"""Fail-closed, PER-MESH documentary license evidence for offline atlas builds.

This is not a legal opinion or an automated grant. A human must identify
each mesh's *actual* origin; Z-Anatomy's general CC BY-SA declaration does
not override third-party NC/unknown content. In particular, inner-ear and
kidney models are recorded upstream with non-commercial terms.

No online lookups, model downloads or privileged approval occur here.
"""
from datetime import date
from urllib.parse import urlparse


class LicenseEvidenceError(ValueError):
    pass


# Commercially reusable subject to each license's attribution/share-alike
# conditions. This is deliberately restrictive, not a universal SPDX parser.
ALLOWED_LICENSE_IDS = frozenset({
    "CC-BY-SA-4.0", "CC-BY-SA-2.1-JP", "CC-BY-4.0",
})


def _require(condition, message):
    if not condition:
        raise LicenseEvidenceError(message)


def _nonempty(value):
    return isinstance(value, str) and bool(value.strip())


def _https(value):
    if not _nonempty(value):
        return False
    parsed = urlparse(value)
    return (parsed.scheme == "https" and bool(parsed.netloc)
            and not parsed.username and not parsed.password)


def _review_header(header):
    _require(isinstance(header, dict), "componentLicenseReview record required")
    _require(_nonempty(header.get("reviewerName")),
             "Human rights reviewer name required")
    stamp = header.get("reviewDate")
    try:
        day = date.fromisoformat(stamp) if isinstance(stamp, str) else None
    except ValueError:
        day = None
    _require(day is not None and date(2000, 1, 1) <= day <= date.today(),
             "Rights review date invalid or in the future")
    _require(header.get("intendedUse") == "commercial-distribution",
             "Commercial distribution rights must be assessed explicitly")
    _require(_nonempty(header.get("reviewNotes")),
             "Independent rights review notes required")
    return {
        "reviewerName": header["reviewerName"].strip(),
        "reviewDate": stamp,
        "intendedUse": header["intendedUse"],
        "reviewNotes": header["reviewNotes"].strip(),
    }


def _entry(record, path):
    _require(isinstance(record, dict), f"Missing component license evidence: {path}")
    _require(record.get("humanReviewed") is True,
             f"Unreviewed license evidence: {path}")
    license_id = record.get("licenseId")
    _require(license_id in ALLOWED_LICENSE_IDS,
             f"Unknown, NC, ND or incompatible component license: {path}: {license_id}")
    for name in ("originalSource", "attribution", "sourceMeshIdentity",
                 "originReviewNotes"):
        _require(_nonempty(record.get(name)),
                 f"Missing per-mesh {name}: {path}")
    _require(_https(record.get("evidenceURL")),
             f"Missing HTTPS evidence URL: {path}")
    _require(record.get("commercialReuseConfirmed") is True,
             f"Commercial rights review is not affirmative: {path}")
    return {
        "licenseId": license_id,
        "originalSource": record["originalSource"].strip(),
        "attribution": record["attribution"].strip(),
        "sourceMeshIdentity": record["sourceMeshIdentity"].strip(),
        "originReviewNotes": record["originReviewNotes"].strip(),
        "evidenceURL": record["evidenceURL"],
        "humanReviewed": True,
        "commercialReuseConfirmed": True,
    }


def reviewed_bindings_license_evidence(review, bindings):
    """Validate the complete private author review before Blender export.

    Returns a path-keyed normalized evidence map to embed alongside EACH
    real source mesh in the MMATLAS1 manifest for independent verification.
    """
    _require(isinstance(review, dict), "Author review JSON required")
    _require(review.get("reviewedForDistribution") is True and
             review.get("licenseReviewed") is True,
             "Human redistribution AND rights review required")
    header = _review_header(review.get("componentLicenseReview"))
    _require(isinstance(bindings, list) and bool(bindings),
             "Complete mesh binding list required")
    result = {}
    for row in bindings:
        _require(isinstance(row, dict), "Malformed source binding")
        path = row.get("sourceHierarchyPath")
        _require(_nonempty(path) and path not in result,
                 "Each source mesh needs a unique exact hierarchy path")
        result[path] = _entry(row.get("componentLicense"), path)
    return header, result


def verify_component_license_manifest(manifest):
    """Validate recorded rights evidence independently of the private file.

    Hash/source/part coverage checks remain the exporter's and verifier's
    responsibility. This rejects unsigned-by-human / unexplained licenses
    even when all model bytes and other review flags are syntactically valid.
    """
    _require(isinstance(manifest, dict), "Atlas manifest required")
    _require(manifest.get("reviewedForDistribution") is True,
             "Human redistribution review missing")
    header = _review_header(manifest.get("componentLicenseReview"))
    parts = manifest.get("parts")
    _require(isinstance(parts, list) and bool(parts),
             "Missing mesh parts for license evidence")
    seen = set()
    for part in parts:
        _require(isinstance(part, dict), "Invalid component license part")
        path = part.get("sourceHierarchyPath")
        _require(_nonempty(path) and path not in seen,
                 "Missing or duplicate licensed source hierarchy path")
        seen.add(path)
        _entry(part.get("componentLicense"), path)
    return header


def compare_private_review_to_manifest(review, manifest):
    """Prove the shipped rights ledger has not drifted from human review."""
    header, rows = reviewed_bindings_license_evidence(
        review, review.get("bindings")
    )
    assert_header = verify_component_license_manifest(manifest)
    _require(header == assert_header, "Rights reviewer record mismatch")
    shipped = {
        row["sourceHierarchyPath"]: _entry(
            row["componentLicense"], row["sourceHierarchyPath"]
        )
        for row in manifest["parts"]
    }
    _require(rows == shipped, "Source mesh license ledger does not match reviewed bindings")
    return True

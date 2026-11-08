#!/usr/bin/env python3
"""Build and validate an openly reusable CC BY-SA 4.0 model-only artifact.

No app source code or camera/ML weights are licensed by this artifact.
The archive is a model distribution aid, not evidence that Apple DRM,
original mesh provenance, or a specific published URL has been cleared.

Input must be a genuinely reviewed atlas; never mark checkboxes true
solely to make the gate pass.
"""
import argparse
from datetime import date
import hashlib
import io
import json
from pathlib import Path
import re
import struct
import sys
from urllib.parse import urlparse
import zipfile


class ShareAlikeError(ValueError):
    pass


LICENSE_ID = "CC-BY-SA-4.0"
LICENSE_URI = "https://creativecommons.org/licenses/by-sa/4.0/"
LEGALCODE_URI = "https://creativecommons.org/licenses/by-sa/4.0/legalcode"
ALLOWED_COMPONENT_LICENSES = frozenset({
    "CC-BY-SA-4.0", "CC-BY-SA-2.1-JP", "CC-BY-4.0"
})
SHA256 = re.compile(r"^[0-9a-f]{64}$")
ALLOWED_MODEL_NAME = re.compile(r"^[a-z][a-z0-9_]*_atlas$")
_FIXED_TIME = (2026, 1, 1, 0, 0, 0)


def _require(condition, message):
    if not condition:
        raise ShareAlikeError(message)


def _filled(value):
    return isinstance(value, str) and bool(value.strip())


def _https(url):
    if not _filled(url):
        return False
    parsed = urlparse(url)
    return parsed.scheme == "https" and bool(parsed.netloc) and not (
        parsed.username or parsed.password
    )


def _digest(data):
    return hashlib.sha256(data).hexdigest()


def review_atlas_manifest(manifest, binary):
    """Verify published rights claims match every part of exact model bytes.

    This deliberately accepts no fabricated 'all meshes CC BY-SA' blanket
    claims, unreviewed origin, mixed NC, or missing source identities.
    """
    _require(isinstance(manifest, dict), "Atlas JSON manifest required")
    _require(manifest.get("schemaVersion") == 1 and
             manifest.get("reviewedForDistribution") is True and
             manifest.get("reviewedJointBindings") is True,
             "Atlas not approved for real anatomy distribution/rig")
    _require(_filled(manifest.get("sourceRepository")) and
             _filled(manifest.get("sourcePath")) and
             re.fullmatch(r"[0-9a-f]{40}", str(
                 manifest.get("sourceRevision", "")
             )) is not None, "Missing pinned original source identity")
    _require(manifest.get("modelSHA256") == _digest(binary),
             "Atlas source manifest does not match published mesh SHA-256")
    header = manifest.get("componentLicenseReview")
    review_date = header.get("reviewDate") if isinstance(header, dict) else None
    try:
        reviewed_on = date.fromisoformat(review_date) if isinstance(
            review_date, str
        ) else None
    except ValueError:
        reviewed_on = None
    _require(isinstance(header, dict) and
             _filled(header.get("reviewerName")) and
             reviewed_on is not None and
             date(2000, 1, 1) <= reviewed_on <= date.today() and
             _filled(header.get("reviewNotes")) and
             header.get("intendedUse") == "commercial-distribution",
             "Full original per-mesh human rights review is mandatory")
    parts = manifest.get("parts")
    _require(isinstance(parts, list) and len(parts) > 0,
             "Reviewed source parts not supplied")
    paths = set()
    expected_offset = 0
    for part in parts:
        _require(isinstance(part, dict), "Invalid mesh part")
        path = part.get("sourceHierarchyPath")
        _require(_filled(path) and path not in paths,
                 "Source mesh path absent or duplicated")
        paths.add(path)
        count = part.get("vertexCount")
        offset = part.get("vertexOffset")
        _require(type(count) is int and type(offset) is int and
                 count > 0 and count % 3 == 0 and
                 offset == expected_offset,
                 f"Invalid published triangle range for {path}")
        expected_offset += count
        c = part.get("componentLicense")
        _require(isinstance(c, dict) and
                 c.get("humanReviewed") is True and
                 c.get("commercialReuseConfirmed") is True and
                 c.get("licenseId") in ALLOWED_COMPONENT_LICENSES,
                 f"NC, ND, unknown or unreviewed source mesh: {path}")
        for key in ("originalSource", "attribution", "sourceMeshIdentity",
                    "originReviewNotes"):
            _require(_filled(c.get(key)),
                     f"Missing {key} rights evidence: {path}")
        _require(_https(c.get("evidenceURL")),
                 f"Invalid original mesh license evidence URL: {path}")
    _require(binary[:8] == b"MMATLAS1" and len(binary) >= 12,
             "Unsupported MMATLAS1 geometry header")
    n = struct.unpack_from("<I", binary, 8)[0]
    _require(0 < n <= 180_000 and n % 3 == 0 and
             len(binary) == 12 + n * 24 and expected_offset == n,
             "Published model geometry and per-part metadata disagree")
    return {"sha256": _digest(binary), "originalParts": len(parts),
            "vertices": n}


def _obj(binary, parts):
    """Readable unindexed OBJ is supplied so CC-model reuse is practical."""
    lines = ["# MagicMirror geometry-only derivative; CC BY-SA 4.0",
             "# Original attributions are in ATTRIBUTION.md",
             "# v and vn coordinates are unchanged from .mmgeom", ""]
    index = 1
    for p in parts:
        lines.append("o " + re.sub(
            r"[^A-Za-z0-9_\-]+", "_", p["sourceHierarchyPath"]
        ))
        offset = p["vertexOffset"]
        count = p["vertexCount"]
        for i in range(offset, offset + count):
            x, y, z, nx, ny, nz = struct.unpack_from(
                "<6f", binary, 12 + i * 24
            )
            _require(all(map(_finite, (x, y, z, nx, ny, nz))),
                     "Non-finite triangle vertex in source")
            lines.append(f"v {x:.9g} {y:.9g} {z:.9g}")
            lines.append(f"vn {nx:.9g} {ny:.9g} {nz:.9g}")
        for _ in range(count // 3):
            a, b, c = index, index + 1, index + 2
            lines.append(f"f {a}//{a} {b}//{b} {c}//{c}")
            index += 3
    return ("\n".join(lines) + "\n").encode("utf-8")


def _finite(value):
    return abs(value) < float("inf") and value == value


def _zip_binary(records):
    """Stable ZIP bytes, no source .fbx, app code, or proprietary weights."""
    output = io.BytesIO()
    with zipfile.ZipFile(
        output, mode="w", compression=zipfile.ZIP_DEFLATED,
        compresslevel=6, strict_timestamps=True
    ) as z:
        for name in sorted(records):
            info = zipfile.ZipInfo(name, date_time=_FIXED_TIME)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            z.writestr(info, records[name], compress_type=zipfile.ZIP_DEFLATED,
                       compresslevel=6)
    return output.getvalue()


def build_pack(*, model_file, manifest_file, attribution_file,
               modification_file, output, skinning_file=None):
    """Produce a distributable archive from actual separately-reviewed inputs."""
    model_file = Path(model_file)
    manifest_file = Path(manifest_file)
    output = Path(output)
    base = model_file.stem
    _require(ALLOWED_MODEL_NAME.fullmatch(base) is not None and
             model_file.name == f"{base}.mmgeom" and
             manifest_file.name == f"{base}.manifest.json",
             "Model and manifest must have matching *_atlas basename")
    _require(not output.exists(), "Refuse to overwrite an existing public release")
    binary = model_file.read_bytes()
    manifest_bytes = manifest_file.read_bytes()
    manifest = json.loads(manifest_bytes)
    _require(manifest.get("modelFile") == model_file.name,
             "Model filename differs from reviewed manifest")
    report = review_atlas_manifest(manifest, binary)
    attribution = Path(attribution_file).read_bytes()
    modifications = Path(modification_file).read_bytes()
    try:
        a_text = attribution.decode("utf-8")
        m_text = modifications.decode("utf-8")
    except UnicodeError as exc:
        raise ShareAlikeError("Credits and modification records need UTF-8") from exc
    _require(len(a_text.strip()) > 60 and
             "Z-Anatomy" in a_text and "BodyParts3D" in a_text and
             "CC BY-SA 4.0" in a_text and LICENSE_URI in a_text,
             "Missing real Z-Anatomy/BodyParts3D attribution and license")
    _require(len(m_text.strip()) > 30,
             "A nonempty human-written modification history is mandatory")
    records = {
        model_file.name: binary,
        manifest_file.name: manifest_bytes,
        f"{base}.obj": _obj(binary, manifest["parts"]),
        "ATTRIBUTION.md": attribution,
        "MODIFICATIONS.md": modifications,
        "LICENSE.txt": (
            "This archive contains separately published derived ANATOMY "
            "geometry only. License: CC BY-SA 4.0\n"
            "Full legal terms: " + LEGALCODE_URI + "\n"
            "No rights over the closed-source MagicMirror iOS app code, "
            "MediaPipe model weights, or third-party material outside the "
            "reviewed geometry are claimed.\n"
        ).encode("utf-8"),
        "README.md": (
            "# Reusable anatomy model (CC BY-SA 4.0)\n\n"
            "Model base: " + base + "\n"
            "Pinned source: " + manifest["sourceRepository"] + "\n"
            "Source revision: " + manifest["sourceRevision"] + "\n"
            "Source path: " + manifest["sourcePath"] + "\n\n"
            "The OBJ is a plain-text, reusable geometry representation. "
            "The matching .mmgeom and .manifest.json are exact app source "
            "assets. The original per-mesh rights evidence, credits, "
            "license links and modification history are included. "
            "The archive is not a license of MagicMirror application code.\n"
        ).encode("utf-8"),
    }
    if skinning_file is not None:
        skinning_file = Path(skinning_file)
        _require(skinning_file.name == f"{base}.skinning.json",
                 "Unmatched rig skinning sidecar")
        raw = skinning_file.read_bytes()
        skin = json.loads(raw)
        _require(skin.get("reviewedJointWeights") is True and
                 skin.get("modelSHA256") == report["sha256"] and
                 skin.get("sourceRevision") == manifest["sourceRevision"] and
                 isinstance(skin.get("vertices"), list) and
                 len(skin["vertices"]) == report["vertices"],
                 "Model rig skinning weights incomplete or mismatched")
        records[skinning_file.name] = raw
    records["SHA256SUMS.txt"] = (
        "".join(f"{_digest(records[name])}  {name}\n"
                for name in sorted(records))
    ).encode("utf-8")
    output.parent.mkdir(parents=True, exist_ok=True)
    raw_zip = _zip_binary(records)
    verify_pack_bytes(raw_zip, model_file.name, binary,
                      manifest_file.name, manifest_bytes,
                      skinning_file.name if skinning_file else None)
    output.write_bytes(raw_zip)
    return {"archive": str(output), "archiveSHA256": _digest(raw_zip),
            **report}


def verify_pack_bytes(raw_zip, model_name, binary, manifest_name, manifest_bytes,
                      skinning_name=None):
    """Verify that archive mirrors *actual* app geometry and rights ledger."""
    with zipfile.ZipFile(io.BytesIO(raw_zip)) as archive:
        names = archive.namelist()
        required = {
            model_name, manifest_name, model_name[:-7] + ".obj",
            "LICENSE.txt", "README.md", "ATTRIBUTION.md",
            "MODIFICATIONS.md", "SHA256SUMS.txt"
        }
        if skinning_name:
            required.add(skinning_name)
        _require(set(names) == required and len(names) == len(set(names)),
                 "Share-alike public archive has missing or injected contents")
        _require(all(not name.startswith("/") and
                     all(p not in ("", ".", "..") for p in name.split("/"))
                     for name in names), "Unsafe publication archive path")
        _require(archive.read(model_name) == binary and
                 archive.read(manifest_name) == manifest_bytes,
                 "Published model or provenance differs from iOS app asset")
        _require(LICENSE_URI in archive.read("LICENSE.txt").decode("utf-8") or
                 LEGALCODE_URI in archive.read("LICENSE.txt").decode("utf-8"),
                 "Missing CC BY-SA public license")
        for key, name in (("ATTRIBUTION.md", "Z-Anatomy"),
                          ("ATTRIBUTION.md", "BodyParts3D")):
            _require(name in archive.read(key).decode("utf-8"),
                     "Missing underlying authorship")
        expected = "".join(
            f"{_digest(archive.read(name))}  {name}\n"
            for name in sorted(required - {"SHA256SUMS.txt"})
        ).encode("utf-8")
        _require(archive.read("SHA256SUMS.txt") == expected,
                 "Published SHA256SUMS did not match all public files")
        actual_manifest = json.loads(manifest_bytes)
        review_atlas_manifest(actual_manifest, binary)
        _require(actual_manifest.get("modelFile") == model_name,
                 "Public provenance manifest names an unrelated model")
        _require(archive.read(model_name[:-7] + ".obj") ==
                 _obj(binary, actual_manifest["parts"]),
                 "Public reuse OBJ has different geometry from shipped app")
        if skinning_name:
            skin = json.loads(archive.read(skinning_name))
            _require(skin.get("reviewedJointWeights") is True and
                     skin.get("modelSHA256") == _digest(binary),
                     "Published original skinning evidence missing")
    return True


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--model", type=Path, required=True)
    p.add_argument("--manifest", type=Path, required=True)
    p.add_argument("--attribution", type=Path, required=True)
    p.add_argument("--modifications", type=Path, required=True)
    p.add_argument("--skinning", type=Path)
    p.add_argument("--output", type=Path, required=True)
    args = p.parse_args(argv)
    try:
        report = build_pack(
            model_file=args.model, manifest_file=args.manifest,
            attribution_file=args.attribution,
            modification_file=args.modifications,
            output=args.output, skinning_file=args.skinning
        )
    except (OSError, ValueError, zipfile.BadZipFile) as exc:
        p.exit(1, "PUBLIC MODEL PACK BLOCKED: " + str(exc) + "\n")
    print(json.dumps(report, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Fail-closed paid iOS App Store THIRD-PARTY ASSET release preflight.

This is a technical gate, NOT legal authorization. It has two purposes:
(1) prevent an unreviewed local, git-ignored atlas or ML model from being
    accidentally copied into a Release .app via XcodeGen's Resources folder;
(2) require explicit product-owner legal signoff, pinned hashes, rights
    scope and an embedded attribution file before any paid build proceeds.

Use from the source checkout:
 python3 Mobile/iOS/Scripts/paid_release_gate.py --mode source
 python3 Mobile/iOS/Scripts/paid_release_gate.py --mode release
 python3 Mobile/iOS/Scripts/paid_release_gate.py --mode bundle --bundle /path/to/MagicMirror.app

The developer-only source check does not pretend to clear a release.
"""
import argparse
from datetime import date
import hashlib
import json
from pathlib import Path
import re
import sys

RESOURCE_MODEL_SUFFIXES = frozenset({
    ".task", ".tflite", ".onnx", ".mlmodel", ".mlpackage", ".mlmodelc",
    ".pt", ".pth", ".ckpt", ".safetensors", ".weights", ".pb",
    ".fbx", ".obj", ".usdz", ".usd", ".usdc", ".usda", ".gltf", ".glb",
    ".dae", ".stl", ".ply", ".blend", ".mmgeom",
    ".zip", ".7z", ".rar", ".tar", ".bin", ".safetensors",
})
MODEL_METADATA_SUFFIXES = (
    ".skinning.json", ".manifest.json", "_atlas_manifest.json",
)
REQUIRED_RUNTIME_ASSETS = frozenset({"pose_landmarker_lite.task"})
PINNED_POSE_SHA256 = (
    "59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a"
)
PINNED_MEDIAPIPE_REVISION = "2df17d66d380f74884c1505a7e7ac677020c3980"
RIGHTS_BASES = frozenset({
    "original-owned", "written-copyright-assignment", "written-commercial-grant"
})
THIRD_PARTY_DEPENDENCIES = frozenset({"MediaPipeTasksVision"})
DEFAULT_ROOT = Path(__file__).resolve().parents[1]
CLEARANCE_NAME = "CommercialRelease/paid-app-clearance.json"
NOTICES_NAME = "ThirdPartyNotices.txt"
HEX_SHA256 = re.compile(r"^[0-9a-f]{64}$")


class CommercialReleaseError(ValueError):
    pass


def require(value, reason):
    if not value:
        raise CommercialReleaseError(reason)


def _nonempty(value):
    return isinstance(value, str) and bool(value.strip())


def _valid_date(value):
    if not isinstance(value, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
        return False
    try:
        day = date.fromisoformat(value)
    except ValueError:
        return False
    return date(2020, 1, 1) <= day <= date.today()


def _is_asset(path):
    filename = path.name.lower()
    return (path.suffix.lower() in RESOURCE_MODEL_SUFFIXES or
            filename.endswith(MODEL_METADATA_SUFFIXES))


def _assets_under(directory):
    """Do not follow symlinked license-bypassing directory boundaries."""
    require(directory.is_dir(), f"Missing iOS resources/bundle: {directory}")
    root = directory.resolve()
    binaries = {}
    for path in directory.rglob("*"):
        relative = path.relative_to(directory).as_posix()
        if path.is_dir() and path.suffix.lower() in (
            ".mlmodelc", ".mlpackage"
        ):
            # ML model packages are DIRECTORY assets and cannot be
            # SHA-256 audited as a single file by this manifest format.
            raise CommercialReleaseError(
                f"Unreviewed model package directory: {relative}"
            )
        if path.is_symlink():
            # Symlinks to frameworks may be present in an iOS .app;
            # their contents are not anatomy assets. Reject links that
            # themselves appear to stage a tracked asset.
            require(not _is_asset(path),
                    f"Linked anatomy/ML asset is not auditable: {relative}")
            continue
        if not path.is_file() or not _is_asset(path):
            continue
        require(path.resolve().is_relative_to(root),
                f"Asset path escapes inspected directory: {relative}")
        require(relative not in binaries, "Duplicate resource asset")
        binaries[relative] = path
    return binaries


def _json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, ValueError) as exc:
        raise CommercialReleaseError(
            f"Cannot read commercial release approval file: {path}"
        ) from exc


def _approval(manifest):
    require(isinstance(manifest, dict), "Release clearance must be a JSON object")
    require(manifest.get("schemaVersion") == 1 and
            manifest.get("distributionChannel") == "paid-ios-app-store",
            "Incorrect paid release clearance schema or channel")
    require(manifest.get("releaseApproved") is True,
            "Paid App Store release is LOCKED until actual rights approval")
    record = manifest.get("approval")
    require(isinstance(record, dict), "Independent release owner/legal approval required")
    require(_nonempty(record.get("reviewerName")) and
            _valid_date(record.get("reviewDate")) and
            _nonempty(record.get("legalEvidenceReference")) and
            record.get("actualDocumentsIndependentlyReviewed") is True,
            "Named, dated review and independently retained legal evidence required")
    require(record.get("appleDRMAndRedistributionReviewed") is True,
            "Apple paid App Store DRM/redistribution compatibility NOT reviewed")
    require(_nonempty(record.get("distributionNotes")),
            "Document release geography, payment and redistributability")
    return record


def _dependency_gate(manifest, root):
    project_file = root / "project.yml"
    require(project_file.is_file(), "Pinned project.yml required")
    project_text = project_file.read_text(encoding="utf-8")
    pinned = re.search(
        r"MediaPipeTasks:\s*\n\s+url:\s*https://github\.com/google-ai-edge/mediapipe\s*\n\s+revision:\s*([0-9a-f]{40})",
        project_text
    )
    require(pinned is not None and
            pinned.group(1) == PINNED_MEDIAPIPE_REVISION,
            "Actual SwiftPM MediaPipe source revision differs from clearance")
    records = manifest.get("runtimeDependencies")
    require(isinstance(records, list), "Third-party runtime dependency ledger required")
    seen = set()
    for item in records:
        require(isinstance(item, dict), "Malformed SDK dependency rights record")
        name = item.get("name")
        require(name in THIRD_PARTY_DEPENDENCIES and name not in seen,
                f"Unrecognized or duplicate commercial SDK dependency: {name}")
        seen.add(name)
        require(item.get("sourceRevision") == PINNED_MEDIAPIPE_REVISION and
                item.get("licenseIdentifier") == "Apache-2.0" and
                item.get("redistributionReviewed") is True and
                item.get("requiredNoticesIncluded") is True and
                _nonempty(item.get("evidenceReference")),
                f"Missing verified commercial dependency/NOTICE clearance: {name}")
    require(seen == THIRD_PARTY_DEPENDENCIES,
            "Pinned MediaPipeTasksVision redistribution/attribution review is required")


def _asset_gate(manifest):
    records = manifest.get("authorizedAssets")
    require(isinstance(records, list), "Per-binary commercial rights ledger required")
    by_path = {}
    for item in records:
        require(isinstance(item, dict), "Malformed release asset clearance")
        path = item.get("bundleRelativePath")
        require(_nonempty(path) and not path.startswith("/") and
                "\\" not in path and all(
                    p not in ("", ".", "..") for p in path.split("/")
                ) and _is_asset(Path(path)), f"Invalid asset path: {path}")
        require(path not in by_path, f"Duplicate asset clearance: {path}")
        digest = item.get("sha256")
        require(isinstance(digest, str) and
                HEX_SHA256.fullmatch(digest) is not None,
                f"Missing SHA-256 provenance for asset: {path}")
        require(item.get("rightsBasis") in RIGHTS_BASES and
                item.get("commercialUseAuthorized") is True and
                item.get("applePaidAppStoreDistributionAuthorized") is True and
                item.get("redistributionAndTechnicalRestrictionsAuthorized") is True,
                f"Insufficient commercial/App Store/DRM rights: {path}")
        require(_nonempty(item.get("authorOrRightsholder")) and
                _nonempty(item.get("sourceAndRevision")) and
                _nonempty(item.get("licenseOrAssignmentEvidenceReference")) and
                _nonempty(item.get("attributionAndModificationNotes")),
                f"Missing provenance and actual rights evidence: {path}")
        # A CC BY-SA / NC source must never be relabelled "original-owned"
        # merely by changing a top-level bool. A distinct written license
        # including Apple's distribution conditions must be reviewed.
        upstream = (str(item.get("sourceAndRevision", "")) + " " +
                    str(item.get("licenseIdentifier", ""))).lower()
        third_party_anatomy = any(
            s in upstream for s in ("z-anatomy", "bodyparts3d", "cc-by-sa", "cc-by-nc")
        )
        if third_party_anatomy:
            require(item["rightsBasis"] == "written-commercial-grant" and
                    item.get("underlyingSourceRightsReviewed") is True and
                    _nonempty(item.get("alternativeWrittenGrantReference")),
                    f"Z-Anatomy/BodyParts3D/CC-licensed material requires"
                    f" separately reviewed alternate written grant: {path}")
        if path.endswith((".mmgeom", ".usdz", ".glb", ".gltf", ".fbx")):
            require(item.get("anatomyAndRigReviewed") is True and
                    _nonempty(item.get("originalMeshRightsAuditSHA256")) and
                    HEX_SHA256.fullmatch(
                        item["originalMeshRightsAuditSHA256"]
                    ) is not None,
                    f"Anatomy original mesh provenance/rig not approved: {path}")
        by_path[path] = item
    require(REQUIRED_RUNTIME_ASSETS.issubset(by_path),
            "Bundled PoseLandmarker model weights need independent release clearance")
    require(by_path["pose_landmarker_lite.task"]["sha256"] == PINNED_POSE_SHA256,
            "Pinned MediaPipe task model digest changed")
    return by_path


def _check_present_asset_hashes(actual, approved):
    require(set(actual) == set(approved),
            f"Bundled AI/anatomy resources differ from cleared ledger: "
            f"missing={sorted(set(approved)-set(actual))}, "
            f"unapproved={sorted(set(actual)-set(approved))}")
    for name, path in sorted(actual.items()):
        calculated = hashlib.sha256(path.read_bytes()).hexdigest()
        require(calculated == approved[name]["sha256"],
                f"Asset binary does not match reviewed SHA-256: {name}")


def _notices(directory, manifest):
    notice_path = directory / NOTICES_NAME
    require(notice_path.is_file(),
            "Paid app is missing bundled ThirdPartyNotices.txt")
    try:
        contents = notice_path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        raise CommercialReleaseError("Cannot inspect third-party notices") from exc
    require(len(contents.strip()) >= 100 and
            "MediaPipe" in contents and "Apache" in contents and
            _nonempty(manifest.get("noticesSHA256")) and
            hashlib.sha256(contents.encode("utf-8")).hexdigest() ==
            manifest["noticesSHA256"],
            "Third-party notices not reviewed or changed after approval")


def run(*, root=DEFAULT_ROOT, mode="source", bundle=None):
    root = Path(root)
    resources = root / "Resources"
    require(mode in ("source", "release", "bundle"),
            "Unsupported release audit mode")
    scan_dir = Path(bundle) if mode == "bundle" else resources
    present = _assets_under(scan_dir)
    if mode == "source":
        # Resource-only inventory check. A local development build may
        # stage the pinned task file, but THIRD-PARTY anatomy isn't allowed
        # in the source Xcode resource folder by default.
        accidental_geometry = [
            name for name in present
            if name != "pose_landmarker_lite.task"
        ]
        require(not accidental_geometry,
                f"Unreviewed 3D/ML assets under app Resources: {accidental_geometry}")
        model = present.get("pose_landmarker_lite.task")
        if model is not None:
            digest = hashlib.sha256(model.read_bytes()).hexdigest()
            require(digest == PINNED_POSE_SHA256,
                    "Unrecognized development PoseLandmarker task weights")
        return {"mode": mode, "foundAssets": sorted(present),
                "paidReleaseCleared": False}

    manifest = _json(root / CLEARANCE_NAME)
    _approval(manifest)
    _dependency_gate(manifest, root)
    reviewed = _asset_gate(manifest)
    _check_present_asset_hashes(present, reviewed)
    _notices(scan_dir, manifest)
    return {"mode": mode, "foundAssets": sorted(present),
            "paidReleaseCleared": True}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--mode", choices=("source", "release", "bundle"),
                        default="source")
    parser.add_argument("--bundle", type=Path,
                        help="Actual .app bundle for independent post-archive audit")
    args = parser.parse_args(argv)
    try:
        if args.mode == "bundle":
            require(args.bundle is not None, "--bundle path required for bundle mode")
        stats = run(root=args.root, mode=args.mode, bundle=args.bundle)
    except (CommercialReleaseError, OSError) as exc:
        parser.exit(1, f"PAID RELEASE BLOCKED: {exc}\n")
    if args.mode == "source":
        print("PASS: developer resources match non-distributable source policy.")
        print("This does NOT approve a paid App Store release.")
    else:
        print("PASS: candidate bundle matches the documentary release ledger.")
        print("Reviewers must STILL verify the real signed grant, SDK notices,"
              " App Store terms and device privacy before submission.")
    return stats


if __name__ == "__main__":
    main()

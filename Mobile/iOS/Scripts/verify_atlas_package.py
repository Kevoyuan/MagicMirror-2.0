#!/usr/bin/env python3
"""Offline, dependency-free structural preflight for a MagicMirror MMATLAS1.

Usage (on a developer Mac, not in the installed iOS app):
  python3 Mobile/iOS/Scripts/verify_atlas_package.py --package /private/reviewed/export

A PASS validates binary/manifest consistency, NOT legal review, anatomy,
camera calibration, a coherent animated rig, or iPhone rendering.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct

MAGIC = b"MMATLAS1"
BINARY_NAME = "skeleton_atlas.mmgeom"
MANIFEST_NAME = "skeleton_atlas.manifest.json"
MAX_VERTICES = 180_000
RECORD_BYTES = 24
SOURCE_REPO = "https://github.com/LluisV/Z-Anatomy"
SOURCE_REVISION = "6c7f9016bd5899ac8edafd31b9900c151df42ed6"
SOURCE_PATH = "Resources/Models/FBX/SkeletalSystem100.fbx"
REQUIRED_LICENSES = {"CC BY-SA 2.1 Japan", "CC BY-SA 4.0"}


class PackageError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise PackageError(message)


def finite_vector(value):
    return (
        isinstance(value, list)
        and len(value) == 3
        and all(type(v) in (int, float) and math.isfinite(v) for v in value)
    )


def verify_package(directory: Path):
    directory = Path(directory)
    manifest_path = directory / MANIFEST_NAME
    binary_path = directory / BINARY_NAME
    require(manifest_path.is_file(), "missing atlas manifest")
    require(binary_path.is_file(), "missing atlas binary")
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (ValueError, UnicodeError) as exc:
        raise PackageError("invalid atlas manifest JSON") from exc

    require(isinstance(manifest, dict), "manifest must be an object")
    require(type(manifest.get("schemaVersion")) is int
            and manifest["schemaVersion"] == 1, "unsupported manifest schema")
    require(manifest.get("modelFile") == BINARY_NAME, "unexpected binary filename")
    require(manifest.get("sourceRepository") == SOURCE_REPO,
            "unexpected source repository")
    require(manifest.get("sourceRevision") == SOURCE_REVISION,
            "unexpected source revision")
    require(manifest.get("sourcePath") == SOURCE_PATH, "unexpected source path")
    require(manifest.get("reviewedForDistribution") is True,
            "human distribution review not recorded")
    require(manifest.get("reviewedJointBindings") is True,
            "human binding review not recorded")
    require(isinstance(manifest.get("licenseIds"), list)
            and all(isinstance(x, str) for x in manifest["licenseIds"])
            and REQUIRED_LICENSES.issubset(set(manifest["licenseIds"])),
            "required license IDs missing")
    attribution = manifest.get("attribution")
    require(isinstance(attribution, list)
            and all(isinstance(x, str) for x in attribution)
            and any("Z-Anatomy" in x for x in attribution)
            and any("BodyParts3D" in x for x in attribution),
            "atlas and BodyParts3D attribution missing")
    notes = manifest.get("modificationNotes")
    require(isinstance(notes, list) and bool(notes)
            and all(isinstance(x, str) and x.strip() for x in notes),
            "modification notes required")
    expected_hash = manifest.get("modelSHA256")
    require(isinstance(expected_hash, str) and len(expected_hash) == 64
            and all(c in "0123456789abcdefABCDEF" for c in expected_hash),
            "invalid SHA-256 in manifest")

    payload = binary_path.read_bytes()
    require(len(payload) >= 12 and payload[:8] == MAGIC,
            "invalid MMATLAS1 header")
    count = struct.unpack_from("<I", payload, 8)[0]
    require(0 < count <= MAX_VERTICES and count % 3 == 0,
            "invalid triangle vertex count")
    require(len(payload) == 12 + count * RECORD_BYTES,
            "binary length inconsistent with vertex count")
    actual_hash = hashlib.sha256(payload).hexdigest()
    require(actual_hash == expected_hash.lower(), "binary SHA-256 mismatch")

    parts = manifest.get("parts")
    require(isinstance(parts, list) and bool(parts),
            "manifest has no reviewed parts")
    cursor = 0
    paths = set()
    for index, part in enumerate(parts):
        require(isinstance(part, dict), f"invalid part at {index}")
        path = part.get("sourceHierarchyPath")
        require(isinstance(path, str) and path.strip() and path not in paths,
                f"empty or duplicate hierarchy path in part {index}")
        paths.add(path)
        require(isinstance(part.get("displayName"), str)
                and part["displayName"].strip(), f"missing display name: {path}")
        require(part.get("group") in ("arms", "legs", "torso"),
                f"invalid region: {path}")
        a, b = part.get("fromLandmark"), part.get("toLandmark")
        require(type(a) is int and type(b) is int
                and 0 <= a < 33 and 0 <= b < 33 and a != b,
                f"invalid landmark pair: {path}")
        rest_a, rest_b = part.get("restFrom"), part.get("restTo")
        require(finite_vector(rest_a) and finite_vector(rest_b),
                f"invalid rest anchors: {path}")
        require(math.dist(rest_a, rest_b) > 1e-5,
                f"coincident rest anchors: {path}")
        start, length = part.get("vertexOffset"), part.get("vertexCount")
        require(type(start) is int and type(length) is int
                and start == cursor and length >= 3
                and length % 3 == 0 and length <= count - cursor,
                f"invalid triangle span: {path}")
        cursor += length
    require(cursor == count, "parts do not cover the complete binary")

    # Float32 position and normal validity is checked for every actual
    # triangle vertex, not just for the reviewed rest anchors.
    for index, values in enumerate(struct.iter_unpack("<6f", payload[12:])):
        px, py, pz, nx, ny, nz = values
        require(all(math.isfinite(x) for x in values),
                f"nonfinite vertex: {index}")
        require(nx * nx + ny * ny + nz * nz > 1e-8,
                f"zero normal: {index}")
    return {"vertex_count": count, "mesh_count": len(parts), "sha256": actual_hash}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, required=True)
    args = parser.parse_args()
    try:
        stats = verify_package(args.package)
    except (PackageError, OSError) as exc:
        parser.exit(1, f"FAIL: {exc}\n")
    print(f"PASS: {stats['vertex_count']} vertices, "
          f"{stats['mesh_count']} meshes, SHA-256 {stats['sha256']}")
    print("Structural checks only; human licensing/anatomy review and iPhone "
          "camera validation remain separate and mandatory.")


if __name__ == "__main__":
    main()

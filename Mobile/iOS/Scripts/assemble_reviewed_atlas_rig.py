#!/usr/bin/env python3
"""Assemble a human-reviewed MMATLAS1 and coherent rig into an iOS bundle.

This stdlib-only developer tool produces the *actual* hierarchy manifest
read by AnatomyAtlasStore. It references the SAME original SHA-verified
.mmgeom binary read by Metal, so no unnecessary second USDZ is fabricated.

    python3 Mobile/iOS/Scripts/assemble_reviewed_atlas_rig.py \
      --system skeleton --package /private/approved-models \
      --review /private/human-reviewed-bindings.json

The private review JSON must include:
  reviewedForDistribution: true, reviewedJointBindings: true,
  reviewedRigHierarchy: true, licenseReviewed: true,
  bindings: [
    {sourceHierarchyPath: <exact original path>,
     boneId: <human-approved stable unique ID>,
     parentBoneId: <approved parent ID or null>,
     anchorsReviewed: true}
  ]

For each binding its rest anchors/landmarks come from the original
independently reviewed MMATLAS1 mesh manifest; they are NEVER guessed
from names or proximity by this script. Human legal and anatomical review
is a prerequisite, not an action performed by the CLI.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import struct

SYSTEM_BASES = {
    "skeleton": "skeleton_atlas",
    "muscles": "muscles_atlas",
    "organs": "organs_atlas",
    "vessels": "vessels_atlas",
    "nerves": "nerves_atlas",
    "joints": "joints_atlas",
}


class AssemblyError(ValueError):
    pass


def require(test, message):
    if not test:
        raise AssemblyError(message)


def _read_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError, UnicodeError) as exc:
        raise AssemblyError(f"Cannot read valid reviewed JSON: {path}") from exc


def _vector(value):
    return isinstance(value, list) and len(value) == 3 and all(
        type(x) in (float, int) and math.isfinite(x) and abs(x) < 10_000
        for x in value
    )


def assemble(package: Path, review_file: Path, system: str = "skeleton"):
    require(system in SYSTEM_BASES, "Unrecognized anatomical system")
    package = Path(package)
    base = SYSTEM_BASES[system]
    meta = _read_json(package / (base + ".manifest.json"))
    review = _read_json(Path(review_file))
    require(isinstance(meta, dict), "MMATLAS1 manifest must be an object")
    require(isinstance(review, dict), "Review must be an object")
    for flag in ("reviewedForDistribution", "reviewedJointBindings",
                 "reviewedRigHierarchy", "licenseReviewed"):
        require(review.get(flag) is True, f"Missing human review: {flag}")
    for flag in ("reviewedForDistribution", "reviewedJointBindings"):
        require(meta.get(flag) is True, f"Unreviewed model: {flag}")
    require(meta.get("schemaVersion") == 1, "Unsupported MMATLAS1 manifest")
    require(meta.get("modelFile") == base + ".mmgeom",
            "Wrong anatomical system binary")
    require(meta.get("anatomicalSystem") == system or
            (system == "skeleton" and meta.get("anatomicalSystem") is None),
            "Cross-system model provenance mismatch")
    require(isinstance(meta.get("sourceRepository"), str) and
            meta["sourceRepository"].startswith("https://"),
            "Source repository provenance required")
    revision = meta.get("sourceRevision")
    require(isinstance(revision, str) and
            re.fullmatch("[0-9a-fA-F]{40}", revision) is not None,
            "Pinned 40-digit source revision required")
    require(isinstance(meta.get("sourcePath"), str) and
            bool(meta["sourcePath"]), "Original source path missing")
    require(isinstance(meta.get("licenseIds"), list) and
            bool(meta["licenseIds"]) and
            all(isinstance(v, str) and v for v in meta["licenseIds"]),
            "Source model licenses missing")
    require(isinstance(meta.get("attribution"), list) and
            bool(meta["attribution"]) and
            all(isinstance(v, str) and v for v in meta["attribution"]),
            "Source model attribution missing")
    require(isinstance(meta.get("modificationNotes"), list) and
            bool(meta["modificationNotes"]), "Recorded modifications missing")

    payload_path = package / (base + ".mmgeom")
    try:
        payload = payload_path.read_bytes()
    except OSError as exc:
        raise AssemblyError(f"Missing original MMATLAS1 mesh: {payload_path}") from exc
    require(len(payload) >= 12 and payload[:8] == b"MMATLAS1",
            "Malformed MMATLAS1 header")
    count = struct.unpack_from("<I", payload, 8)[0]
    require(0 < count <= 180_000 and count % 3 == 0 and
            len(payload) == 12 + 24 * count,
            "Invalid MMATLAS1 mesh length")
    digest = hashlib.sha256(payload).hexdigest()
    require(meta.get("modelSHA256") == digest,
            "Source binary and manifest SHA-256 disagree")

    parts = meta.get("parts")
    require(isinstance(parts, list) and bool(parts),
            "Missing per-source reviewed parts")
    reviewed = review.get("bindings")
    require(isinstance(reviewed, list) and len(reviewed) == len(parts),
            "Every source mesh needs exactly one reviewed rig binding")
    records = {}
    for entry in reviewed:
        require(isinstance(entry, dict), "Malformed reviewed binding")
        path = entry.get("sourceHierarchyPath")
        bone_id = entry.get("boneId")
        parent = entry.get("parentBoneId")
        require(isinstance(path, str) and path and path not in records,
                "Missing or duplicated source hierarchy path")
        require(isinstance(bone_id, str) and bone_id.strip() and
                (parent is None or (isinstance(parent, str) and parent.strip())),
                "Missing reviewed stable bone ID or invalid parent")
        require(entry.get("anchorsReviewed") is True,
                f"Rest-anchor review not recorded for {path}")
        records[path] = entry

    bones = []
    ids = set()
    cursor = 0
    anchors = {}
    for entry in parts:
        require(isinstance(entry, dict), "Malformed model part")
        path = entry.get("sourceHierarchyPath")
        require(isinstance(path, str) and path in records,
                "Unmapped source mesh in anatomy model")
        bind = records[path]
        bone_id = bind["boneId"]
        require(bone_id not in ids, "Duplicate reviewed bone ID")
        ids.add(bone_id)
        start, length = entry.get("vertexOffset"), entry.get("vertexCount")
        require(type(start) is int and type(length) is int and
                start == cursor and length >= 3 and length % 3 == 0 and
                length <= count - cursor,
                f"Invalid part vertex range: {path}")
        cursor += length
        a, b = entry.get("fromLandmark"), entry.get("toLandmark")
        start_point, end_point = entry.get("restFrom"), entry.get("restTo")
        require(type(a) is int and type(b) is int and
                0 <= a < 33 and 0 <= b < 33 and a != b and
                _vector(start_point) and _vector(end_point) and
                math.dist(start_point, end_point) > 1e-5,
                f"Malformed reviewed landmark/anchor for {path}")
        for landmark, point in ((a, start_point), (b, end_point)):
            if landmark in anchors:
                require(math.dist(anchors[landmark], point) <= 1e-4,
                        f"Inconsistent rest anchors for landmark {landmark}")
            else:
                anchors[landmark] = point
        bones.append({
            "id": bone_id,
            "nodePath": path,
            "parentId": bind.get("parentBoneId"),
            "proximalLandmark": a,
            "distalLandmark": b,
            "restStart": start_point,
            "restEnd": end_point,
            "anchorsReviewed": True,
        })
    require(cursor == count, "Uncovered source triangle vertices")
    require(set(records) == {part["sourceHierarchyPath"] for part in parts},
            "Reviewed hierarchy paths do not match source")
    require({11, 12, 23, 24}.issubset(anchors),
            "Rig requires independently reviewed shoulder/hip anchors")

    parents = {bone["id"]: bone["parentId"] for bone in bones}
    for node, parent in parents.items():
        require(parent is None or (parent in ids and parent != node),
                f"Unknown parent bone: {node}")
        chain = {node}
        while parent is not None:
            require(parent not in chain, "Cyclic reviewed rig hierarchy")
            chain.add(parent)
            parent = parents[parent]

    atlas_id = review.get("atlasId", f"{system}-{revision[:12]}")
    require(isinstance(atlas_id, str) and bool(atlas_id.strip()),
            "Human reviewed atlas ID required")
    rig = {
        "atlasId": atlas_id,
        "sourceURL": meta["sourceRepository"],
        "sourceRevision": revision,
        "attribution": "; ".join(meta["attribution"]),
        "licenseIdentifier": "; ".join(meta["licenseIds"]),
        "assetFilename": base + ".mmgeom",
        "assetSHA256": digest,
        "licenseReviewed": True,
        "anatomyReviewed": True,
        "bones": bones,
    }
    filename = ("anatomy_atlas_manifest.json" if system == "skeleton"
                else base + "_manifest.json")
    output = package / filename
    output.write_text(
        json.dumps(rig, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8"
    )
    return {"filename": filename, "bones": len(bones),
            "vertex_count": count, "sha256": digest}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--system", choices=SYSTEM_BASES,
                        default="skeleton")
    parser.add_argument("--package", required=True, type=Path)
    parser.add_argument("--review", required=True, type=Path)
    args = parser.parse_args()
    try:
        result = assemble(args.package, args.review, args.system)
    except AssemblyError as exc:
        parser.exit(1, f"FAIL: {exc}\n")
    print(f"Built {result['filename']}, {result['bones']} reviewed bindings,"
          f" original SHA-256 {result['sha256']}")
    print("Metadata assembly only; human legal/anatomy review, licensed"
          " source weights and real iPhone behavior are not certified.")


if __name__ == "__main__":
    main()

"""Strict, Blender-independent construction of reviewed USDZ rig metadata.

Consumes the *same* reviewed per-mesh anchor/bone declarations used to
export MMATLAS1. The USDZ archive is produced by Blender's USD exporter,
not by this module. Structural success does NOT certify human anatomy,
copyright/licensing or the user's camera registration.
"""
import hashlib
import math
from pathlib import Path
import zipfile

from atlas_sources import SOURCE_COMMIT, SOURCE_REPOSITORY, SYSTEM_SOURCES, resource_base


class RigPackageError(ValueError):
    pass


def build_rig_manifest(review, mesh_manifest, usdz_file, system):
    if system not in SYSTEM_SOURCES:
        raise RigPackageError("unsupported reviewed anatomical system")
    if any(review.get(flag) is not True for flag in (
            "reviewedForDistribution", "reviewedJointBindings",
            "reviewedUSDZHierarchy")):
        raise RigPackageError("all three independent human review flags required")
    if review.get("anatomicalSystem", "skeleton") != system:
        raise RigPackageError("reviewed USDZ system mismatch")
    if mesh_manifest.get("anatomicalSystem", "skeleton") != system:
        raise RigPackageError("MMATLAS1 system mismatch")
    if mesh_manifest.get("sourceRevision") != SOURCE_COMMIT:
        raise RigPackageError("unknown source revision")
    source_path = SYSTEM_SOURCES[system][0]
    if mesh_manifest.get("sourcePath") != source_path:
        raise RigPackageError("unrecognized original FBX provenance")

    usdz_file = Path(usdz_file)
    if not usdz_file.is_file() or usdz_file.stat().st_size < 128:
        raise RigPackageError("missing or empty USDZ")
    if not zipfile.is_zipfile(usdz_file):
        raise RigPackageError("USDZ must be a valid ZIP archive")
    usd_bytes = usdz_file.read_bytes()

    bindings = review.get("bindings")
    parts = mesh_manifest.get("parts")
    if not isinstance(bindings, list) or not isinstance(parts, list):
        raise RigPackageError("no reviewed hierarchy to package")
    by_path = {}
    ids = set()
    for binding in bindings:
        if not isinstance(binding, dict):
            raise RigPackageError("invalid reviewed bone binding")
        node_path = binding.get("sourceHierarchyPath")
        bone_id = binding.get("boneId")
        if not isinstance(node_path, str) or not node_path.strip():
            raise RigPackageError("source hierarchy path required")
        if node_path in by_path or not isinstance(bone_id, str) \
                or not bone_id.strip() or bone_id in ids:
            raise RigPackageError("duplicate or absent reviewed rig ID")
        ids.add(bone_id)
        by_path[node_path] = binding
    if len(parts) != len(by_path) or {
        part.get("sourceHierarchyPath") for part in parts
    } != set(by_path):
        raise RigPackageError("USDZ rig and MMATLAS1 paths differ")

    bones = []
    rest_anchor = {}
    for part in parts:
        path = part["sourceHierarchyPath"]
        binding = by_path[path]
        bone_id = binding["boneId"]
        parent = binding.get("parentBoneId")
        if parent is not None and (not isinstance(parent, str)
                                   or parent not in ids
                                   or parent == bone_id):
            raise RigPackageError("unreviewed/unknown bone parent")
        a = part["fromLandmark"]
        b = part["toLandmark"]
        start = part["restFrom"]
        end = part["restTo"]
        if a == b or any(not math.isfinite(v) for v in start + end):
            raise RigPackageError("invalid source rest anchors")
        if math.dist(start, end) <= 1e-4:
            raise RigPackageError("degenerate source bone")
        for landmark, coordinate in ((a, start), (b, end)):
            if landmark in rest_anchor and math.dist(
                    rest_anchor[landmark], coordinate) > 1e-4:
                raise RigPackageError(
                    f"conflicted source world rest landmark {landmark}"
                )
            rest_anchor[landmark] = coordinate

        bones.append({
            "id": bone_id,
            "nodePath": path,
            "parentId": parent,
            "proximalLandmark": a,
            "distalLandmark": b,
            "restStart": start,
            "restEnd": end,
            "anchorsReviewed": True,
        })
    lookup = {bone["id"]: bone["parentId"] for bone in bones}
    for bone in bones:
        visited = {bone["id"]}
        parent = bone["parentId"]
        while parent is not None:
            if parent in visited:
                raise RigPackageError("cycle in reviewed rig hierarchy")
            visited.add(parent)
            parent = lookup[parent]

    asset_file = "anatomy_atlas.usdz" if system == "skeleton" else (
        resource_base(system) + ".usdz"
    )
    if usdz_file.name != asset_file:
        raise RigPackageError("USDZ filename differs from approved layer")
    return {
        "atlasId": f"z-anatomy-{system}-{SOURCE_COMMIT[:12]}",
        "sourceURL": (
            f"{SOURCE_REPOSITORY}/blob/{SOURCE_COMMIT}/{source_path}"
        ),
        "sourceRevision": SOURCE_COMMIT,
        "attribution": "Z-Anatomy (CC BY-SA 4.0); "
                       "BodyParts3D / DBCLS (CC BY-SA 2.1 Japan)",
        "licenseIdentifier": "CC BY-SA 4.0; CC BY-SA 2.1 Japan",
        "assetFilename": asset_file,
        "assetSHA256": hashlib.sha256(usd_bytes).hexdigest(),
        "licenseReviewed": True,
        "anatomyReviewed": True,
        "bones": bones,
    }

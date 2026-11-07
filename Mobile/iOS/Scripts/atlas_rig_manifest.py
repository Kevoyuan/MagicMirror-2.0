"""Strict, Blender-independent construction of reviewed USDZ rig metadata.

Consumes the *same* reviewed per-mesh anchor/bone declarations used to
export MMATLAS1. The USDZ archive is produced by Blender's USD exporter,
not by this module. Structural success does NOT certify human anatomy,
copyright/licensing or the user's camera registration.
"""
import hashlib
import json
import math
from pathlib import Path
from usdz_package import USDZPackageError, verify_usdz

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
    try:
        verify_usdz(usdz_file)
    except USDZPackageError as exc:
        raise RigPackageError(f"invalid OpenUSD USDZ archive: {exc}") from exc
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


def verify_rig_companion(directory, mesh_manifest, system):
    """Check a shipped MMATLAS1/USDZ/hierarchy as one coherent package.

    Does not repeat the author's human joint or rights review. Only
    ensures the SAME source revisions, anchors, hierarchies and SHA are
    on disk. A structurally compliant USDZ may still be invalid USD
    geometry: independently check the USD stage on the developer Mac.
    """
    if system not in SYSTEM_SOURCES:
        raise RigPackageError("unknown anatomical system")
    directory = Path(directory)
    base = resource_base(system)
    usd_name = "anatomy_atlas.usdz" if system == "skeleton" else base + ".usdz"
    rig_name = (
        "anatomy_atlas_manifest.json" if system == "skeleton"
        else base + "_manifest.json"
    )
    usd_file = directory / usd_name
    rig_file = directory / rig_name
    if not usd_file.exists() and not rig_file.exists():
        return None
    if not usd_file.is_file() or not rig_file.is_file():
        raise RigPackageError("incomplete USDZ + reviewed rig companion")
    try:
        rig = json.loads(rig_file.read_text(encoding="utf-8"))
    except (OSError, ValueError, UnicodeError) as exc:
        raise RigPackageError("invalid reviewed rig manifest") from exc
    if not isinstance(rig, dict):
        raise RigPackageError("reviewed rig manifest must be an object")
    expected_source = (
        f"{SOURCE_REPOSITORY}/blob/{SOURCE_COMMIT}/"
        f"{SYSTEM_SOURCES[system][0]}"
    )
    if (rig.get("sourceURL") != expected_source
            or rig.get("sourceRevision") != SOURCE_COMMIT):
        raise RigPackageError("reviewed rig source does not match atlas")
    if rig.get("assetFilename") != usd_name:
        raise RigPackageError("wrong reviewed USDZ file identity")
    if rig.get("licenseReviewed") is not True or (
            rig.get("anatomyReviewed") is not True):
        raise RigPackageError("rig licensing/anatomy review not recorded")
    if not isinstance(rig.get("attribution"), str) or (
            "Z-Anatomy" not in rig["attribution"]
            or "BodyParts3D" not in rig["attribution"]):
        raise RigPackageError("rig licence credits missing")
    if not isinstance(rig.get("licenseIdentifier"), str) or (
            "CC BY-SA" not in rig["licenseIdentifier"]):
        raise RigPackageError("rig licensing identification missing")
    if not isinstance(rig.get("assetSHA256"), str) or (
            hashlib.sha256(usd_file.read_bytes()).hexdigest()
            != rig["assetSHA256"].lower()):
        raise RigPackageError("USDZ SHA-256 differs from reviewed manifest")
    try:
        verify_usdz(usd_file)
    except USDZPackageError as exc:
        raise RigPackageError(f"invalid USDZ companion: {exc}") from exc

    bones, parts = rig.get("bones"), mesh_manifest.get("parts")
    if not isinstance(bones, list) or not isinstance(parts, list) or (
            not parts or len(bones) != len(parts)):
        raise RigPackageError("rig and MMATLAS1 mesh part count mismatch")
    paths = {part["sourceHierarchyPath"]: part for part in parts}
    ids, by_id, names = set(), {}, set()
    for bone in bones:
        if not isinstance(bone, dict):
            raise RigPackageError("malformed approved bone")
        path, bone_id = bone.get("nodePath"), bone.get("id")
        if (not isinstance(path, str) or path not in paths or path in names
                or not isinstance(bone_id, str) or not bone_id.strip()
                or bone_id in ids):
            raise RigPackageError("unmatched or duplicated approved bone path")
        names.add(path)
        ids.add(bone_id)
        by_id[bone_id] = bone
        part = paths[path]
        if (bone.get("proximalLandmark") != part["fromLandmark"]
                or bone.get("distalLandmark") != part["toLandmark"]
                or bone.get("anchorsReviewed") is not True):
            raise RigPackageError("bone landmark identity differs")
        for rig_key, mesh_key in (
            ("restStart", "restFrom"), ("restEnd", "restTo")
        ):
            v = bone.get(rig_key)
            expected = part[mesh_key]
            if not isinstance(v, list) or len(v) != 3 or not all(
                type(x) in (int, float) and math.isfinite(x) for x in v
            ) or math.dist(v, expected) > 1e-4:
                raise RigPackageError("rig and MMATLAS1 rest anchors differ")
    if names != set(paths):
        raise RigPackageError("rig doesn't cover every source mesh")
    roots = 0
    for bone in bones:
        root_id = bone["id"]
        seen = {root_id}
        parent = bone.get("parentId")
        if parent is None:
            roots += 1
        while parent is not None:
            if parent not in by_id or parent in seen:
                raise RigPackageError("unknown or cyclic source bone parent")
            seen.add(parent)
            parent = by_id[parent].get("parentId")
    if not roots:
        raise RigPackageError("reviewed rig has no root segment")

    skin = directory / f"{base}.skinning.json"
    if skin.is_file():
        try:
            payload = json.loads(skin.read_text(encoding="utf-8"))
            for vertex in payload["vertices"]:
                if any(bone_id not in ids for bone_id in vertex["boneIds"]):
                    raise RigPackageError(
                        "skinning weight bone IDs not in approved rig"
                    )
        except (OSError, ValueError, KeyError, TypeError) as exc:
            if isinstance(exc, RigPackageError):
                raise
            raise RigPackageError("invalid cross-linked rig skinning") from exc
    return {"approved_bones": len(bones), "usdz": usd_name}

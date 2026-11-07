#!/usr/bin/env python3
"""Build-time-only export of a WHOLE pinned Z-Anatomy FBX for MagicMirror iOS.

Run inside Blender's bundled Python, not in the iOS application:
  blender -b --python Mobile/iOS/Scripts/export_full_atlas.py -- \
    --fbx /path/to/SkeletalSystem100.fbx \
    --review /path/to/human-reviewed-bindings.json \
    --out Mobile/iOS/Resources

No automatic bone identity guessing. EVERY mesh object must be mapped
to reviewed rest anchors and a tracked segment before export can succeed.
The script does NOT decide whether a third-party asset is licensable.
"""

import argparse
import hashlib
import json
import math
import struct
import sys
from pathlib import Path

try:
    import bpy
except ImportError as exc:
    raise SystemExit("Run using Blender: blender -b --python ... -- ...") from exc

from atlas_sources import (
    SOURCE_REPOSITORY,
    SOURCE_COMMIT,
    SYSTEM_SOURCES,
    resource_base,
)

MAX_TRIANGLE_VERTICES = 180000


def parse_args():
    args = sys.argv
    if "--" not in args:
        raise SystemExit("Expected -- before exporter arguments")
    parser = argparse.ArgumentParser()
    parser.add_argument("--fbx", type=Path, required=True)
    parser.add_argument("--system", choices=sorted(SYSTEM_SOURCES),
                        default="skeleton")
    parser.add_argument("--review", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    return parser.parse_args(args[args.index("--") + 1:])


def verify_source(path, system):
    payload = path.read_bytes()
    header = b"blob " + str(len(payload)).encode("ascii") + b"\0"
    actual = hashlib.sha1(header + payload).hexdigest()
    _, expected_bytes, expected_blob = SYSTEM_SOURCES[system]
    if len(payload) != expected_bytes or actual != expected_blob:
        raise ValueError(
            f"Wrong FBX source: bytes={len(payload)}, git_blob={actual}"
        )


def full_hierarchy_path(obj):
    elements = []
    current = obj
    while current is not None:
        elements.append(current.name)
        current = current.parent
    return "/".join(reversed(elements))


def checked_review(path, system):
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("anatomicalSystem", "skeleton") != system:
        raise ValueError("Reviewed system identity does not match source FBX")
    weights_reviewed = data.get("reviewedJointWeights") is True
    if data.get("reviewedForDistribution") is not True:
        raise ValueError("Human redistribution/license review is required")
    if data.get("reviewedJointBindings") is not True:
        raise ValueError("Human source hierarchy/anchor review is required")
    notes = data.get("modificationNotes")
    if not isinstance(notes, list) or not notes or any(
        not isinstance(x, str) or not x.strip() for x in notes
    ):
        raise ValueError("Document the modified/derived mesh changes")
    bindings = data.get("bindings")
    if not isinstance(bindings, list) or not bindings:
        raise ValueError("Supply per-mesh human-reviewed bindings")
    seen = set()
    for entry in bindings:
        path = entry.get("sourceHierarchyPath", "")
        if not path or path in seen:
            raise ValueError(f"Empty/duplicate sourceHierarchyPath: {path}")
        seen.add(path)
        if entry.get("group") not in ("arms", "legs", "torso"):
            raise ValueError(f"Unexpected group for {path}")
        a, b = entry.get("fromLandmark"), entry.get("toLandmark")
        if not isinstance(a, int) or not isinstance(b, int) or (
            not 0 <= a <= 32 or not 0 <= b <= 32 or a == b
        ):
            raise ValueError(f"Invalid tracked joint pair: {path}")
        for field in ("restFrom", "restTo"):
            v = entry.get(field)
            if not isinstance(v, list) or len(v) != 3 or not all(
                isinstance(x, (int, float)) and math.isfinite(x) for x in v
            ):
                raise ValueError(f"Invalid reviewed rest anchor: {field}, {path}")
        if math.dist(entry["restFrom"], entry["restTo"]) <= 1e-5:
            raise ValueError(f"Coincident reviewed rest anchors: {path}")
        if weights_reviewed:
            mapping = entry.get("vertexGroupToBoneId")
            if not isinstance(mapping, dict) or not mapping or any(
                not isinstance(k, str) or not k.strip()
                or not isinstance(v, str) or not v.strip()
                for k, v in mapping.items()
            ):
                raise ValueError(f"Reviewed skin group mapping required: {path}")
    return data, {entry["sourceHierarchyPath"]: entry for entry in bindings}


def main():
    args = parse_args()
    verify_source(args.fbx, args.system)
    review, bindings = checked_review(args.review, args.system)
    source_path, _, _ = SYSTEM_SOURCES[args.system]
    base = resource_base(args.system)
    model_file = f"{base}.mmgeom"
    manifest_file = f"{base}.manifest.json"
    export_skin = review.get("reviewedJointWeights") is True
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.fbx(filepath=str(args.fbx))

    source_meshes = {
        full_hierarchy_path(obj): obj
        for obj in bpy.data.objects if obj.type == "MESH"
    }
    if set(source_meshes) != set(bindings):
        missing = sorted(set(source_meshes) - set(bindings))
        extra = sorted(set(bindings) - set(source_meshes))
        raise ValueError(
            "Atlas hierarchy not fully reviewed; "
            f"unmapped mesh examples={missing[:12]}, "
            f"unknown binding examples={extra[:12]}"
        )

    depsgraph = bpy.context.evaluated_depsgraph_get()
    raw = bytearray()
    parts = []
    skin_vertices = []
    count = 0
    for source_path in sorted(source_meshes):
        obj = source_meshes[source_path]
        entry = bindings[source_path]
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        if mesh is None:
            raise ValueError(f"Cannot evaluate mesh: {source_path}")
        vertex_start = count
        try:
            mesh.calc_loop_triangles()
            mat = evaluated.matrix_world
            normal_matrix = mat.to_3x3().inverted_safe().transposed()
            for triangle in mesh.loop_triangles:
                for vid in triangle.vertices:
                    v = mesh.vertices[vid]
                    if export_skin:
                        group_map = entry["vertexGroupToBoneId"]
                        reviewed_weights = []
                        for influence in v.groups:
                            if influence.weight <= 1e-6:
                                continue
                            source_group = obj.vertex_groups[influence.group].name
                            if source_group not in group_map:
                                raise ValueError(
                                    f"Unreviewed source vertex group: "
                                    f"{source_path}, {source_group}"
                                )
                            weight = float(influence.weight)
                            if not math.isfinite(weight):
                                raise ValueError("Nonfinite authored joint weight")
                            reviewed_weights.append(
                                (group_map[source_group], weight)
                            )
                        if not 1 <= len(reviewed_weights) <= 4:
                            raise ValueError(
                                f"Requires 1–4 audited vertex groups at "
                                f"{source_path} vertex {vid}"
                            )
                        total = sum(value for _, value in reviewed_weights)
                        if not 0.98 <= total <= 1.02:
                            raise ValueError(
                                f"Unnormalized authored weights at "
                                f"{source_path} vertex {vid}: {total}"
                            )
                        reviewed_weights.sort(key=lambda item: -item[1])
                        ids = [item[0] for item in reviewed_weights]
                        weights = [item[1] / total for item in reviewed_weights]
                        while len(ids) < 4:
                            ids.append(ids[0])
                            weights.append(0.0)
                        skin_vertices.append({
                            "boneIds": ids,
                            "weights": weights,
                        })
                    p = mat @ v.co
                    normal = normal_matrix @ v.normal
                    if normal.length_squared <= 1e-9:
                        normal = normal_matrix @ triangle.normal
                    normal.normalize()
                    values = (p.x, p.y, p.z, normal.x, normal.y, normal.z)
                    if not all(math.isfinite(component) for component in values):
                        raise ValueError(f"Nonfinite atlas vertex: {source_path}")
                    raw += struct.pack("<6f", *values)
                    count += 1
                    if count > MAX_TRIANGLE_VERTICES:
                        raise ValueError(
                            "Unoptimized atlas exceeds 180k mobile vertices. "
                            "Optimize source with reviewed modifications first."
                        )
        finally:
            evaluated.to_mesh_clear()
        used = count - vertex_start
        if used <= 0 or used % 3:
            raise ValueError(f"Empty or invalid triangles: {source_path}")
        parts.append({
            "sourceHierarchyPath": source_path,
            "displayName": entry.get("displayName", obj.name),
            "group": entry["group"],
            "fromLandmark": entry["fromLandmark"],
            "toLandmark": entry["toLandmark"],
            "restFrom": entry["restFrom"],
            "restTo": entry["restTo"],
            "vertexOffset": vertex_start,
            "vertexCount": used,
        })

    args.out.mkdir(parents=True, exist_ok=True)
    binary = b"MMATLAS1" + struct.pack("<I", count) + raw
    model_sha = hashlib.sha256(binary).hexdigest()
    (args.out / model_file).write_bytes(binary)
    modification_notes = review["modificationNotes"] + [
        "Triangulated all reviewed source mesh surfaces; preserved names, "
        "hierarchy paths and source world-space coordinates",
    ]
    manifest = {
        "schemaVersion": 1,
        "sourceRepository": SOURCE_REPOSITORY,
        "sourceRevision": SOURCE_COMMIT,
        "sourcePath": source_path,
        "anatomicalSystem": args.system,
        "modelFile": model_file,
        "modelSHA256": model_sha,
        "licenseIds": ["CC BY-SA 2.1 Japan", "CC BY-SA 4.0"],
        "attribution": [
            "BodyParts3D — The Database Center for Life Science (DBCLS)",
            "Z-Anatomy — The libre 3D atlas of anatomy",
        ],
        "modificationNotes": modification_notes,
        "reviewedForDistribution": True,
        "reviewedJointBindings": True,
        "parts": parts,
    }
    (args.out / manifest_file).write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False),
        encoding="utf-8"
    )
    if export_skin:
        skinning = {
            "schemaVersion": 1,
            "sourceRevision": SOURCE_COMMIT,
            "modelSHA256": model_sha,
            "reviewedJointWeights": True,
            "vertices": skin_vertices,
        }
        (args.out / f"{base}.skinning.json").write_text(
            json.dumps(skinning, indent=2, ensure_ascii=False),
            encoding="utf-8"
        )
    (args.out / f"{base}.ATTRIBUTION.txt").write_text(
        "BodyParts3D — The Database Center for Life Science — CC BY-SA 2.1 Japan\n"
        "Z-Anatomy — The open source atlas of anatomy — CC BY-SA 4.0\n"
        f"Source: {SOURCE_REPOSITORY}, commit {SOURCE_COMMIT}, {source_path}\n"
        "Modifications:\n" + "\n".join(f"- {m}" for m in modification_notes) +
        "\nSee respective source licenses before distribution.\n",
        encoding="utf-8"
    )
    # Independently re-open emitted artifacts after writing them, so the
    # Blender export cannot claim success for an inconsistent binary/manifest.
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from verify_atlas_package import verify_package
    verify_package(args.out, system=args.system)
    print(f"Built {count} vertices / {len(parts)} reviewed meshes, sha256={model_sha}")
    print("Asset is developer-produced, NOT a human/device anatomical validation.")


if __name__ == "__main__":
    main()

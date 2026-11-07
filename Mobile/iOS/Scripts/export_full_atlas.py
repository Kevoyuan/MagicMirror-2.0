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

SOURCE_REPOSITORY = "https://github.com/LluisV/Z-Anatomy"
SOURCE_COMMIT = "6c7f9016bd5899ac8edafd31b9900c151df42ed6"
SOURCE_PATH = "Resources/Models/FBX/SkeletalSystem100.fbx"
SOURCE_GIT_BLOB = "7c62e45211bf3992bb7239170343e06e2b073865"
SOURCE_BYTES = 41339660
MAX_TRIANGLE_VERTICES = 180000
MODEL_FILE = "skeleton_atlas.mmgeom"
MANIFEST_FILE = "skeleton_atlas.manifest.json"


def parse_args():
    args = sys.argv
    if "--" not in args:
        raise SystemExit("Expected -- before exporter arguments")
    parser = argparse.ArgumentParser()
    parser.add_argument("--fbx", type=Path, required=True)
    parser.add_argument("--review", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    return parser.parse_args(args[args.index("--") + 1:])


def verify_source(path):
    payload = path.read_bytes()
    header = b"blob " + str(len(payload)).encode("ascii") + b"\0"
    actual = hashlib.sha1(header + payload).hexdigest()
    if len(payload) != SOURCE_BYTES or actual != SOURCE_GIT_BLOB:
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


def checked_review(path):
    data = json.loads(path.read_text(encoding="utf-8"))
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
    return data, {entry["sourceHierarchyPath"]: entry for entry in bindings}


def main():
    args = parse_args()
    verify_source(args.fbx)
    review, bindings = checked_review(args.review)
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
    (args.out / MODEL_FILE).write_bytes(binary)
    modification_notes = review["modificationNotes"] + [
        "Triangulated all reviewed source mesh surfaces; preserved names, "
        "hierarchy paths and source world-space coordinates",
    ]
    manifest = {
        "schemaVersion": 1,
        "sourceRepository": SOURCE_REPOSITORY,
        "sourceRevision": SOURCE_COMMIT,
        "sourcePath": SOURCE_PATH,
        "modelFile": MODEL_FILE,
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
    (args.out / MANIFEST_FILE).write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False),
        encoding="utf-8"
    )
    (args.out / "skeleton_atlas.ATTRIBUTION.txt").write_text(
        "BodyParts3D — The Database Center for Life Science — CC BY-SA 2.1 Japan\n"
        "Z-Anatomy — The open source atlas of anatomy — CC BY-SA 4.0\n"
        f"Source: {SOURCE_REPOSITORY}, commit {SOURCE_COMMIT}, {SOURCE_PATH}\n"
        "Modifications:\n" + "\n".join(f"- {m}" for m in modification_notes) +
        "\nSee respective source licenses before distribution.\n",
        encoding="utf-8"
    )
    print(f"Built {count} vertices / {len(parts)} reviewed meshes, sha256={model_sha}")
    print("Asset is developer-produced, NOT a human/device anatomical validation.")


if __name__ == "__main__":
    main()

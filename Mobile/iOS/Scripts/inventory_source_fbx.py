#!/usr/bin/env python3
"""Generate a NON-APPROVED real FBX inventory for manual rights/rig review.

Run only with Blender installed on a developer machine. It verifies the
original pinned FBX *bytes*, enumerates Blender-imported MESH objects,
and emits exact source hierarchy names and a deliberately LOCKED review
template. It cannot determine component origin or anatomical anchors.
No original FBX or derived model is published by this tool.

blender -b --python Mobile/iOS/Scripts/inventory_source_fbx.py -- \\
  --system skeleton --fbx /private/SkeletalSystem100.fbx \\
  --out /private/skeleton.audit-draft.json
"""
import argparse
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from atlas_sources import SOURCE_REPOSITORY, SOURCE_COMMIT, SYSTEM_SOURCES
from atlas_source_inventory import make_unapproved_review


def _args():
    args = sys.argv
    if "--" not in args:
        raise SystemExit("Expected -- before inventory arguments")
    p = argparse.ArgumentParser()
    p.add_argument("--fbx", required=True, type=Path)
    p.add_argument("--system", required=True, choices=sorted(SYSTEM_SOURCES))
    p.add_argument("--out", required=True, type=Path)
    return p.parse_args(args[args.index("--") + 1:])


def hierarchy(obj):
    components = []
    while obj is not None:
        components.append(obj.name)
        obj = obj.parent
    return "/".join(reversed(components))


def main():
    try:
        import bpy
    except ImportError as exc:
        raise SystemExit("Blender/bpy required on developer computer") from exc
    from export_full_atlas import verify_source
    args = _args()
    verify_source(args.fbx, args.system)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.fbx(filepath=str(args.fbx))
    rows = []
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        rows.append({
            "sourceHierarchyPath": hierarchy(obj),
            "vertexCount": len(obj.data.vertices),
            "polygonCount": len(obj.data.polygons),
            "vertexGroups": sorted(g.name for g in obj.vertex_groups),
            "hasArmatureModifier": any(
                modifier.type == "ARMATURE" for modifier in obj.modifiers
            ),
        })
    result = make_unapproved_review(
        source_repository=SOURCE_REPOSITORY, source_revision=SOURCE_COMMIT,
        source_path=SYSTEM_SOURCES[args.system][0],
        system=args.system, meshes=rows
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n",
                        encoding="utf-8")
    print(f"Wrote {len(rows)} actual source meshes to {args.out}")
    print("ALL component licenses, pose anchors and rig IDs are intentionally"
          " UNREVIEWED; human audit required before any packaging.")


if __name__ == "__main__":
    main()

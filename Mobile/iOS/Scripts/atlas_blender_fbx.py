"""Version-aware native FBX import shared by inspection and production export.

Blender 4.5+ ships a native C++ FBX importer. Reusing the SAME importer
in inventory and export avoids reviewing one object hierarchy and exporting
another. Fail rather than fallback silently after an importer error.
"""


def import_pinned_fbx(filepath):
    import bpy
    if bpy.app.version >= (4, 5, 0):
        result = bpy.ops.wm.fbx_import(filepath=str(filepath))
        importer = "native-wm.fbx_import"
    else:
        result = bpy.ops.import_scene.fbx(filepath=str(filepath))
        importer = "legacy-import_scene.fbx"
    if "FINISHED" not in result:
        raise RuntimeError(f"Reviewed source FBX import failed: {importer}")
    print(f"Verified original FBX imported with {importer}")
    return importer

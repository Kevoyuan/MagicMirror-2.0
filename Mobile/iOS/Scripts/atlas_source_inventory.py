"""Pure model-inventory review template generator; never auto-approves FBX.

The Blender importer passes EXACT source mesh identities from an original
SHA-verified FBX. This data facilitates manual mesh-by-mesh attribution,
skin weighting, topology review and a coherent anatomical rig.
"""
from copy import deepcopy


class InventoryError(ValueError):
    pass


def make_unapproved_review(*, source_repository, source_revision,
                           source_path, system, meshes):
    if not isinstance(meshes, list) or not meshes:
        raise InventoryError("FBX has no source mesh objects")
    if not isinstance(source_revision, str) or len(source_revision) != 40:
        raise InventoryError("Pinned source revision required")
    seen = set()
    result = []
    for item in sorted(meshes, key=lambda v: v.get("sourceHierarchyPath", "")):
        path = item.get("sourceHierarchyPath")
        if not isinstance(path, str) or not path or path in seen:
            raise InventoryError("Duplicate or unnamed source mesh")
        seen.add(path)
        vertices = item.get("vertexCount")
        polygons = item.get("polygonCount")
        if type(vertices) is not int or vertices < 0 or (
            type(polygons) is not int or polygons < 0
        ):
            raise InventoryError("Invalid source mesh dimensions")
        groups = item.get("vertexGroups")
        if not isinstance(groups, list) or not all(
            isinstance(g, str) and g for g in groups
        ):
            raise InventoryError("Vertex group metadata required")
        result.append({
            "sourceHierarchyPath": path,
            "displayName": path.rsplit("/", 1)[-1],
            "sourceInspection": {
                "vertexCount": vertices,
                "polygonCount": polygons,
                "hasRenderableTriangles": vertices >= 3 and polygons > 0,
                "requiresHumanGeometryReview": vertices < 3 or polygons == 0,
                "vertexGroups": sorted(groups),
                "hasArmatureModifier": bool(
                    item.get("hasArmatureModifier", False)
                ),
            },
            "group": None,
            "fromLandmark": None,
            "toLandmark": None,
            "restFrom": None,
            "restTo": None,
            "boneId": None,
            "parentBoneId": None,
            "anchorsReviewed": False,
            "approvedSkinBoneIds": [],
            "vertexGroupToBoneId": {},
            "componentLicense": {
                "licenseId": "UNRESOLVED",
                "originalSource": "",
                "sourceMeshIdentity": path,
                "attribution": "",
                "originReviewNotes": "",
                "evidenceURL": "",
                "humanReviewed": False,
                "commercialReuseConfirmed": False,
            },
        })
    return {
        "anatomicalSystem": system,
        "sourceRepository": source_repository,
        "sourceRevision": source_revision,
        "sourcePath": source_path,
        "inventoryOnly": True,
        "reviewedForDistribution": False,
        "licenseReviewed": False,
        "reviewedJointBindings": False,
        "reviewedRigHierarchy": False,
        "reviewedJointWeights": False,
        "reviewedUSDZHierarchy": False,
        "modificationNotes": [],
        "componentLicenseReview": {
            "reviewerName": "", "reviewDate": "",
            "intendedUse": "commercial-distribution",
            "reviewNotes": "",
        },
        "bindings": deepcopy(result),
    }

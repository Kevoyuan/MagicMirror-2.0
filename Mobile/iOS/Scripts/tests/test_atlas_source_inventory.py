"""Synthetic source inventory; this test does not import actual FBX."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from atlas_source_inventory import make_unapproved_review, InventoryError
from atlas_license_evidence import (
    LicenseEvidenceError, reviewed_bindings_license_evidence
)


class SourceInventoryTests(unittest.TestCase):
    def test_real_hierarchy_names_preserved_and_everything_unapproved(self):
        output = make_unapproved_review(
            source_repository="https://github.com/example/test",
            source_revision="a" * 40,
            source_path="test.fbx",
            system="skeleton",
            meshes=[
                {"sourceHierarchyPath": "Pelvis/Right", "vertexCount": 10,
                 "polygonCount": 8, "vertexGroups": [],
                 "hasArmatureModifier": False},
                {"sourceHierarchyPath": "Spine/Left", "vertexCount": 12,
                 "polygonCount": 10, "vertexGroups": ["armature"]},
            ],
        )
        self.assertEqual(
            [x["sourceHierarchyPath"] for x in output["bindings"]],
            ["Pelvis/Right", "Spine/Left"]
        )
        self.assertEqual(output["bindings"][1]["sourceInspection"]["vertexGroups"],
                         ["armature"])
        self.assertFalse(output["reviewedForDistribution"])
        self.assertTrue(all(not b["componentLicense"]["humanReviewed"]
                            and b["boneId"] is None for b in output["bindings"]))
        with self.assertRaises(LicenseEvidenceError):
            reviewed_bindings_license_evidence(
                output, output["bindings"]
            )

    def test_empty_geometry_preserved_for_explicit_human_remediation(self):
        output = make_unapproved_review(
            source_repository="https://example.org",
            source_revision="a" * 40, source_path="x.fbx",
            system="skeleton",
            meshes=[{"sourceHierarchyPath": "empty-holder", "vertexCount": 0,
                     "polygonCount": 0, "vertexGroups": []}],
        )
        self.assertEqual(len(output["bindings"]), 1)
        inspection = output["bindings"][0]["sourceInspection"]
        self.assertFalse(inspection["hasRenderableTriangles"])
        self.assertTrue(inspection["requiresHumanGeometryReview"])
        self.assertFalse(output["reviewedForDistribution"])

    def test_bad_source_identity_or_no_mesh_fails(self):
        base = dict(source_repository="https://example.org",
                    source_revision="a" * 40, source_path="x.fbx",
                    system="skeleton")
        for meshes in (
            [], [{"sourceHierarchyPath": "a", "vertexCount": -1,
                  "polygonCount": 1, "vertexGroups": []}],
            [{"sourceHierarchyPath": "a", "vertexCount": 3,
              "polygonCount": 1, "vertexGroups": []}] * 2
        ):
            with self.assertRaises(InventoryError):
                make_unapproved_review(**base, meshes=meshes)


if __name__ == "__main__":
    unittest.main()

"""Conservative Unity whole-atlas inventory audits, no real FBX or Unity required."""
from copy import deepcopy
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from Tools.anatomy_tools.audit_unity_inventory import (
    MANIFEST, SOURCE_PATH, pinned_source_issues, validate_inventory, main
)


def synthetic_inventory():
    # Paths below are deliberately synthetic, not verified Z-Anatomy names.
    return {
        "sourceAssetPath": SOURCE_PATH,
        "rendererCount": 3,
        "entries": [
            {
                "hierarchyPath": "Anatomy%20Meshes@0/Left%20Humerus@0/Mesh@0",
                "rendererType": "MeshRenderer",
                "objectName": "Left Humerus (synthetic)",
                "suggestedGroup": "LeftUpperArm",
                "verified": False,
            },
            {
                "hierarchyPath": "Anatomy%20Meshes@0/Right%20Radius@1/Mesh@0",
                "rendererType": "MeshRenderer",
                "objectName": "Right Radius (synthetic)",
                "suggestedGroup": "RightForearm",
                "verified": False,
            },
            {
                "hierarchyPath": "Anatomy%20Meshes@0/Unassigned@2/Mesh@0",
                "rendererType": "MeshRenderer",
                "objectName": "Unassigned synthetic mesh",
                "suggestedGroup": "",
                "verified": False,
            },
        ],
    }


class AtlasInventoryAuditTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))

    def test_pinned_manifest_matches_fetcher(self):
        self.assertEqual(pinned_source_issues(self.manifest), [])

    def test_extracts_candidates_but_never_marks_reviewed(self):
        result = validate_inventory(synthetic_inventory(), self.manifest)
        self.assertEqual(result["rendererCount"], 3)
        self.assertEqual(result["unassignedOrUnsupportedRendererCount"], 1)
        self.assertFalse(result["readyForRealAnatomyRig"])
        self.assertFalse(result["identityAndAnchorsReviewed"])
        self.assertFalse(result["licensesReviewed"])
        self.assertEqual([c["segmentHint"] for c in result["unverifiedCandidates"]],
                         ["LeftUpperArm", "RightForearm"])
        for candidate in result["unverifiedCandidates"]:
            self.assertFalse(candidate["reviewed"])
            self.assertIsNone(candidate["atlasStartLocal"])
            self.assertIsNone(candidate["atlasEndLocal"])

    def test_rejects_conflicting_source_revision(self):
        wrong = deepcopy(self.manifest)
        for entry in wrong["models"]:
            if entry["file"] == "SkeletalSystem100.fbx":
                entry["sourceRevision"] = "not-the-pinned-source"
        with self.assertRaisesRegex(ValueError, "sourceRevision"):
            validate_inventory(synthetic_inventory(), wrong)

    def test_rejects_missing_unreviewed_asset_gate(self):
        wrong = deepcopy(self.manifest)
        wrong["models"][0]["distributed"] = True
        with self.assertRaisesRegex(ValueError, "distributed"):
            validate_inventory(synthetic_inventory(), wrong)

    def test_rejects_wrong_source_and_renderer_count(self):
        inventory = synthetic_inventory()
        inventory["sourceAssetPath"] = "Assets/SomethingElse.fbx"
        inventory["rendererCount"] = 2
        with self.assertRaisesRegex(ValueError, "source|count"):
            validate_inventory(inventory, self.manifest)

    def test_rejects_duplicate_renderer_path(self):
        inventory = synthetic_inventory()
        inventory["entries"][1]["hierarchyPath"] = inventory["entries"][0]["hierarchyPath"]
        with self.assertRaisesRegex(ValueError, "duplicate"):
            validate_inventory(inventory, self.manifest)

    def test_rejects_claimed_anatomical_review(self):
        inventory = synthetic_inventory()
        inventory["entries"][0]["verified"] = True
        with self.assertRaisesRegex(ValueError, "cannot claim human review"):
            validate_inventory(inventory, self.manifest)

    def test_rejects_unknown_segment(self):
        inventory = synthetic_inventory()
        inventory["entries"][0]["suggestedGroup"] = "LungLobeFromName"
        with self.assertRaisesRegex(ValueError, "unsupported segment"):
            validate_inventory(inventory, self.manifest)

    def test_detects_parent_child_conflicts_without_auto_binding(self):
        inventory = synthetic_inventory()
        inventory["entries"][0]["hierarchyPath"] = "Root@0/Arm@0"
        inventory["entries"][1]["hierarchyPath"] = "Root@0/Arm@0/Mesh@0"
        result = validate_inventory(inventory, self.manifest)
        self.assertEqual(result["potentialParentChildRendererPathConflicts"],
                         [["Root@0/Arm@0", "Root@0/Arm@0/Mesh@0"]])
        self.assertFalse(result["readyForRealAnatomyRig"])

    def test_skinned_only_is_not_a_rigid_motion_group(self):
        inventory = synthetic_inventory()
        inventory["entries"][0]["rendererType"] = "SkinnedMeshRenderer"
        result = validate_inventory(inventory, self.manifest)
        self.assertEqual(result["skinnedMeshRendererCountUnsupportedByCurrentRig"], 1)
        self.assertNotIn("LeftUpperArm",
                         [c["segmentHint"] for c in result["unverifiedCandidates"]])

    def test_cli_writes_audit_without_models(self):
        with TemporaryDirectory() as tmp:
            source = Path(tmp) / "synthetic.json"
            report = Path(tmp) / "candidate-report.json"
            source.write_text(json.dumps(synthetic_inventory()), encoding="utf-8")
            self.assertEqual(main(["--inventory", str(source),
                                   "--report", str(report)]), 0)
            result = json.loads(report.read_text(encoding="utf-8"))
            self.assertFalse(result["readyForRealAnatomyRig"])


if __name__ == "__main__":
    unittest.main()

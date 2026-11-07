"""Synthetic parent-connected USDZ manifest tests. No licensed real FBX."""
import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from atlas_sources import SYSTEM_SOURCES, SOURCE_COMMIT  # noqa: E402
from atlas_rig_manifest import (  # noqa: E402
    build_rig_manifest, verify_rig_companion, RigPackageError,
)
from usdz_package import pack_usdc_as_usdz  # noqa: E402


class ReviewedUSDZRigManifestTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name) / "muscles_atlas.usdz"
        # Synthetic USD-crate magic tests archive structure and rig
        # metadata only; it is NOT a parsed or anatomy-reviewed scene.
        synthetic_stage = self.path.with_suffix(".usdc")
        synthetic_stage.write_bytes(b"PXR-USDC" + b"\0" * 512)
        pack_usdc_as_usdz(synthetic_stage, self.path)
        self.parts = [
            {
                "sourceHierarchyPath": "synthetic/upper",
                "fromLandmark": 11, "toLandmark": 13,
                "restFrom": [-0.2, 0.4, 0],
                "restTo": [-0.4, 0.2, 0],
            },
            {
                "sourceHierarchyPath": "synthetic/lower",
                "fromLandmark": 13, "toLandmark": 15,
                "restFrom": [-0.4, 0.2, 0],
                "restTo": [-0.5, -0.1, 0],
            },
        ]
        self.source = {
            "sourceRevision": SOURCE_COMMIT,
            "sourcePath": SYSTEM_SOURCES["muscles"][0],
            "anatomicalSystem": "muscles",
            "parts": self.parts,
        }
        self.review = {
            "anatomicalSystem": "muscles",
            "reviewedForDistribution": True,
            "reviewedJointBindings": True,
            "reviewedUSDZHierarchy": True,
            "bindings": [
                {"sourceHierarchyPath": "synthetic/upper",
                 "boneId": "upper", "parentBoneId": None},
                {"sourceHierarchyPath": "synthetic/lower",
                 "boneId": "lower", "parentBoneId": "upper"},
            ],
        }

    def validate(self):
        return build_rig_manifest(
            self.review, self.source, self.path, "muscles"
        )

    def test_two_bones_form_coherent_reviewed_usdz_package(self):
        manifest = self.validate()
        self.assertEqual(manifest["assetFilename"], "muscles_atlas.usdz")
        self.assertEqual(
            manifest["assetSHA256"],
            hashlib.sha256(self.path.read_bytes()).hexdigest()
        )
        self.assertEqual([b["id"] for b in manifest["bones"]],
                         ["upper", "lower"])
        self.assertEqual(
            manifest["bones"][1]["parentId"], "upper"
        )
        self.assertTrue(manifest["licenseReviewed"])
        self.assertTrue(manifest["anatomyReviewed"])

    def test_no_review_flags_unknown_parent_cycles_or_fake_ids(self):
        for flag in ["reviewedForDistribution",
                     "reviewedJointBindings", "reviewedUSDZHierarchy"]:
            with self.subTest(flag=flag):
                self.review[flag] = False
                with self.assertRaises(RigPackageError):
                    self.validate()
                self.review[flag] = True

        bad = copy.deepcopy(self.review["bindings"])
        bad[1]["parentBoneId"] = "unknown"
        self.review["bindings"] = bad
        with self.assertRaises(RigPackageError):
            self.validate()
        bad[1]["parentBoneId"] = "upper"
        bad[0]["parentBoneId"] = "lower"
        with self.assertRaises(RigPackageError):
            self.validate()
        bad[0]["parentBoneId"] = None
        bad[1]["boneId"] = "upper"
        with self.assertRaises(RigPackageError):
            self.validate()

    def test_source_part_mismatch_and_conflicting_landmark(self):
        original = self.source["parts"]
        self.source["parts"] = original[:1]
        with self.assertRaises(RigPackageError):
            self.validate()
        self.source["parts"] = copy.deepcopy(original)
        self.source["parts"][1]["restFrom"] = [-0.2, 0.2, 0]
        with self.assertRaises(RigPackageError):
            self.validate()
        self.source["parts"] = original

    def test_invalid_usdz_not_permitted_as_approved_hierarchy(self):
        self.path.write_bytes(b"not a USDZ archive")
        with self.assertRaises(RigPackageError):
            self.validate()

    def test_cross_checks_real_artifact_ids_sha_anchors_and_parents(self):
        manifest = self.validate()
        path = self.path.parent / "muscles_atlas_manifest.json"
        path.write_text(json.dumps(manifest), encoding="utf-8")
        report = verify_rig_companion(
            self.path.parent, self.source, "muscles"
        )
        self.assertEqual(report["approved_bones"], 2)

        for key, change in [
            ("assetSHA256", "0" * 64),
            ("sourceRevision", "wrong-source-revision"),
            ("assetFilename", "skeleton_atlas.usdz"),
        ]:
            with self.subTest(key=key):
                original = manifest[key]
                manifest[key] = change
                path.write_text(json.dumps(manifest), encoding="utf-8")
                with self.assertRaises(RigPackageError):
                    verify_rig_companion(
                        self.path.parent, self.source, "muscles"
                    )
                manifest[key] = original

        manifest["bones"][1]["restStart"] = [2, 2, 2]
        path.write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(RigPackageError, "rest anchors"):
            verify_rig_companion(self.path.parent, self.source, "muscles")

        manifest["bones"][1]["restStart"] = [-0.4, 0.2, 0]
        path.write_text(json.dumps(manifest), encoding="utf-8")
        self.assertEqual(
            verify_rig_companion(
                self.path.parent, self.source, "muscles"
            )["approved_bones"], 2
        )

    def test_missing_usdz_or_unknown_skinned_joint_fails_closed(self):
        manifest = self.validate()
        rig_file = self.path.parent / "muscles_atlas_manifest.json"
        rig_file.write_text(json.dumps(manifest), encoding="utf-8")
        skinning = self.path.parent / "muscles_atlas.skinning.json"
        skinning.write_text(json.dumps({
            "vertices": [{
                "boneIds": ["upper", "missing", "upper", "upper"],
                "weights": [1, 0, 0, 0]
            }]
        }), encoding="utf-8")
        with self.assertRaisesRegex(RigPackageError, "bone IDs"):
            verify_rig_companion(
                self.path.parent, self.source, "muscles"
            )
        skinning.unlink()
        self.path.unlink()
        with self.assertRaisesRegex(RigPackageError, "incomplete"):
            verify_rig_companion(
                self.path.parent, self.source, "muscles"
            )


if __name__ == "__main__":
    unittest.main()

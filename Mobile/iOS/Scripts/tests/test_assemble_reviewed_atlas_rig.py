"""Entirely synthetic unit fixtures; never an actual Z-Anatomy review."""
import copy
import hashlib
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from assemble_reviewed_atlas_rig import (  # noqa: E402
    AssemblyError, assemble
)


class AssembleReviewedAtlasRigTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.system = "skeleton"
        specs = [
            ("shoulder/left", "left-upper", 11, 13,
             [-0.2, 0.4, 0], [-0.4, 0.2, 0]),
            ("shoulder/right", "right-upper", 12, 14,
             [0.2, 0.4, 0], [0.4, 0.2, 0]),
            ("hip/left", "left-leg", 23, 25,
             [-0.16, -0.1, 0], [-0.2, -0.5, 0]),
            ("hip/right", "right-leg", 24, 26,
             [0.16, -0.1, 0], [0.2, -0.5, 0]),
        ]
        self.parts = []
        self.bindings = []
        self.vertices = []
        for path, bone_id, a, b, start, end in specs:
            begin = len(self.vertices)
            self.vertices.extend([
                (*start, 0, 0, 1),
                (*end, 0, 0, 1),
                (start[0] + 0.03, start[1] + 0.01,
                 start[2], 0, 0, 1)
            ])
            self.parts.append({
                "sourceHierarchyPath": path,
                "displayName": bone_id + " synthetic",
                "group": "arms" if a < 20 else "legs",
                "fromLandmark": a, "toLandmark": b,
                "restFrom": start, "restTo": end,
                "vertexOffset": begin, "vertexCount": 3
            })
            self.bindings.append({
                "sourceHierarchyPath": path,
                "boneId": bone_id, "parentBoneId": None,
                "anchorsReviewed": True
            })
        self.review = {
            "reviewedForDistribution": True,
            "reviewedJointBindings": True,
            "reviewedRigHierarchy": True,
            "licenseReviewed": True,
            "bindings": self.bindings
        }
        self.meta = {
            "schemaVersion": 1,
            "sourceRepository": "https://github.com/example/synthetic",
            "sourceRevision": "a" * 40,
            "sourcePath": "synthetic-only/test.fbx",
            "modelFile": "skeleton_atlas.mmgeom",
            "modelSHA256": "",
            "licenseIds": ["synthetic-license-fixture"],
            "attribution": ["synthetic fixture, no licensed anatomy"],
            "modificationNotes": ["handwritten synthetic triangles"],
            "reviewedForDistribution": True,
            "reviewedJointBindings": True,
            "parts": self.parts
        }
        self.write()

    def write(self):
        base = self.system + "_atlas"
        payload = b"MMATLAS1" + struct.pack("<I", len(self.vertices))
        payload += b"".join(struct.pack("<6f", *v)
                            for v in self.vertices)
        (self.root / (base + ".mmgeom")).write_bytes(payload)
        self.meta["modelFile"] = base + ".mmgeom"
        self.meta["modelSHA256"] = hashlib.sha256(payload).hexdigest()
        if self.system != "skeleton":
            self.meta["anatomicalSystem"] = self.system
        (self.root / (base + ".manifest.json")).write_text(
            json.dumps(self.meta), encoding="utf-8"
        )
        (self.root / "review.json").write_text(
            json.dumps(self.review), encoding="utf-8"
        )

    def build(self):
        return assemble(self.root, self.root / "review.json",
                        self.system)

    def test_assemble_exact_bone_hierarchy_without_second_usdz(self):
        result = self.build()
        self.assertEqual(result["bones"], 4)
        self.assertEqual(result["vertex_count"], 12)
        output = self.root / "anatomy_atlas_manifest.json"
        metadata = json.loads(output.read_text(encoding="utf-8"))
        self.assertEqual(metadata["assetFilename"],
                         "skeleton_atlas.mmgeom")
        self.assertEqual(metadata["assetSHA256"],
                         self.meta["modelSHA256"])
        self.assertEqual(metadata["sourceRevision"], "a" * 40)
        self.assertEqual(len(metadata["bones"]), 4)
        self.assertEqual(metadata["bones"][0]["nodePath"],
                         self.parts[0]["sourceHierarchyPath"])
        self.assertTrue(metadata["licenseReviewed"])
        self.assertTrue(metadata["anatomyReviewed"])

    def test_source_specific_system_prefixes(self):
        self.system = "muscles"
        self.write()
        result = self.build()
        self.assertEqual(result["filename"],
                         "muscles_atlas_manifest.json")
        self.assertEqual(json.loads(
            (self.root / result["filename"]).read_text()
        )["assetFilename"], "muscles_atlas.mmgeom")

    def test_no_flags_or_unreviewed_anchor_cannot_be_assembled(self):
        for field in ("reviewedForDistribution", "reviewedJointBindings",
                      "reviewedRigHierarchy", "licenseReviewed"):
            with self.subTest(field=field):
                old = self.review[field]
                self.review[field] = False
                self.write()
                with self.assertRaisesRegex(AssemblyError, "review"):
                    self.build()
                self.review[field] = old
        self.review["bindings"][0]["anchorsReviewed"] = False
        self.write()
        with self.assertRaises(AssemblyError):
            self.build()

    def test_duplicate_bone_unknown_parent_cycle_and_missing_mesh(self):
        cases = [
            lambda records: records[1].update(
                boneId=records[0]["boneId"]
            ),
            lambda records: records[0].update(
                parentBoneId="unknown-id"
            ),
            lambda records: (
                records[0].update(parentBoneId=records[1]["boneId"]),
                records[1].update(parentBoneId=records[0]["boneId"])
            ),
            lambda records: records.pop()
        ]
        original = copy.deepcopy(self.bindings)
        for modify in cases:
            self.review["bindings"] = copy.deepcopy(original)
            modify(self.review["bindings"])
            self.write()
            with self.assertRaises(AssemblyError):
                self.build()
        self.review["bindings"] = copy.deepcopy(original)

    def test_binary_digest_and_rest_anchor_mismatch(self):
        self.meta["sourceRevision"] = "invalid"
        self.write()
        with self.assertRaises(AssemblyError):
            self.build()
        self.meta["sourceRevision"] = "a" * 40
        self.parts[0]["restTo"] = self.parts[0]["restFrom"]
        self.write()
        with self.assertRaises(AssemblyError):
            self.build()

    def test_mismatched_binary_contents_cannot_produce_rig(self):
        self.write()
        (self.root / "skeleton_atlas.mmgeom").write_bytes(b"corrupt")
        with self.assertRaises(AssemblyError):
            self.build()

    def test_no_orphan_rig_written_on_failed_review(self):
        self.review["reviewedRigHierarchy"] = False
        self.write()
        with self.assertRaises(AssemblyError):
            self.build()
        self.assertFalse(
            (self.root / "anatomy_atlas_manifest.json").exists()
        )


if __name__ == "__main__":
    unittest.main()

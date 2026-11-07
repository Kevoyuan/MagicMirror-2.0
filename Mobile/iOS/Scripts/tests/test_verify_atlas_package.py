"""Synthetic, license-free corruption tests for the offline atlas preflight."""
import copy
import hashlib
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from verify_atlas_package import (  # noqa: E402
    BINARY_NAME, MANIFEST_NAME, PackageError, SOURCE_PATH,
    SOURCE_REPO, SOURCE_REVISION, verify_package,
)
from atlas_sources import SYSTEM_SOURCES, resource_base  # noqa: E402


class AtlasPackagePreflightTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.vertices = [
            (0., 0., 0., 0., 0., 1.),
            (1., 0., 0., 0., 0., 1.),
            (0., 1., 0., 0., 0., 1.),
        ]
        self.parts = [{
            "sourceHierarchyPath": "synthetic/test",
            "displayName": "Unlicensed synthetic test triangle",
            "group": "arms",
            "fromLandmark": 11,
            "toLandmark": 13,
            "restFrom": [0., 0., 0.],
            "restTo": [1., 0., 0.],
            "vertexOffset": 0,
            "vertexCount": 3
        }]
        self.manifest = {
            "schemaVersion": 1,
            "sourceRepository": SOURCE_REPO,
            "sourceRevision": SOURCE_REVISION,
            "sourcePath": SOURCE_PATH,
            "modelFile": BINARY_NAME,
            "modelSHA256": "",
            "licenseIds": ["CC BY-SA 2.1 Japan", "CC BY-SA 4.0"],
            "attribution": ["Z-Anatomy synthetic fixture",
                            "BodyParts3D synthetic fixture"],
            "modificationNotes": ["Synthetic triangle for unit tests only"],
            "reviewedForDistribution": True,
            "reviewedJointBindings": True,
            "parts": self.parts
        }
        self.rewrite()

    def rewrite(self, *, keep_hash=False):
        payload = b"MMATLAS1" + struct.pack("<I", len(self.vertices))
        payload += b"".join(struct.pack("<6f", *v) for v in self.vertices)
        (self.root / BINARY_NAME).write_bytes(payload)
        if not keep_hash:
            self.manifest["modelSHA256"] = hashlib.sha256(payload).hexdigest()
        (self.root / MANIFEST_NAME).write_text(
            json.dumps(self.manifest), encoding="utf-8")

    def test_valid_synthetic_structure(self):
        report = verify_package(self.root)
        self.assertEqual(report["vertex_count"], 3)
        self.assertEqual(report["mesh_count"], 1)

    def test_missing_or_false_review_flags(self):
        for key in ["reviewedForDistribution", "reviewedJointBindings"]:
            old = self.manifest[key]
            self.manifest[key] = False
            self.rewrite()
            with self.assertRaises(PackageError):
                verify_package(self.root)
            self.manifest[key] = old

    def test_wrong_source_identity_or_missing_credits(self):
        changes = [
            ("sourceRevision", "not-pinned"),
            ("sourcePath", "other-source.fbx"),
            ("sourceRepository", "https://invalid.example"),
            ("licenseIds", []),
            ("attribution", ["Z-Anatomy only"]),
            ("modificationNotes", []),
        ]
        for key, bad in changes:
            with self.subTest(key=key):
                old = self.manifest[key]
                self.manifest[key] = bad
                self.rewrite()
                with self.assertRaises(PackageError):
                    verify_package(self.root)
                self.manifest[key] = old

    def test_detects_tampered_model_hash(self):
        self.vertices[1] = (2., 0., 0., 0., 0., 1.)
        self.rewrite(keep_hash=True)
        with self.assertRaisesRegex(PackageError, "SHA-256"):
            verify_package(self.root)

    def test_detects_truncated_or_bad_header(self):
        p = self.root / BINARY_NAME
        for payload in [
            b"bad",
            b"BADSIGN!" + struct.pack("<I", 3) + b"\0" * 72,
            b"MMATLAS1" + struct.pack("<I", 3) + b"\0" * 24,
        ]:
            p.write_bytes(payload)
            with self.assertRaises(PackageError):
                verify_package(self.root)

    def test_rejects_invalid_part_ranges_and_duplicate_paths(self):
        variants = [
            [{"sourceHierarchyPath": "synthetic/test", "displayName": "test",
              "group": "arms", "fromLandmark": 11, "toLandmark": 13,
              "restFrom": [0, 0, 0], "restTo": [1, 0, 0],
              "vertexOffset": 1, "vertexCount": 3}],
            [self.parts[0], copy.deepcopy(self.parts[0])],
            [{**self.parts[0], "vertexCount": 2}],
            [{**self.parts[0], "fromLandmark": 11,
              "toLandmark": 11}],
            [{**self.parts[0], "restTo": [0, 0, 0]}],
        ]
        for parts in variants:
            with self.subTest(parts=parts):
                self.manifest["parts"] = parts
                self.rewrite()
                with self.assertRaises(PackageError):
                    verify_package(self.root)

    def test_rejects_nan_vertex_and_zero_normal_even_with_correct_hash(self):
        for bad in [(float("nan"), 0., 0., 0., 0., 1.),
                    (0., 0., 0., 0., 0., 0.)]:
            self.vertices[0] = bad
            self.rewrite()
            with self.assertRaises(PackageError):
                verify_package(self.root)

    def test_manifest_absence_fails_closed(self):
        (self.root / MANIFEST_NAME).unlink()
        with self.assertRaises(PackageError):
            verify_package(self.root)

    def test_all_six_real_upstream_sources_are_pinned(self):
        self.assertEqual(
            set(SYSTEM_SOURCES),
            {"skeleton", "muscles", "organs", "vessels", "nerves", "joints"}
        )
        for name, (path, byte_count, blob) in SYSTEM_SOURCES.items():
            with self.subTest(system=name):
                self.assertTrue(path.startswith("Resources/Models/FBX/"))
                self.assertGreater(byte_count, 1_000_000)
                self.assertEqual(len(blob), 40)
                self.assertTrue(resource_base(name).endswith("_atlas"))

    def test_other_anatomy_system_requires_correct_source_and_name(self):
        system = "muscles"
        base = resource_base(system)
        self.manifest["sourcePath"] = SYSTEM_SOURCES[system][0]
        self.manifest["anatomicalSystem"] = system
        self.manifest["modelFile"] = f"{base}.mmgeom"
        self.rewrite()
        (self.root / BINARY_NAME).rename(
            self.root / f"{base}.mmgeom"
        )
        (self.root / MANIFEST_NAME).rename(
            self.root / f"{base}.manifest.json"
        )
        report = verify_package(self.root, system=system)
        self.assertEqual(report["vertex_count"], 3)
        manifest_path = self.root / f"{base}.manifest.json"
        self.manifest["anatomicalSystem"] = "skeleton"
        manifest_path.write_text(json.dumps(self.manifest), encoding="utf-8")
        with self.assertRaisesRegex(PackageError, "system mismatch"):
            verify_package(self.root, system=system)

    def test_valid_audited_four_weights_and_corrupt_sidecar(self):
        influence = {
            "boneIds": ["reviewed/a", "reviewed/b",
                        "reviewed/a", "reviewed/a"],
            "weights": [0.6, 0.4, 0, 0],
        }
        skinning = {
            "schemaVersion": 1,
            "sourceRevision": SOURCE_REVISION,
            "modelSHA256": self.manifest["modelSHA256"],
            "reviewedJointWeights": True,
            "vertices": [influence] * 3,
        }
        p = self.root / "skeleton_atlas.skinning.json"

        def write():
            p.write_text(json.dumps(skinning), encoding="utf-8")

        write()
        self.assertEqual(verify_package(self.root)["vertex_count"], 3)
        for key, wrong in [
            ("reviewedJointWeights", False),
            ("sourceRevision", "wrong-revision"),
            ("modelSHA256", "invalid"),
            ("vertices", [{"boneIds": ["a"], "weights": [1]}]),
            ("vertices", [{"boneIds": ["a"] * 4,
                           "weights": [float("nan"), 0, 0, 0]}] * 3),
            ("vertices", [{"boneIds": ["a"] * 4,
                           "weights": [0.1, 0.1, 0, 0]}] * 3),
        ]:
            with self.subTest(key=key, wrong=wrong):
                old = skinning[key]
                skinning[key] = wrong
                write()
                with self.assertRaises(PackageError):
                    verify_package(self.root)
                skinning[key] = old
                write()


if __name__ == "__main__":
    unittest.main()

"""Commercial paid build gate regression tests use made-up model bytes only."""
import copy
from datetime import date, timedelta
import hashlib
import json
from pathlib import Path
import sys
import tempfile
from unittest import mock
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paid_release_gate as gate  # noqa: E402


class PaidReleaseGateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.resources = self.root / "Resources"
        self.resources.mkdir()
        (self.root / "CommercialRelease").mkdir()
        (self.root / "project.yml").write_text(
            "packages:\n  MediaPipeTasks:\n"
            "    url: https://github.com/google-ai-edge/mediapipe\n"
            f"    revision: {gate.PINNED_MEDIAPIPE_REVISION}\n",
            encoding="utf-8"
        )
        self.fake_model = b"FAKE NOT GOOGLE MEDIA PIPE POSE"
        self.model_digest = hashlib.sha256(self.fake_model).hexdigest()
        self.addCleanup(lambda: None)
        self.patcher = mock.patch.object(
            gate, "PINNED_POSE_SHA256", self.model_digest
        )
        self.patcher.start()
        self.addCleanup(self.patcher.stop)
        self.approval = {
            "reviewerName": "Synthetic Rights Reviewer",
            "reviewDate": date.today().isoformat(),
            "legalEvidenceReference": "synthetic/test-only/evidence",
            "actualDocumentsIndependentlyReviewed": True,
            "appleDRMAndRedistributionReviewed": True,
            "distributionNotes": "Synthetic fixture only for test geography",
        }
        self.dependency = {
            "name": "MediaPipeTasksVision",
            "sourceRevision": gate.PINNED_MEDIAPIPE_REVISION,
            "licenseIdentifier": "Apache-2.0",
            "redistributionReviewed": True,
            "requiredNoticesIncluded": True,
            "evidenceReference": "synthetic/sdk-notice-check",
        }
        self.notice = (
            "Synthetic provenance fixture, MediaPipe SDK Apache-2.0 "
            "developer docs: https://www.apache.org/licenses/LICENSE-2.0\n"
            + "For integration unit testing ONLY, not real release permission.\n"
        )
        self.model_record = {
            "bundleRelativePath": "pose_landmarker_lite.task",
            "sha256": self.model_digest,
            "rightsBasis": "written-commercial-grant",
            "commercialUseAuthorized": True,
            "applePaidAppStoreDistributionAuthorized": True,
            "redistributionAndTechnicalRestrictionsAuthorized": True,
            "authorOrRightsholder": "Synthetic test model author",
            "sourceAndRevision": "test-fixture fake task binary v1",
            "licenseIdentifier": "synthetic-commercial-test-grant",
            "licenseOrAssignmentEvidenceReference": "synthetic/model-license",
            "attributionAndModificationNotes": "Synthetic test bytes only",
        }
        self.manifest = {
            "schemaVersion": 1,
            "distributionChannel": "paid-ios-app-store",
            "releaseApproved": True,
            "approval": self.approval,
            "runtimeDependencies": [self.dependency],
            "authorizedAssets": [self.model_record],
            "noticesSHA256": hashlib.sha256(
                self.notice.encode("utf-8")
            ).hexdigest(),
        }
        (self.resources / "pose_landmarker_lite.task").write_bytes(self.fake_model)
        (self.resources / gate.NOTICES_NAME).write_text(
            self.notice, encoding="utf-8"
        )
        self.save_manifest()

    def save_manifest(self):
        (self.root / gate.CLEARANCE_NAME).write_text(
            json.dumps(self.manifest), encoding="utf-8"
        )

    def pass_release(self):
        self.save_manifest()
        return gate.run(root=self.root, mode="release")

    def test_legal_checklist_with_matching_synthetic_assets_passes(self):
        self.assertTrue(self.pass_release()["paidReleaseCleared"])

    def test_missing_owner_approval_is_a_hard_build_stop(self):
        self.manifest["releaseApproved"] = False
        with self.assertRaisesRegex(gate.CommercialReleaseError, "LOCKED"):
            self.pass_release()
        self.manifest["releaseApproved"] = True
        self.manifest["approval"]["actualDocumentsIndependentlyReviewed"] = False
        with self.assertRaises(gate.CommercialReleaseError):
            self.pass_release()

    def test_missing_media_pipe_weights_rights_or_sdk_notice_fails(self):
        self.manifest["authorizedAssets"] = []
        with self.assertRaisesRegex(
            gate.CommercialReleaseError, "PoseLandmarker"
        ):
            self.pass_release()
        self.manifest["authorizedAssets"] = [self.model_record]
        self.manifest["runtimeDependencies"][0]["redistributionReviewed"] = False
        with self.assertRaisesRegex(
            gate.CommercialReleaseError, "commercial dependency"
        ):
            self.pass_release()

    def test_swiftpm_dependency_revision_must_match_reviewed_dependency(self):
        (self.root / "project.yml").write_text(
            "packages:\n  MediaPipeTasks:\n"
            "    url: https://github.com/google-ai-edge/mediapipe\n"
            "    revision: " + "a" * 40 + "\n",
            encoding="utf-8"
        )
        with self.assertRaisesRegex(
            gate.CommercialReleaseError, "source revision differs"
        ):
            self.pass_release()

    def test_unapproved_3d_geometry_bypasses_gitignore_but_not_gate(self):
        (self.resources / "unreviewed_z_anatomy.usdz").write_bytes(b"FAKE MESH")
        with self.assertRaisesRegex(
            gate.CommercialReleaseError, "unapproved="
        ):
            self.pass_release()
        with self.assertRaisesRegex(
            gate.CommercialReleaseError, "Unreviewed 3D/ML"
        ):
            gate.run(root=self.root, mode="source")

    def test_model_package_directory_and_zip_do_not_escape_audit(self):
        package = self.resources / "unapproved.mlmodelc"
        package.mkdir()
        (package / "metadata.json").write_text("{}", encoding="utf-8")
        with self.assertRaisesRegex(
            gate.CommercialReleaseError, "model package directory"
        ):
            self.pass_release()
        (package / "metadata.json").unlink()
        package.rmdir()
        (self.resources / "atlas.zip").write_bytes(b"FAKE ARCHIVE")
        with self.assertRaisesRegex(
            gate.CommercialReleaseError, "unapproved="
        ):
            self.pass_release()

    def test_sidecar_and_alternate_model_are_not_accidentally_copied(self):
        for extra in (
            "skeleton_atlas.mmgeom", "skeleton_atlas.skinning.json",
            "anatomy_atlas_manifest.json", "other_model.onnx"
        ):
            with self.subTest(extra=extra):
                p = self.resources / extra
                p.write_text("fake", encoding="utf-8")
                with self.assertRaises(gate.CommercialReleaseError):
                    self.pass_release()
                p.unlink()

    def test_forged_model_bytes_and_notices_change_block_release(self):
        (self.resources / "pose_landmarker_lite.task").write_bytes(b"MISMATCH")
        with self.assertRaisesRegex(
            gate.CommercialReleaseError, "does not match reviewed"
        ):
            self.pass_release()
        (self.resources / "pose_landmarker_lite.task").write_bytes(
            self.fake_model
        )
        (self.resources / gate.NOTICES_NAME).write_text(
            "Not an attribution notice", encoding="utf-8"
        )
        with self.assertRaisesRegex(
            gate.CommercialReleaseError, "notices"
        ):
            self.pass_release()

    def test_cc_sa_or_noncommercial_source_requires_separate_written_grant(self):
        anatomy = {
            **copy.deepcopy(self.model_record),
            "bundleRelativePath": "skeleton_atlas.mmgeom",
            "sha256": hashlib.sha256(b"FAKE ATLAS").hexdigest(),
            "rightsBasis": "original-owned",
            "sourceAndRevision": "Z-Anatomy@fake / BodyParts3D",
            "licenseIdentifier": "CC-BY-SA-4.0",
            "anatomyAndRigReviewed": True,
            "originalMeshRightsAuditSHA256": "a" * 64,
        }
        (self.resources / "skeleton_atlas.mmgeom").write_bytes(b"FAKE ATLAS")
        self.manifest["authorizedAssets"].append(anatomy)
        with self.assertRaisesRegex(
            gate.CommercialReleaseError, "alternate written grant"
        ):
            self.pass_release()
        anatomy["rightsBasis"] = "written-commercial-grant"
        anatomy["underlyingSourceRightsReviewed"] = True
        anatomy["alternativeWrittenGrantReference"] = "test/grant"
        self.assertTrue(self.pass_release()["paidReleaseCleared"])

    def test_no_cleared_assets_can_be_symlinked_to_untracked_source(self):
        (self.resources / "other.task").symlink_to(
            self.resources / "pose_landmarker_lite.task"
        )
        with self.assertRaisesRegex(gate.CommercialReleaseError, "Linked"):
            self.pass_release()

    def test_external_app_bundle_must_match_cleared_resources(self):
        bundle = self.root / "MagicMirror.app"
        bundle.mkdir()
        (bundle / "pose_landmarker_lite.task").write_bytes(self.fake_model)
        (bundle / gate.NOTICES_NAME).write_text(self.notice, encoding="utf-8")
        self.save_manifest()
        self.assertTrue(gate.run(
            root=self.root, mode="bundle", bundle=bundle
        )["paidReleaseCleared"])
        (bundle / "not_allowed.glb").write_bytes(b"FAKE")
        with self.assertRaisesRegex(gate.CommercialReleaseError, "unapproved="):
            gate.run(root=self.root, mode="bundle", bundle=bundle)

    def test_old_future_review_and_missing_restrictions_are_blocked(self):
        self.manifest["approval"]["reviewDate"] = (
            date.today() + timedelta(days=20)
        ).isoformat()
        with self.assertRaises(gate.CommercialReleaseError):
            self.pass_release()
        self.manifest["approval"]["reviewDate"] = date.today().isoformat()
        self.manifest["approval"]["appleDRMAndRedistributionReviewed"] = False
        with self.assertRaisesRegex(gate.CommercialReleaseError, "DRM"):
            self.pass_release()
        self.manifest["approval"]["appleDRMAndRedistributionReviewed"] = True
        self.manifest["authorizedAssets"][0]["bundleRelativePath"] = "../escape.task"
        with self.assertRaisesRegex(gate.CommercialReleaseError, "Invalid asset path"):
            self.pass_release()

    def test_developer_mode_does_not_claim_paid_approval(self):
        self.manifest["releaseApproved"] = False
        self.save_manifest()
        result = gate.run(root=self.root, mode="source")
        self.assertFalse(result["paidReleaseCleared"])
        with self.assertRaises(gate.CommercialReleaseError):
            gate.run(root=self.root, mode="release")


if __name__ == "__main__":
    unittest.main()

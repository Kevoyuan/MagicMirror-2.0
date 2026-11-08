"""Synthetic open-model release contract: no actual Z-Anatomy mesh is included."""
import copy
from datetime import date
import hashlib
import io
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest import mock
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paid_release_gate as gate
import sharealike_publication as share
from stage_cc_model_attribution import notice_from_clearance


class PublicCCShareAlikeModelTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.resources = self.root / "Resources"
        self.resources.mkdir()
        self.release = self.root / "CommercialRelease"
        self.release.mkdir()
        self.packs = self.release / "PublishedPacks"
        self.packs.mkdir()
        (self.root / "project.yml").write_text(
            "packages:\n  MediaPipeTasks:\n"
            "    url: https://github.com/google-ai-edge/mediapipe\n"
            f"    revision: {gate.PINNED_MEDIAPIPE_REVISION}\n",
            encoding="utf-8")
        self.task = b"FAKE TASK WEIGHTS FOR PYTHON TEST ONLY"
        self.task_sha = hashlib.sha256(self.task).hexdigest()
        patcher = mock.patch.object(gate, "PINNED_POSE_SHA256", self.task_sha)
        patcher.start()
        self.addCleanup(patcher.stop)
        (self.resources / "pose_landmarker_lite.task").write_bytes(self.task)
        self.notice = ("MediaPipe Apache-2.0 SDK: synthetic example. "
                       "This is NOT actually reviewed license material. "
                       "For test purposes, do not distribute publicly.\n")
        (self.resources / "ThirdPartyNotices.txt").write_text(
            self.notice, encoding="utf-8")
        self.model_name = "skeleton_atlas.mmgeom"
        self.manifest_name = "skeleton_atlas.manifest.json"
        self.vertices = [
            (0., 0., 0., 0., 0., 1.),
            (1., 0., 0., 0., 0., 1.),
            (0., 1., 0., 0., 0., 1.)
        ]
        self.model = b"MMATLAS1" + struct.pack("<I", 3) + b"".join(
            struct.pack("<6f", *v) for v in self.vertices
        )
        self.model_sha = hashlib.sha256(self.model).hexdigest()
        self.parts = [{
            "sourceHierarchyPath": "reviewed/test-bone",
            "displayName": "Synthetic bone, not a source model",
            "vertexOffset": 0,
            "vertexCount": 3,
            "componentLicense": {
                "licenseId": "CC-BY-SA-4.0",
                "originalSource": "Z-Anatomy synthetic metadata ONLY",
                "attribution": "Z-Anatomy and BodyParts3D original credits",
                "sourceMeshIdentity": "synthetic-fixture-only-000",
                "originReviewNotes": "Human review simulated in tests",
                "evidenceURL": "https://github.com/Z-Anatomy/Models-of-human-anatomy",
                "humanReviewed": True,
                "commercialReuseConfirmed": True,
            }
        }]
        self.atlas_manifest = {
            "schemaVersion": 1,
            "sourceRepository": "https://github.com/LluisV/Z-Anatomy",
            "sourceRevision": "6c7f9016bd5899ac8edafd31b9900c151df42ed6",
            "sourcePath": "Resources/Models/FBX/SkeletalSystem100.fbx",
            "modelFile": self.model_name,
            "modelSHA256": self.model_sha,
            "reviewedForDistribution": True,
            "reviewedJointBindings": True,
            "componentLicenseReview": {
                "reviewerName": "Synthetic Test Reviewer",
                "reviewDate": date.today().isoformat(),
                "intendedUse": "commercial-distribution",
                "reviewNotes": "Tests only, not actual human rights review",
            },
            "parts": self.parts,
        }
        (self.resources / self.model_name).write_bytes(self.model)
        self.manifest_file = self.resources / self.manifest_name
        self.save_atlas()
        self.attr = self.root / "ATTRIBUTION.md"
        self.attr.write_text(
            "Z-Anatomy — The libre 3D atlas of anatomy, Gauthier Kervyn "
            "and contributors. BodyParts3D — The Database Center for "
            "Life Science. CC BY-SA 4.0 at " + share.LICENSE_URI +
            " . This is synthetic test content only, NO actual license.",
            encoding="utf-8")
        self.changes = self.root / "MODIFICATIONS.md"
        self.changes.write_text(
            "Synthetic demo model: generated one triangle with arbitrary "
            "vertex and normal coordinates; not a real anatomy conversion.",
            encoding="utf-8")
        self.archive_name = "skeleton-open-v1.zip"
        self.archive = self.packs / self.archive_name
        self.rights_record = {
            "bundleRelativePath": self.model_name,
            "sha256": self.model_sha,
            "rightsBasis": "cc-by-sa-public-license",
            "commercialUseAuthorized": True,
            "applePaidAppStoreDistributionAuthorized": True,
            "redistributionAndTechnicalRestrictionsAuthorized": True,
            "authorOrRightsholder": "Z-Anatomy and BodyParts3D",
            "sourceAndRevision": "Z-Anatomy synthetic fixture",
            "licenseIdentifier": "CC-BY-SA-4.0",
            "licenseOrAssignmentEvidenceReference": "synthetic/CC-deed",
            "attributionAndModificationNotes": "Synthetic only",
            "underlyingSourceRightsReviewed": True,
            "underlyingSourceRightsEvidenceReference": "test/private/evidence",
            "originalMeshRightsAuditSHA256": "a" * 64,
            "anatomyAndRigReviewed": True,
            "shareAlikePublicationId": "skeleton-v1",
        }
        self.task_record = {
            **self.rights_record,
            "bundleRelativePath": "pose_landmarker_lite.task",
            "sha256": self.task_sha,
            "rightsBasis": "written-commercial-grant",
            "licenseIdentifier": "mock-proprietary-task-grant",
            "sourceAndRevision": "mock-weights-v1",
            "authorOrRightsholder": "Synthetic test ML author",
        }
        self.atlas_metadata_record = {
            **self.rights_record,
            "bundleRelativePath": self.manifest_name,
            "sha256": hashlib.sha256(self.manifest_file.read_bytes()).hexdigest(),
        }
        self.policy = {
            "schemaVersion": 1,
            "distributionChannel": "paid-ios-app-store",
            "releaseApproved": True,
            "approval": {
                "reviewerName": "Test Rights Reviewer",
                "reviewDate": date.today().isoformat(),
                "legalEvidenceReference": "synthetic-test/legal-review",
                "actualDocumentsIndependentlyReviewed": True,
                "appleDRMAndRedistributionReviewed": True,
                "distributionNotes": "Synthetic-only German App Store example",
            },
            "runtimeDependencies": [{
                "name": "MediaPipeTasksVision",
                "sourceRevision": gate.PINNED_MEDIAPIPE_REVISION,
                "licenseIdentifier": "Apache-2.0",
                "redistributionReviewed": True,
                "requiredNoticesIncluded": True,
                "evidenceReference": "synthetic/sdk-test",
            }],
            "authorizedAssets": [self.task_record, self.rights_record,
                                 self.atlas_metadata_record],
            "noticesSHA256": hashlib.sha256(
                self.notice.encode("utf-8")
            ).hexdigest(),
            "shareAlikePublications": [{
                "id": "skeleton-v1",
                "modelFile": self.model_name,
                "manifestFile": self.manifest_name,
                "publicArchiveFile": self.archive_name,
                "publicArchiveSHA256": "",
                "publicURL": "https://models.example.org/skeleton-open-v1.zip",
                "publicNoLoginNoDRMVerified": True,
                "verifiedPublicAvailability": True,
                "publicationVerifiedDate": date.today().isoformat(),
                "publicationVerifiedBy": "Synthetic Test Reviewer",
                "rightsChainEvidenceReference": "synthetic/permesh-review",
                "appleDistributionCompatibilityReviewReference": "synthetic/DRM-counsel",
            }],
        }

    def save_atlas(self):
        self.manifest_file.write_text(
            json.dumps(self.atlas_manifest), encoding="utf-8"
        )

    def make_archive(self):
        report = share.build_pack(
            model_file=self.resources / self.model_name,
            manifest_file=self.manifest_file,
            attribution_file=self.attr,
            modification_file=self.changes,
            output=self.archive
        )
        self.policy["shareAlikePublications"][0][
            "publicArchiveSHA256"
        ] = report["archiveSHA256"]
        (self.resources / "CCModelAttribution.json").write_text(
            json.dumps(notice_from_clearance(self.policy)),
            encoding="utf-8"
        )
        return report

    def save_policy(self):
        (self.release / "paid-app-clearance.json").write_text(
            json.dumps(self.policy), encoding="utf-8"
        )

    def run_release(self):
        self.save_policy()
        return gate.run(root=self.root, mode="release")

    def test_public_model_pack_contains_actual_open_geo_credits_and_hashes(self):
        report = self.make_archive()
        self.assertEqual(report["originalParts"], 1)
        self.assertEqual(report["vertices"], 3)
        with zipfile.ZipFile(self.archive) as z:
            self.assertEqual(z.read(self.model_name), self.model)
            obj = z.read("skeleton_atlas.obj").decode()
            self.assertIn("f 1//1 2//2 3//3", obj)
            self.assertIn("Z-Anatomy", z.read("ATTRIBUTION.md").decode())
            self.assertIn("BodyParts3D", z.read("ATTRIBUTION.md").decode())
            self.assertIn("synthetic-fixture-only-000",
                          z.read("COMPONENT_CREDITS.md").decode())
        self.assertTrue(self.run_release()["paidReleaseCleared"])
        self.assertTrue(
            gate.run(root=self.root, mode="source")["paidReleaseCleared"]
        )

    def test_cc_by_sa_release_does_not_require_a_separate_written_grant(self):
        self.make_archive()
        self.assertNotIn("alternativeWrittenGrantReference", self.rights_record)
        self.assertTrue(self.run_release()["paidReleaseCleared"])

    def test_no_public_pack_and_no_lawyer_drm_review_both_block(self):
        self.policy["shareAlikePublications"][0]["publicArchiveSHA256"] = "a" * 64
        with self.assertRaisesRegex(
            gate.CommercialReleaseError, "Actual published archive missing"
        ):
            self.run_release()
        self.make_archive()
        self.policy["shareAlikePublications"][0][
            "appleDistributionCompatibilityReviewReference"
        ] = ""
        with self.assertRaisesRegex(
            gate.CommercialReleaseError, "Legal review"
        ):
            self.run_release()

    def test_nc_or_unknown_mesh_rejected_even_with_complete_archive_settings(self):
        for license_id in ("CC-BY-NC-4.0", "CC-BY-NC-SA-4.0", "unknown", ""):
            with self.subTest(license_id=license_id):
                self.parts[0]["componentLicense"]["licenseId"] = license_id
                self.save_atlas()
                with self.assertRaisesRegex(
                    share.ShareAlikeError, "NC, ND, unknown"
                ):
                    self.make_archive()
        self.parts[0]["componentLicense"]["licenseId"] = "CC-BY-SA-4.0"

    def test_legal_template_and_fake_published_link_must_not_auto_approve(self):
        self.make_archive()
        self.policy["releaseApproved"] = False
        with self.assertRaisesRegex(
            gate.CommercialReleaseError, "LOCKED"
        ):
            self.run_release()
        self.policy["releaseApproved"] = True
        self.policy["shareAlikePublications"][0]["publicNoLoginNoDRMVerified"] = False
        with self.assertRaisesRegex(
            gate.CommercialReleaseError, "Legal review"
        ):
            self.run_release()

    def test_public_bytes_cannot_differ_from_paid_bundle(self):
        self.make_archive()
        (self.resources / self.model_name).write_bytes(
            self.model + b"ALTERED"
        )
        with self.assertRaisesRegex(
            gate.CommercialReleaseError, "does not match reviewed SHA-256"
        ):
            self.run_release()

    def test_injected_pack_files_or_altered_zip_fail_even_if_hash_updated(self):
        self.make_archive()
        with zipfile.ZipFile(self.archive, "a") as z:
            z.writestr("not-in-public-release.bin", b"unapproved")
        self.policy["shareAlikePublications"][0][
            "publicArchiveSHA256"
        ] = hashlib.sha256(self.archive.read_bytes()).hexdigest()
        with self.assertRaisesRegex(
            gate.CommercialReleaseError, "missing or injected"
        ):
            self.run_release()

    def test_unchanged_zip_fails_when_recorded_sha_corrupted(self):
        self.make_archive()
        self.policy["shareAlikePublications"][0][
            "publicArchiveSHA256"
        ] = "f" * 64
        with self.assertRaisesRegex(
            gate.CommercialReleaseError, "SHA-256"
        ):
            self.run_release()

    def test_visible_model_download_link_must_match_license_record(self):
        self.make_archive()
        notice_file = self.resources / "CCModelAttribution.json"
        notice = json.loads(notice_file.read_text())
        notice["publicModels"][0]["publicArchiveSHA256"] = "0" * 64
        notice_file.write_text(json.dumps(notice))
        with self.assertRaisesRegex(
            gate.CommercialReleaseError, "Visible in-app public model"
        ):
            self.run_release()

    def test_wrong_public_url_and_mismatched_publication_ids_block(self):
        self.make_archive()
        entry = self.policy["shareAlikePublications"][0]
        entry["publicURL"] = "http://models.example.org/skeleton-open-v1.zip"
        with self.assertRaisesRegex(gate.CommercialReleaseError, "HTTPS"):
            self.run_release()
        entry["publicURL"] = "https://models.example.org/skeleton-open-v1.zip"
        self.atlas_metadata_record["shareAlikePublicationId"] = "wrong"
        with self.assertRaisesRegex(
            gate.CommercialReleaseError, "rights ledger"
        ):
            self.run_release()

    def test_no_missing_permesh_license_evidence_can_enter_public_pack(self):
        for key in ("sourceMeshIdentity", "attribution", "originReviewNotes"):
            with self.subTest(key=key):
                old = self.parts[0]["componentLicense"][key]
                self.parts[0]["componentLicense"][key] = ""
                self.save_atlas()
                with self.assertRaisesRegex(
                    share.ShareAlikeError, "Missing"
                ):
                    self.make_archive()
                self.parts[0]["componentLicense"][key] = old
        self.save_atlas()

    def test_legacy_unreviewed_z_anatomy_has_no_release_shortcut(self):
        self.make_archive()
        self.rights_record["rightsBasis"] = "original-owned"
        with self.assertRaisesRegex(
            gate.CommercialReleaseError, "alternate written grant"
        ):
            self.run_release()


if __name__ == "__main__":
    unittest.main()

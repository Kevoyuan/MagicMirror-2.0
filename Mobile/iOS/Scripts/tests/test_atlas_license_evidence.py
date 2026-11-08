"""Synthetic license evidence fixtures only: no real model approved."""
import copy
from datetime import date, timedelta
import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from atlas_license_evidence import (  # noqa: E402
    LicenseEvidenceError, reviewed_bindings_license_evidence,
    verify_component_license_manifest, compare_private_review_to_manifest,
)


class ComponentLicenseEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.component = {
            "licenseId": "CC-BY-SA-4.0",
            "originalSource": "Synthetic independent fixture",
            "sourceMeshIdentity": "source object mesh UID (synthetic)",
            "attribution": "Synthetic geometry only",
            "originReviewNotes": "Fixture provenance verified by test author only",
            "evidenceURL": "https://example.org/synthetic-license",
            "humanReviewed": True,
            "commercialReuseConfirmed": True,
        }
        self.review = {
            "reviewedForDistribution": True, "licenseReviewed": True,
            "componentLicenseReview": {
                "reviewerName": "Synthetic Test Reviewer",
                "reviewDate": date.today().isoformat(),
                "intendedUse": "commercial-distribution",
                "reviewNotes": "Synthetic source only; not an actual legal review",
            },
            "bindings": [
                {"sourceHierarchyPath": "synthetic/left",
                 "componentLicense": copy.deepcopy(self.component)},
                {"sourceHierarchyPath": "synthetic/right",
                 "componentLicense": copy.deepcopy(self.component)},
            ],
        }
        self.manifest = {
            "reviewedForDistribution": True,
            "componentLicenseReview":
                copy.deepcopy(self.review["componentLicenseReview"]),
            "parts": [
                copy.deepcopy(item) for item in self.review["bindings"]
            ],
        }

    def test_complete_per_mesh_review_matches_exported_manifest(self):
        header, entries = reviewed_bindings_license_evidence(
            self.review, self.review["bindings"]
        )
        self.assertEqual(len(entries), 2)
        self.assertEqual(header["reviewerName"], "Synthetic Test Reviewer")
        self.assertEqual(verify_component_license_manifest(self.manifest),
                         header)
        self.assertTrue(compare_private_review_to_manifest(
            self.review, self.manifest
        ))

    def test_mixed_nc_and_unknown_assets_fail_even_with_approval_bool(self):
        for license_id in (
            "CC-BY-NC-4.0", "CC-BY-NC-SA-4.0",
            "NOASSERTION", "other", "", "CC-BY-ND-4.0"
        ):
            with self.subTest(id=license_id):
                self.review["bindings"][0]["componentLicense"]["licenseId"] = license_id
                with self.assertRaisesRegex(
                    LicenseEvidenceError, "incompatible component license"
                ):
                    reviewed_bindings_license_evidence(
                        self.review, self.review["bindings"]
                    )

    def test_missing_origin_evidence_and_undocumented_reviewer_fail(self):
        for key, bad in (
            ("sourceMeshIdentity", ""),
            ("evidenceURL", "http://example.com/test"),
            ("attribution", ""),
            ("originReviewNotes", ""),
            ("humanReviewed", False),
            ("commercialReuseConfirmed", False),
        ):
            with self.subTest(field=key):
                trial = copy.deepcopy(self.review)
                trial["bindings"][0]["componentLicense"][key] = bad
                with self.assertRaises(LicenseEvidenceError):
                    reviewed_bindings_license_evidence(
                        trial, trial["bindings"]
                    )
        self.review["componentLicenseReview"]["reviewDate"] = (
            date.today() + timedelta(days=1)
        ).isoformat()
        with self.assertRaises(LicenseEvidenceError):
            reviewed_bindings_license_evidence(
                self.review, self.review["bindings"]
            )

    def test_missing_one_mesh_or_swapped_post_review_ledger_fails(self):
        self.manifest["parts"].pop()
        with self.assertRaisesRegex(LicenseEvidenceError, "does not match"):
            compare_private_review_to_manifest(self.review, self.manifest)

        self.manifest["parts"].append(copy.deepcopy(self.review["bindings"][1]))
        self.manifest["parts"][0]["componentLicense"]["sourceMeshIdentity"] = "other"
        with self.assertRaisesRegex(LicenseEvidenceError, "does not match"):
            compare_private_review_to_manifest(self.review, self.manifest)

    def test_false_review_and_duplicate_path_are_not_approvals(self):
        self.manifest["reviewedForDistribution"] = False
        with self.assertRaises(LicenseEvidenceError):
            verify_component_license_manifest(self.manifest)
        self.manifest["reviewedForDistribution"] = True
        self.manifest["parts"][1]["sourceHierarchyPath"] = "synthetic/left"
        with self.assertRaises(LicenseEvidenceError):
            verify_component_license_manifest(self.manifest)


if __name__ == "__main__":
    unittest.main()

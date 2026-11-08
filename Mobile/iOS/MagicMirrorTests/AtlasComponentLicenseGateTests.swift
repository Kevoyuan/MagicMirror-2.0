import XCTest
@testable import MagicMirror

/// These fixtures contain NO real anatomy, license approval or skinning.
final class AtlasComponentLicenseGateTests: XCTestCase {
    private func evidence(
        license: String = "CC-BY-SA-4.0",
        approved: Bool = true
    ) -> AtlasComponentLicenseEvidence {
        AtlasComponentLicenseEvidence(
            licenseId: license,
            originalSource: "Synthetic triangle fixture",
            attribution: "Synthetic author",
            sourceMeshIdentity: "synthetic/mesh",
            originReviewNotes: "This is test-only geometry",
            evidenceURL: "https://example.org/test-only",
            humanReviewed: approved,
            commercialReuseConfirmed: approved
        )
    }

    func testReviewedCompatibleComponentMayPassDocumentaryGate() {
        XCTAssertTrue(evidence().isApprovedForCommercialAtlas)
        XCTAssertTrue(AtlasComponentLicenseReview(
            reviewerName: "Synthetic Fixture Reviewer",
            reviewDate: "2026-11-08",
            intendedUse: "commercial-distribution",
            reviewNotes: "A test fixture, not Z-Anatomy rights approval"
        ).isDocumented)
    }

    func testUnknownAndNoncommercialComponentCannotPassEvenIfFlagged() {
        XCTAssertFalse(evidence(license: "CC-BY-NC-4.0")
            .isApprovedForCommercialAtlas)
        XCTAssertFalse(evidence(license: "CC-BY-NC-SA-4.0")
            .isApprovedForCommercialAtlas)
        XCTAssertFalse(evidence(license: "NOASSERTION")
            .isApprovedForCommercialAtlas)
        XCTAssertFalse(evidence(approved: false)
            .isApprovedForCommercialAtlas)
    }

    func testFutureDatedOrMalformedHumanEvidenceCannotPass() {
        XCTAssertFalse(AtlasComponentLicenseReview(
            reviewerName: "Synthetic",
            reviewDate: "2099-12-31",
            intendedUse: "commercial-distribution",
            reviewNotes: "Future-dated synthetic record"
        ).isDocumented)
        XCTAssertFalse(AtlasComponentLicenseReview(
            reviewerName: "Synthetic",
            reviewDate: "today",
            intendedUse: "commercial-distribution",
            reviewNotes: "Invalid date"
        ).isDocumented)
        let invalidURL = AtlasComponentLicenseEvidence(
            licenseId: "CC-BY-SA-4.0",
            originalSource: "synthetic",
            attribution: "synthetic",
            sourceMeshIdentity: "synthetic/test",
            originReviewNotes: "synthetic",
            evidenceURL: "https://",
            humanReviewed: true,
            commercialReuseConfirmed: true
        )
        XCTAssertFalse(invalidURL.isApprovedForCommercialAtlas)
    }

    func testReviewRecordWithoutActualNamedReviewerIsNotAcceptable() {
        XCTAssertFalse(AtlasComponentLicenseReview(
            reviewerName: " ",
            reviewDate: "2026-11-08",
            intendedUse: "commercial-distribution",
            reviewNotes: "Missing actual reviewer"
        ).isDocumented)
    }

    func testARealPackageMustNotInferApprovalFromTopLevelCredits() {
        // A formerly approved top-level CC BY-SA declaration alone is
        // insufficient; the actual bundle loader requires per-part proof.
        let old = """
        {
          "schemaVersion": 1, "sourceRepository": "https://example.org",
          "sourceRevision": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
          "sourcePath": "synthetic.fbx", "modelFile": "skeleton_atlas.mmgeom",
          "modelSHA256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
          "licenseIds": ["CC BY-SA 4.0", "CC BY-SA 2.1 Japan"],
          "attribution": ["Z-Anatomy synthetic", "BodyParts3D synthetic"],
          "modificationNotes": ["Fake triangles only"],
          "reviewedForDistribution": true, "reviewedJointBindings": true,
          "parts": [{
            "sourceHierarchyPath": "synthetic/test", "displayName": "test",
            "group": "arms", "fromLandmark": 11, "toLandmark": 13,
            "restFrom": [0,0,0], "restTo": [1,0,0],
            "vertexOffset": 0, "vertexCount": 3
          }]
        }
        """
        let decoded = try? JSONDecoder().decode(
            MobileAtlasManifest.self, from: Data(old.utf8)
        )
        XCTAssertNotNil(decoded)
        XCTAssertNil(decoded?.componentLicenseReview)
        XCTAssertNil(decoded?.parts.first?.componentLicense)
    }
}

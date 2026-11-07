import CoreGraphics
import XCTest
import simd
@testable import MagicMirror

/// These test values are **entirely synthetic** and do NOT certify any
/// Z-Anatomy/BodyParts3D mesh, license or actual joint pivot.
final class AnatomyAtlasManifestTests: XCTestCase {
    private func bone(
        id: String = "left-arm",
        nodePath: String = "Rig/LeftArm",
        parentId: String? = nil,
        reviewed: Bool = true
    ) -> AnatomyAtlasManifest.BoneBinding {
        .init(
            id: id,
            nodePath: nodePath,
            parentId: parentId,
            proximalLandmark: 11,
            distalLandmark: 13,
            restStart: [0, 0, 0],
            restEnd: [0, -0.48, 0],
            anchorsReviewed: reviewed
        )
    }

    private func fixture(
        licenseReviewed: Bool = true,
        anatomyReviewed: Bool = true,
        assetFilename: String = "fake.usdz",
        bones: [AnatomyAtlasManifest.BoneBinding]? = nil
    ) -> AnatomyAtlasManifest {
        AnatomyAtlasManifest(
            atlasId: "synthetic-test-fixture-not-shippable",
            sourceURL: "https://example.invalid/synthetic",
            sourceRevision: "test-only",
            attribution: "Synthetic values, not third-party anatomy",
            licenseIdentifier: "TEST-NOT-FOR-REDISTRIBUTION",
            assetFilename: assetFilename,
            assetSHA256: String(repeating: "a", count: 64),
            licenseReviewed: licenseReviewed,
            anatomyReviewed: anatomyReviewed,
            bones: bones ?? [bone()]
        )
    }

    func testApprovedMetadataStructurePassesSyntheticSchemaOnly() {
        XCTAssertNoThrow(try fixture().validateForUse())
    }

    func testRejectsUnreviewedLicenseAndAnatomy() {
        XCTAssertThrowsError(try fixture(
            licenseReviewed: false
        ).validateForUse())
        XCTAssertThrowsError(try fixture(
            anatomyReviewed: false
        ).validateForUse())
    }

    func testRejectsUnreviewedRealAtlasAnchors() {
        XCTAssertThrowsError(try fixture(
            bones: [bone(reviewed: false)]
        ).validateForUse())
    }

    func testRejectsTraversalAndUnapprovedFileExtensions() {
        for file in ["../external.usdz", "atlas.fbx", "folder/atlas.usdz"] {
            XCTAssertThrowsError(try fixture(
                assetFilename: file
            ).validateForUse())
        }
    }

    func testRejectsDuplicateIdAndNodePath() {
        let duplicateId = bone(id: "same", nodePath: "Arm/A")
        let second = bone(id: "same", nodePath: "Arm/B")
        XCTAssertThrowsError(try fixture(
            bones: [duplicateId, second]
        ).validateForUse())
        let samePath = bone(id: "different", nodePath: "Arm/A")
        XCTAssertThrowsError(try fixture(
            bones: [duplicateId, samePath]
        ).validateForUse())
    }

    func testRejectsUnknownParentAndCycle() {
        XCTAssertThrowsError(try fixture(bones: [
            bone(parentId: "absent")
        ]).validateForUse())
        let a = bone(id: "a", nodePath: "A", parentId: "b")
        let b = bone(id: "b", nodePath: "B", parentId: "a")
        XCTAssertThrowsError(try fixture(
            bones: [a, b]
        ).validateForUse())
    }

    func testRejectsInvalidBoneGeometry() {
        let degenerate = AnatomyAtlasManifest.BoneBinding(
            id: "broken",
            nodePath: "Rig/Broken",
            parentId: nil,
            proximalLandmark: 11,
            distalLandmark: 13,
            restStart: [0, 0, 0],
            restEnd: [0, 0, 0],
            anchorsReviewed: true
        )
        XCTAssertThrowsError(try fixture(
            bones: [degenerate]
        ).validateForUse())
    }

    private func pose(_ elbow: SIMD3<Float>, timestamp: Int) -> PoseSnapshot {
        let screen = Array(
            repeating: PosePoint(x: 0.5, y: 0.5, visibility: 0.99),
            count: 33
        )
        var world = Array(
            repeating: PoseWorldPoint(
                x: 0, y: 0, z: 0, visibility: 0.99
            ),
            count: 33
        )
        world[11] = PoseWorldPoint(
            x: 0, y: 0, z: 0, visibility: 0.99
        )
        world[13] = PoseWorldPoint(
            x: elbow.x, y: elbow.y, z: elbow.z, visibility: 0.99
        )
        return PoseSnapshot(
            timestampMilliseconds: timestamp,
            imageSize: CGSize(width: 720, height: 1280),
            points: screen,
            worldPoints: world
        )
    }

    func test3DRelativeJointRotationOnSyntheticArmRaise() {
        let reference = pose(
            SIMD3<Float>(0, -0.5, 0), timestamp: 1000
        )
        let moved = pose(
            SIMD3<Float>(0, 0, -0.5), timestamp: 1033
        )
        let commands = AnatomyMotionPlanner.rotationCommands(
            manifest: fixture(), reference: reference, current: moved
        )
        XCTAssertEqual(commands.count, 1)
        XCTAssertEqual(commands[0].boneId, "left-arm")
        XCTAssertEqual(commands[0].restLength, 0.48, accuracy: 0.0001)
        let rotated = simd_act(
            commands[0].referenceToCurrent, SIMD3<Float>(0, -1, 0)
        )
        XCTAssertEqual(rotated.x, 0, accuracy: 0.001)
        XCTAssertEqual(rotated.y, 0, accuracy: 0.001)
        XCTAssertEqual(rotated.z, -1, accuracy: 0.001)
    }

    func testMissingWorldPoseDoesNotGenerateFalseMotion() {
        let good = pose(
            SIMD3<Float>(0, -0.5, 0), timestamp: 1000
        )
        let missing = PoseSnapshot(
            timestampMilliseconds: 1033, imageSize: good.imageSize,
            points: good.points
        )
        XCTAssertTrue(AnatomyMotionPlanner.rotationCommands(
            manifest: fixture(), reference: good, current: missing
        ).isEmpty)
    }

    func testMotionBlockedWhenManifestNotApproved() {
        let good = pose(
            SIMD3<Float>(0, -0.5, 0), timestamp: 1000
        )
        XCTAssertTrue(AnatomyMotionPlanner.rotationCommands(
            manifest: fixture(licenseReviewed: false),
            reference: good, current: good
        ).isEmpty)
    }
}

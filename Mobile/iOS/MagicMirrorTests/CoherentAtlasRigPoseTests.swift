import CoreGraphics
import simd
import XCTest
@testable import MagicMirror

/// Entirely synthetic anchors: Boolean review flags here exercise
/// code-path validation; they are NEVER human anatomy/license approval.
final class CoherentAtlasRigPoseTests: XCTestCase {
    private func world(
        _ x: Float, _ y: Float, _ z: Float = 0,
        confidence: Float = 0.98
    ) -> PoseWorldPoint {
        PoseWorldPoint(
            x: x, y: y, z: z, visibility: confidence
        )
    }

    private func observed(
        timestamp: Int = 1000, moving: Bool = false,
        elbowConfidence: Float = 0.98
    ) -> PoseSnapshot {
        var image = Array(
            repeating: PosePoint(x: 0.5, y: 0.5, visibility: 0.98),
            count: 33
        )
        var model = Array(
            repeating: world(0, 0), count: 33
        )
        model[11] = world(-0.2, 0.5)
        model[12] = world(0.2, 0.5)
        model[23] = world(-0.15, 0.0)
        model[24] = world(0.15, 0.0)
        model[13] = moving
            ? world(-0.55, 0.48, confidence: elbowConfidence)
            : world(-0.4, 0.2, confidence: elbowConfidence)
        model[15] = moving
            ? world(-0.6, 0.15)
            : world(-0.55, -0.1)
        image[13] = PosePoint(x: 0.38, y: 0.48, visibility: 0.98)
        return PoseSnapshot(
            timestampMilliseconds: timestamp,
            imageSize: CGSize(width: 720, height: 1280),
            points: image, worldPoints: model
        )
    }

    private func registration() -> BodySimilarityRegistration {
        let result = BodySimilarityRegistration.calibrate(
            sourceLeftShoulder: SIMD3(-0.2, 0.5, 0),
            sourceRightShoulder: SIMD3(0.2, 0.5, 0),
            sourceMidHip: SIMD3(0, 0, 0),
            atlasLeftShoulder: SIMD3(-0.4, 1, 0),
            atlasRightShoulder: SIMD3(0.4, 1, 0),
            atlasMidHip: SIMD3(0, 0, 0),
            allowedScale: 1.0 ... 3.0,
            maximumPelvisResidual: 0.05
        )
        XCTAssertNotNil(result, "Constructed reference registration")
        return result!
    }

    private func binding(
        id: String, path: String, parent: String?,
        proximal: Int, distal: Int,
        from: [Float], to: [Float]
    ) -> AnatomyAtlasManifest.BoneBinding {
        AnatomyAtlasManifest.BoneBinding(
            id: id, nodePath: path, parentId: parent,
            proximalLandmark: proximal,
            distalLandmark: distal,
            restStart: from, restEnd: to,
            anchorsReviewed: true
        )
    }

    private func manifest(
        malformedChild: Bool = false,
        missingParent: Bool = false
    ) -> AnatomyAtlasManifest {
        AnatomyAtlasManifest(
            atlasId: "synthetic-do-not-distribute",
            sourceURL: "test://synthetic-not-real",
            sourceRevision: "test-v1",
            attribution: "Synthetic test only",
            licenseIdentifier: "synthetic",
            assetFilename: "synthetic.usdz",
            assetSHA256: String(repeating: "a", count: 64),
            licenseReviewed: true,
            anatomyReviewed: true,
            bones: [
                binding(
                    id: "left-upper", path: "arm/upper", parent: nil,
                    proximal: 11, distal: 13,
                    from: [-0.4, 1, 0], to: [-0.8, 0.4, 0]
                ),
                binding(
                    id: "left-lower", path: "arm/lower",
                    parent: missingParent ? "unknown" : "left-upper",
                    proximal: 13, distal: 15,
                    from: malformedChild ? [-0.1, 2, 0] : [-0.8, 0.4, 0],
                    to: [-1.1, -0.2, 0]
                )
            ]
        )
    }

    func testConnectedHierarchyMovesTogetherWithoutStretching() {
        let solution = CoherentAtlasRigPlanner.plan(
            manifest: manifest(), reference: observed(),
            current: observed(timestamp: 1033, moving: true),
            registration: registration()
        )
        XCTAssertNotNil(solution)
        XCTAssertEqual(solution?.bones.count, 2)
        guard let upper = solution?.bone("left-upper"),
              let lower = solution?.bone("left-lower") else { return }

        let attachment = upper.transformRestPoint(lower.restPivot)
        XCTAssertNotNil(attachment)
        XCTAssertEqual(lower.posedPivot.x, attachment!.x, accuracy: 0.001)
        XCTAssertEqual(lower.posedPivot.y, attachment!.y, accuracy: 0.001)
        XCTAssertEqual(lower.posedPivot.z, attachment!.z, accuracy: 0.001)

        let upperEnd = upper.transformRestPoint(SIMD3(-0.8, 0.4, 0))
        XCTAssertNotNil(upperEnd)
        XCTAssertEqual(
            simd_length(upperEnd! - upper.posedPivot),
            upper.restLength, accuracy: 0.001
        )
        let lowerEnd = lower.transformRestPoint(SIMD3(-1.1, -0.2, 0))
        XCTAssertNotNil(lowerEnd)
        XCTAssertEqual(
            simd_length(lowerEnd! - lower.posedPivot),
            lower.restLength, accuracy: 0.001
        )
        XCTAssertGreaterThan(upper.confidence, 0.9)
        XCTAssertGreaterThan(lower.confidence, 0.9)
    }

    func testStaticReferenceIsStableRestFrame() {
        let snapshot = observed()
        let solution = CoherentAtlasRigPlanner.plan(
            manifest: manifest(),
            reference: snapshot, current: snapshot,
            registration: registration()
        )
        XCTAssertNotNil(solution)
        let upper = solution?.bone("left-upper")
        XCTAssertNotNil(upper)
        XCTAssertEqual(upper!.posedPivot.x, -0.4, accuracy: 0.001)
        XCTAssertEqual(upper!.posedPivot.y, 1, accuracy: 0.001)
        XCTAssertEqual(upper!.restLength, sqrt(0.52), accuracy: 0.001)
    }

    func testUnreviewedOrBrokenTopologyFailsClosed() {
        XCTAssertNil(CoherentAtlasRigPlanner.plan(
            manifest: manifest(missingParent: true),
            reference: observed(),
            current: observed(timestamp: 1033),
            registration: registration()
        ))
        XCTAssertNil(CoherentAtlasRigPlanner.plan(
            manifest: manifest(malformedChild: true),
            reference: observed(),
            current: observed(timestamp: 1033),
            registration: registration()
        ))
    }

    func testLowConfidenceOrLengthMismatchFailsEntirePose() {
        let reference = observed()
        let lowConfidence = observed(
            timestamp: 1033, moving: true, elbowConfidence: 0.1
        )
        XCTAssertNil(CoherentAtlasRigPlanner.plan(
            manifest: manifest(), reference: reference,
            current: lowConfidence, registration: registration()
        ))

        var outlier = observed(timestamp: 1033, moving: true)
        var points = outlier.worldPoints
        points[13] = world(-1.5, 0.48)
        outlier = PoseSnapshot(
            timestampMilliseconds: 1033,
            imageSize: outlier.imageSize,
            points: outlier.points,
            worldPoints: points
        )
        XCTAssertNil(CoherentAtlasRigPlanner.plan(
            manifest: manifest(), reference: reference,
            current: outlier, registration: registration()
        ))
    }

    func testCannotReuseFrozenCalibrationAcrossDifferentImageSizes() {
        let source = observed()
        let sample = observed(timestamp: 1033, moving: true)
        let changed = PoseSnapshot(
            timestampMilliseconds: sample.timestampMilliseconds,
            imageSize: CGSize(width: 1280, height: 720),
            points: sample.points, worldPoints: sample.worldPoints
        )
        XCTAssertNil(CoherentAtlasRigPlanner.plan(
            manifest: manifest(), reference: source, current: changed,
            registration: registration()
        ))
    }

    func testNonfiniteAndInvalidLimitsRejected() {
        let no = CoherentAtlasRigPlanner.Limits(
            maximumRestAngleRadians: .nan,
            maximumCurrentAngleRadians: 2,
            maximumLengthErrorFraction: 0.2,
            maximumAttachmentErrorFraction: 0.2
        )
        XCTAssertNil(CoherentAtlasRigPlanner.plan(
            manifest: manifest(), reference: observed(),
            current: observed(timestamp: 1033),
            registration: registration(), limits: no
        ))
    }
}

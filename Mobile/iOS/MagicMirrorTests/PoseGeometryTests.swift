import CoreGraphics
import XCTest
@testable import MagicMirror

final class PoseGeometryTests: XCTestCase {
    private func posePoint(_ x: CGFloat, _ y: CGFloat, confidence: Float = 0.95) -> PosePoint {
        PosePoint(x: x, y: y, visibility: confidence)
    }

    func testPortraitAspectFillWithoutCrop() {
        let actual = PoseSkeleton.pointInPreview(
            posePoint(0.5, 0.5),
            imageSize: CGSize(width: 720, height: 1280),
            viewSize: CGSize(width: 360, height: 640)
        )
        XCTAssertNotNil(actual)
        XCTAssertEqual(actual!.x, 180, accuracy: 0.001)
        XCTAssertEqual(actual!.y, 320, accuracy: 0.001)
    }

    func testNonsquareDisplayCropsSymmetrically() {
        let size = CGSize(width: 390, height: 844)
        let image = CGSize(width: 720, height: 1280)
        let center = PoseSkeleton.pointInPreview(
            posePoint(0.5, 0.5), imageSize: image, viewSize: size
        )
        XCTAssertNotNil(center)
        XCTAssertEqual(center!.x, 195, accuracy: 0.001)
        XCTAssertEqual(center!.y, 422, accuracy: 0.001)
        let left = PoseSkeleton.pointInPreview(
            posePoint(0, 0), imageSize: image, viewSize: size
        )
        XCTAssertNotNil(left)
        XCTAssertLessThan(left!.x, 0)
        XCTAssertEqual(left!.y, 0, accuracy: 0.001)
    }

    func testConfidenceAndFiniteCoordinateGate() {
        let image = CGSize(width: 720, height: 1280)
        let display = CGSize(width: 390, height: 844)
        XCTAssertNil(PoseSkeleton.pointInPreview(
            posePoint(0.5, 0.5, confidence: 0.2),
            imageSize: image, viewSize: display
        ))
        XCTAssertNil(PoseSkeleton.pointInPreview(
            posePoint(.nan, 0.5), imageSize: image, viewSize: display
        ))
        XCTAssertNil(PoseSkeleton.pointInPreview(
            posePoint(0.5, 0.5), imageSize: .zero, viewSize: display
        ))
    }

    func testPartialUpperBodyWithoutHipsIsDrawable() {
        var points = Array(
            repeating: posePoint(0.5, 0.5, confidence: 0.1), count: 33
        )
        points[11] = posePoint(0.3, 0.3)
        points[13] = posePoint(0.25, 0.4)
        points[15] = posePoint(0.2, 0.55)
        let pose = PoseSnapshot(
            timestampMilliseconds: 100,
            imageSize: CGSize(width: 720, height: 1280),
            points: points
        )
        XCTAssertTrue(pose.isUsable)
        XCTAssertEqual(pose.coverage, .partial)
        XCTAssertFalse(pose.hasTorsoAnchor)
        XCTAssertEqual(pose.drawableSegments.count, 2)
        XCTAssertEqual(pose.confidence(for: .arms), 0.95, accuracy: 0.0001)
        XCTAssertEqual(pose.confidence(for: .torso), 0)
        XCTAssertEqual(pose.confidence(for: .legs), 0)
    }

    func testFourTorsoAnchorsStillGateFullTracking() {
        var points = Array(repeating: posePoint(0.5, 0.5), count: 33)
        let source = CGSize(width: 720, height: 1280)
        let full = PoseSnapshot(
            timestampMilliseconds: 100, imageSize: source, points: points
        )
        XCTAssertTrue(full.isUsable)
        XCTAssertTrue(full.hasTorsoAnchor)
        XCTAssertEqual(full.coverage, .torsoAnchored)
        points[24] = posePoint(0.5, 0.5, confidence: 0.1)
        let partial = PoseSnapshot(
            timestampMilliseconds: 101, imageSize: source, points: points
        )
        XCTAssertTrue(partial.isUsable)
        XCTAssertFalse(partial.hasTorsoAnchor)
        XCTAssertEqual(partial.coverage, .partial)
    }

    func testOnlyUnconnectedJointsAndMalformedCaptureAreRejected() {
        var points = Array(
            repeating: posePoint(0.5, 0.5, confidence: 0.1), count: 33
        )
        points[0] = posePoint(0.4, 0.2)  // nose is not a limb segment
        points[11] = posePoint(0.3, 0.4)
        let source = CGSize(width: 720, height: 1280)
        let alone = PoseSnapshot(
            timestampMilliseconds: 100, imageSize: source, points: points
        )
        XCTAssertFalse(alone.isUsable)
        XCTAssertEqual(alone.coverage, .none)
        points[13] = posePoint(0.2, 0.5)
        let malformedCount = PoseSnapshot(
            timestampMilliseconds: 101, imageSize: source,
            points: Array(points.prefix(32))
        )
        XCTAssertFalse(malformedCount.isUsable)
        XCTAssertFalse(malformedCount.hasValidLandmarks)
        let malformedSize = PoseSnapshot(
            timestampMilliseconds: 102,
            imageSize: CGSize(width: .nan, height: 1280),
            points: points
        )
        XCTAssertFalse(malformedSize.isUsable)
        XCTAssertEqual(malformedSize.confidence(for: .arms), 0)
    }

    func testMissingElbowNeverBridgesShoulderDirectlyToWrist() {
        var points = Array(
            repeating: posePoint(0.5, 0.5, confidence: 0.1), count: 33
        )
        points[11] = posePoint(0.3, 0.3)
        points[13] = posePoint(0.25, 0.4, confidence: 0.2)
        points[15] = posePoint(0.2, 0.55)
        points[12] = posePoint(0.65, 0.3)
        points[14] = posePoint(0.7, 0.4)
        let pose = PoseSnapshot(
            timestampMilliseconds: 103,
            imageSize: CGSize(width: 720, height: 1280),
            points: points
        )
        XCTAssertEqual(pose.coverage, .partial)
        XCTAssertEqual(pose.drawableSegments.count, 2)
        XCTAssertFalse(pose.drawableSegments.contains {
            $0.from == 11 && $0.to == 13
        })
        XCTAssertTrue(pose.drawableSegments.contains {
            $0.from == 12 && $0.to == 14
        })
    }

    func testLeftAndRightLimbConnectionsRemainDistinct() {
        let edges = PoseSkeleton.segments
        XCTAssertTrue(edges.contains { $0.from == 11 && $0.to == 13 })
        XCTAssertTrue(edges.contains { $0.from == 13 && $0.to == 15 })
        XCTAssertTrue(edges.contains { $0.from == 24 && $0.to == 26 })
        XCTAssertTrue(edges.contains { $0.from == 26 && $0.to == 28 })
    }
}

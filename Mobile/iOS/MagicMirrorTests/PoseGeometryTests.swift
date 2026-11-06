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

    func testValidPoseRequires33PointsAndShoulderHipConfidence() {
        var points = Array(repeating: posePoint(0.5, 0.5), count: 33)
        let source = CGSize(width: 720, height: 1280)
        XCTAssertTrue(PoseSnapshot(
            timestampMilliseconds: 100, imageSize: source, points: points
        ).isUsable)
        points[24] = posePoint(0.5, 0.5, confidence: 0.1)
        XCTAssertFalse(PoseSnapshot(
            timestampMilliseconds: 101, imageSize: source, points: points
        ).isUsable)
        XCTAssertFalse(PoseSnapshot(
            timestampMilliseconds: 102, imageSize: source,
            points: Array(points.prefix(32))
        ).isUsable)
    }

    func testLeftAndRightLimbConnectionsRemainDistinct() {
        let edges = PoseSkeleton.segments
        XCTAssertTrue(edges.contains { $0.from == 11 && $0.to == 13 })
        XCTAssertTrue(edges.contains { $0.from == 13 && $0.to == 15 })
        XCTAssertTrue(edges.contains { $0.from == 24 && $0.to == 26 })
        XCTAssertTrue(edges.contains { $0.from == 26 && $0.to == 28 })
    }
}

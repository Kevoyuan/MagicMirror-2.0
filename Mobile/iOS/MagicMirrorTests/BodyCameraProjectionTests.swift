import CoreGraphics
import XCTest
import simd
@testable import MagicMirror

final class BodyCameraProjectionTests: XCTestCase {
    private let camera = BodyCameraIntrinsics(
        fx: 800, fy: 800, cx: 360, cy: 640, width: 720, height: 1280
    )

    private var identity: BodyToCameraTransform {
        BodyToCameraTransform(
            rotation: simd_quatf(
                angle: 0, axis: SIMD3<Float>(0, 1, 0)
            ),
            translation: SIMD3<Float>(0, 0, 0)
        )
    }

    private func syntheticPose(
        sourceCamera: BodyToCameraTransform,
        shiftX: Float = 0
    ) -> PoseSnapshot {
        let positions: [SIMD3<Float>] = (0..<33).map { index in
            SIMD3<Float>(
                Float(index % 6 - 3) * 0.055,
                Float(index / 6 - 3) * 0.055,
                1 + Float(index % 3) * 0.07
            )
        }
        let points: [PosePoint] = positions.map { p in
            let projected = BodyCameraProjection.project(
                bodyWorld: p, camera: camera,
                bodyToCamera: sourceCamera
            )!
            return PosePoint(
                x: CGFloat(projected.normalizedX + shiftX),
                y: CGFloat(projected.normalizedY),
                visibility: 0.98
            )
        }
        let world: [PoseWorldPoint] = positions.map { p in
            PoseWorldPoint(
                x: p.x, y: p.y, z: p.z, visibility: 0.98
            )
        }
        return PoseSnapshot(
            timestampMilliseconds: 1000,
            imageSize: CGSize(width: 720, height: 1280),
            points: points, worldPoints: world
        )
    }

    func testProjectsExpectedPixelsWithKnownIntrinsics() {
        let p = BodyCameraProjection.project(
            bodyWorld: SIMD3<Float>(0.2, -0.1, 1),
            camera: camera, bodyToCamera: identity
        )
        XCTAssertNotNil(p)
        XCTAssertEqual(p!.normalizedX, 520.0 / 720.0, accuracy: 0.00001)
        XCTAssertEqual(p!.normalizedY, 560.0 / 1280.0, accuracy: 0.00001)
        XCTAssertEqual(p!.depthMeters, 1, accuracy: 0.00001)
    }

    func testRejectsBehindCameraAndInvalidIntrinsicDimensions() {
        XCTAssertNil(BodyCameraProjection.project(
            bodyWorld: SIMD3<Float>(0, 0, -1),
            camera: camera, bodyToCamera: identity
        ))
        let invalid = BodyCameraIntrinsics(
            fx: 0, fy: 800, cx: 360, cy: 640, width: 720, height: 1280
        )
        XCTAssertNil(BodyCameraProjection.project(
            bodyWorld: SIMD3<Float>(0, 0, 1),
            camera: invalid, bodyToCamera: identity
        ))
    }

    func testKnownSyntheticCameraHasNearZeroReprojectionError() {
        let snapshot = syntheticPose(sourceCamera: identity)
        let result = BodyReprojectionGate.evaluate(
            snapshot: snapshot, camera: camera, transform: identity
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.visibleCount, 33)
        XCTAssertTrue(result!.accepted)
        XCTAssertLessThan(result!.p90ErrorFractionOfImageWidth, 0.00001)
    }

    func testIncorrectExtrinsicFailsReprojectionGate() {
        let snapshot = syntheticPose(sourceCamera: identity)
        let shifted = BodyToCameraTransform(
            rotation: identity.rotation,
            translation: SIMD3<Float>(0.15, 0, 0)
        )
        let result = BodyReprojectionGate.evaluate(
            snapshot: snapshot, camera: camera, transform: shifted
        )
        XCTAssertNotNil(result)
        XCTAssertFalse(result!.accepted)
        XCTAssertGreaterThan(result!.p90ErrorFractionOfImageWidth, 0.03)
    }

    func testSourceImageDimensionMismatchFailsClosed() {
        let original = syntheticPose(sourceCamera: identity)
        let mismatch = BodyCameraIntrinsics(
            fx: 800, fy: 800, cx: 360, cy: 640,
            width: 1280, height: 720
        )
        XCTAssertNil(BodyReprojectionGate.evaluate(
            snapshot: original, camera: mismatch, transform: identity
        ))
    }

    func testMissingWorldLandmarksNeverAcceptsCameraCalibration() {
        let source = syntheticPose(sourceCamera: identity)
        let missing = PoseSnapshot(
            timestampMilliseconds: 1001, imageSize: source.imageSize,
            points: source.points
        )
        XCTAssertNil(BodyReprojectionGate.evaluate(
            snapshot: missing, camera: camera, transform: identity
        ))
    }

    func testVisibleLandmarkReprojectionHasExplicitPixelWidthUnits() {
        let source = syntheticPose(
            sourceCamera: identity, shiftX: 0.035
        )
        let report = BodyReprojectionGate.evaluate(
            snapshot: source, camera: camera, transform: identity
        )
        XCTAssertNotNil(report)
        XCTAssertFalse(report!.accepted)
        XCTAssertEqual(
            report!.p90ErrorFractionOfImageWidth, 0.035, accuracy: 0.001
        )
    }
}

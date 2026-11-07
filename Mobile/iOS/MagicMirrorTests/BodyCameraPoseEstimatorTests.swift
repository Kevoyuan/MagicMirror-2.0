import CoreGraphics
import XCTest
import simd
@testable import MagicMirror

/// Deterministic synthetic 3D source and exactly projected image points.
/// These are mathematical fixtures, NOT real-camera/body accuracy evidence.
final class BodyCameraPoseEstimatorTests: XCTestCase {
    private let intrinsics = BodyCameraIntrinsics(
        fx: 850, fy: 845, cx: 360, cy: 640,
        width: 720, height: 1280
    )

    private var source: [Int: SIMD3<Float>] {
        [
            11: SIMD3(-0.25, -0.42, -0.08),
            12: SIMD3(0.25, -0.42, -0.06),
            13: SIMD3(-0.41, -0.19, 0.04),
            14: SIMD3(0.43, -0.19, 0.06),
            15: SIMD3(-0.53, 0.06, 0.16),
            16: SIMD3(0.54, 0.07, 0.13),
            23: SIMD3(-0.19, 0.05, 0),
            24: SIMD3(0.19, 0.05, 0),
            25: SIMD3(-0.20, 0.40, 0.09),
            26: SIMD3(0.20, 0.40, 0.08),
            27: SIMD3(-0.21, 0.75, 0.15),
            28: SIMD3(0.21, 0.75, 0.13),
            29: SIMD3(-0.22, 0.79, 0.17),
            30: SIMD3(0.22, 0.79, 0.15),
            31: SIMD3(-0.24, 0.89, 0.20),
            32: SIMD3(0.24, 0.89, 0.18)
        ]
    }

    private func projectedPose(
        extrinsic: BodyToCameraTransform,
        badIndices: Set<Int> = []
    ) -> PoseSnapshot {
        var image = Array(
            repeating: PosePoint(
                x: 0.5, y: 0.5, visibility: 0.01
            ),
            count: 33
        )
        var world = Array(
            repeating: PoseWorldPoint(
                x: 0, y: 0, z: 0, visibility: 0.01
            ),
            count: 33
        )
        for (index, point) in source {
            let observation = BodyCameraProjection.project(
                bodyWorld: point, camera: intrinsics,
                bodyToCamera: extrinsic
            )!
            let error: Float = badIndices.contains(index) ? 0.12 : 0
            image[index] = PosePoint(
                x: CGFloat(observation.normalizedX + error),
                y: CGFloat(observation.normalizedY - error),
                visibility: 0.99
            )
            world[index] = PoseWorldPoint(
                x: point.x, y: point.y, z: point.z,
                visibility: 0.99
            )
        }
        return PoseSnapshot(
            timestampMilliseconds: 1000,
            imageSize: CGSize(width: 720, height: 1280),
            points: image,
            worldPoints: world,
            cameraIntrinsics: intrinsics
        )
    }

    private func transform(
        yaw: Float = 0, x: Float = 0.03,
        y: Float = -0.04, z: Float = 2.7
    ) -> BodyToCameraTransform {
        BodyToCameraTransform(
            rotation: simd_quatf(
                angle: yaw, axis: SIMD3<Float>(0, 1, 0)
            ),
            translation: SIMD3<Float>(x, y, z)
        )
    }

    func testFitsFrontalSyntheticPoseWithoutManualCameraOffset() {
        let trueCamera = transform()
        let snapshot = projectedPose(extrinsic: trueCamera)
        let estimated = BodyCameraPoseEstimator.estimate(
            snapshot: snapshot
        )
        XCTAssertNotNil(estimated)
        XCTAssertTrue(estimated!.reprojection.accepted)
        XCTAssertGreaterThanOrEqual(
            estimated!.reprojection.visibleCount, 12
        )
        XCTAssertLessThan(
            estimated!.reprojection.p90ErrorFractionOfImageWidth,
            0.01
        )
        XCTAssertEqual(
            estimated!.transform.translation.z, 2.7,
            accuracy: 0.30
        )
    }

    func testFitsSmallBodyCameraYawChange() {
        let snapshot = projectedPose(
            extrinsic: transform(yaw: 0.12, x: 0.05)
        )
        let estimated = BodyCameraPoseEstimator.estimate(
            snapshot: snapshot
        )
        XCTAssertNotNil(estimated)
        XCTAssertLessThan(
            estimated!.reprojection.p90ErrorFractionOfImageWidth,
            0.01
        )
    }

    func testRejectsInconsistent2D3DCorrespondences() {
        let snapshot = projectedPose(
            extrinsic: transform(),
            badIndices: [11, 13, 15, 24, 26, 28, 32]
        )
        let estimated = BodyCameraPoseEstimator.estimate(
            snapshot: snapshot
        )
        XCTAssertNil(estimated)
    }

    func testRejectsMissingCameraCalibration() {
        let good = projectedPose(extrinsic: transform())
        let lacking = PoseSnapshot(
            timestampMilliseconds: good.timestampMilliseconds,
            imageSize: good.imageSize,
            points: good.points, worldPoints: good.worldPoints
        )
        XCTAssertNil(BodyCameraPoseEstimator.estimate(
            snapshot: lacking
        ))
    }

    func testRejectsDegenerateWorldGeometry() {
        let good = projectedPose(extrinsic: transform())
        var flat = good.worldPoints
        for index in BodyCameraPoseEstimator.bodyIndices {
            flat[index] = PoseWorldPoint(
                x: 0, y: 0, z: 0, visibility: 0.99
            )
        }
        let bad = PoseSnapshot(
            timestampMilliseconds: good.timestampMilliseconds,
            imageSize: good.imageSize,
            points: good.points, worldPoints: flat,
            cameraIntrinsics: intrinsics
        )
        XCTAssertNil(BodyCameraPoseEstimator.estimate(
            snapshot: bad
        ))
    }

    func testRejectsInsufficientVisibleJoints() {
        let good = projectedPose(extrinsic: transform())
        var image = good.points
        for index in [13, 14, 15, 16, 25, 26, 27, 28] {
            image[index] = PosePoint(
                x: 0.5, y: 0.5, visibility: 0.1
            )
        }
        let bad = PoseSnapshot(
            timestampMilliseconds: good.timestampMilliseconds,
            imageSize: good.imageSize,
            points: image, worldPoints: good.worldPoints,
            cameraIntrinsics: intrinsics
        )
        XCTAssertNil(BodyCameraPoseEstimator.estimate(
            snapshot: bad
        ))
    }

    func testRejectsWrongImageDimensions() {
        let good = projectedPose(extrinsic: transform())
        let wrong = PoseSnapshot(
            timestampMilliseconds: good.timestampMilliseconds,
            imageSize: CGSize(width: 1280, height: 720),
            points: good.points, worldPoints: good.worldPoints,
            cameraIntrinsics: intrinsics
        )
        XCTAssertNil(BodyCameraPoseEstimator.estimate(
            snapshot: wrong
        ))
    }
}

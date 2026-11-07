import CoreGraphics
import Foundation
import simd

/// Executed on the CI Mac (no iPhone/camera). The fixture is synthetic,
/// and checks math only; not real camera extrinsics or human accuracy.
@main
enum PoseMathSmoke {
    static let intrinsics = BodyCameraIntrinsics(
        fx: 850, fy: 845, cx: 360, cy: 640,
        width: 720, height: 1280
    )

    static let sampleBody: [Int: SIMD3<Float>] = [
        11: SIMD3(-0.25, -0.42, -0.08),
        12: SIMD3( 0.25, -0.42, -0.06),
        13: SIMD3(-0.41, -0.19,  0.04),
        14: SIMD3( 0.43, -0.19,  0.06),
        15: SIMD3(-0.53,  0.06,  0.16),
        16: SIMD3( 0.54,  0.07,  0.13),
        23: SIMD3(-0.19,  0.05,  0.00),
        24: SIMD3( 0.19,  0.05,  0.00),
        25: SIMD3(-0.20,  0.40,  0.09),
        26: SIMD3( 0.20,  0.40,  0.08),
        27: SIMD3(-0.21,  0.75,  0.15),
        28: SIMD3( 0.21,  0.75,  0.13),
        29: SIMD3(-0.22,  0.79,  0.17),
        30: SIMD3( 0.22,  0.79,  0.15),
        31: SIMD3(-0.24,  0.89,  0.20),
        32: SIMD3( 0.24,  0.89,  0.18)
    ]

    static func createPose(
        yaw: Float, damaged: Set<Int> = []
    ) -> PoseSnapshot {
        let transform = BodyToCameraTransform(
            rotation: simd_quatf(
                angle: yaw, axis: SIMD3<Float>(0, 1, 0)
            ),
            translation: SIMD3<Float>(0.04, -0.05, 2.7)
        )
        var points = Array(
            repeating: PosePoint(
                x: 0.5, y: 0.5, visibility: 0.0
            ),
            count: 33
        )
        var world = Array(
            repeating: PoseWorldPoint(
                x: 0, y: 0, z: 0, visibility: 0.0
            ),
            count: 33
        )
        for (index, point) in sampleBody {
            guard let xy = BodyCameraProjection.project(
                bodyWorld: point, camera: intrinsics,
                bodyToCamera: transform
            ) else { fatalError("Synthetic input not projectable") }
            let corrupt: Float = damaged.contains(index) ? 0.12 : 0
            points[index] = PosePoint(
                x: CGFloat(xy.normalizedX + corrupt),
                y: CGFloat(xy.normalizedY - corrupt),
                visibility: 0.99
            )
            world[index] = PoseWorldPoint(
                x: point.x, y: point.y, z: point.z,
                visibility: 0.99
            )
        }
        return PoseSnapshot(
            timestampMilliseconds: 1234,
            imageSize: CGSize(width: 720, height: 1280),
            points: points,
            worldPoints: world,
            cameraIntrinsics: intrinsics
        )
    }

    static func main() {
        for angle: Float in [0, 0.12] {
            let input = createPose(yaw: angle)
            guard let result = BodyCameraPoseEstimator.estimate(
                snapshot: input
            ) else {
                fatalError("Synthetic camera pose estimation failed")
            }
            guard result.reprojection.accepted,
                  result.reprojection.visibleCount >= 12,
                  result.reprojection.p90ErrorFractionOfImageWidth < 0.01
            else {
                fatalError("Synthetic camera reprojection gate failed")
            }
            print(
                "PASS: pose yaw=\(angle) projected P90=\(result.reprojection.p90ErrorFractionOfImageWidth) normalized image width"
            )
        }
        let corrupt = createPose(
            yaw: 0, damaged: [11, 13, 15, 24, 26, 28, 32]
        )
        precondition(
            BodyCameraPoseEstimator.estimate(
                snapshot: corrupt
            ) == nil,
            "Corrupted 2D↔3D correspondences should fail closed"
        )
        print("PASS: corrupted pose rejected")
        print("PASS: only synthetic macOS math executed; NO phone proof")
    }
}

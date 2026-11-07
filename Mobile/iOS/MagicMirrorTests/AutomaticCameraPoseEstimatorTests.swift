import CoreGraphics
import simd
import XCTest
@testable import MagicMirror

/// Synthetic camera and world coordinates, not a human calibration.
final class AutomaticCameraPoseEstimatorTests: XCTestCase {
    private let size = CGSize(width: 720, height: 1280)

    private func intrinsics() -> BodyCameraIntrinsics {
        BodyCameraIntrinsics(
            fx: 700, fy: 710, cx: 360, cy: 640,
            width: 720, height: 1280
        )
    }

    private func transform() -> BodyToCameraTransform {
        let yaw = simd_quatf(
            angle: 0.28, axis: SIMD3<Float>(0, 1, 0)
        )
        let pitch = simd_quatf(
            angle: -0.11, axis: SIMD3<Float>(1, 0, 0)
        )
        return BodyToCameraTransform(
            rotation: pitch * yaw,
            translation: SIMD3<Float>(0.12, -0.07, 2.8)
        )
    }

    private func frame(
        timestamp: Int = 1000,
        includeIntrinsics: Bool = true,
        zFlat: Bool = false,
        corruptPixels: Bool = false,
        hideTorso: Bool = false
    ) -> PoseSnapshot {
        var world: [PoseWorldPoint] = []
        for i in 0..<33 {
            let x = Float(i % 6) * 0.12 - 0.30
            let y = Float(i / 6) * 0.15 - 0.35
            let z: Float = zFlat ? 0 : Float(i % 5) * 0.065 - 0.10
            world.append(PoseWorldPoint(
                x: x, y: y, z: z, visibility: 0.99
            ))
        }
        world[11] = PoseWorldPoint(
            x: -0.24, y: 0.42, z: zFlat ? 0 : 0.06,
            visibility: 0.99
        )
        world[12] = PoseWorldPoint(
            x: 0.24, y: 0.42, z: zFlat ? 0 : -0.05,
            visibility: 0.99
        )
        world[23] = PoseWorldPoint(
            x: -0.17, y: -0.12, z: zFlat ? 0 : 0.04,
            visibility: 0.99
        )
        world[24] = PoseWorldPoint(
            x: 0.17, y: -0.12, z: zFlat ? 0 : -0.03,
            visibility: 0.99
        )

        var pixels: [PosePoint] = []
        for (index, point) in world.enumerated() {
            let p = BodyCameraProjection.project(
                bodyWorld: SIMD3(point.x, point.y, point.z),
                camera: intrinsics(),
                bodyToCamera: transform()
            )!
            let corrupt = corruptPixels && index < 8
            let confidence: Float = hideTorso && [
                11, 12, 23, 24
            ].contains(index) ? 0.1 : 0.99
            pixels.append(PosePoint(
                x: corrupt ? 0.95 : CGFloat(p.normalizedX),
                y: corrupt ? 0.12 : CGFloat(p.normalizedY),
                visibility: confidence
            ))
        }
        return PoseSnapshot(
            timestampMilliseconds: timestamp,
            imageSize: size,
            points: pixels,
            worldPoints: world,
            cameraIntrinsics: includeIntrinsics ? intrinsics() : nil
        )
    }

    func testKnownSyntheticPerspectiveRecoversCameraPoseCandidate() {
        let source = frame()
        let candidate = AutomaticCameraPoseEstimator.estimate(
            snapshot: source
        )
        XCTAssertNotNil(candidate)
        guard let candidate else { return }
        XCTAssertEqual(candidate.timestampMilliseconds, 1000)
        XCTAssertEqual(candidate.imageSize, size)
        XCTAssertGreaterThanOrEqual(candidate.landmarkCount, 9)
        XCTAssertLessThan(
            candidate.p90ReprojectionErrorFractionOfWidth, 0.01
        )
        XCTAssertEqual(
            candidate.transform.translation.z,
            transform().translation.z, accuracy: 0.25
        )
        let report = BodyReprojectionGate.evaluate(
            snapshot: source,
            camera: intrinsics(),
            transform: candidate.transform,
            requiredVisiblePoints: 9
        )
        XCTAssertEqual(report?.accepted, true)
    }

    func testRejectsMissingIntrinsicsFlatWorldAndHiddenTorso() {
        XCTAssertNil(AutomaticCameraPoseEstimator.estimate(
            snapshot: frame(includeIntrinsics: false)
        ))
        XCTAssertNil(AutomaticCameraPoseEstimator.estimate(
            snapshot: frame(zFlat: true)
        ))
        XCTAssertNil(AutomaticCameraPoseEstimator.estimate(
            snapshot: frame(hideTorso: true)
        ))
    }

    func testOutlierPixelsCannotPassStrictGlobalReprojection() {
        XCTAssertNil(AutomaticCameraPoseEstimator.estimate(
            snapshot: frame(corruptPixels: true)
        ))
        XCTAssertNil(AutomaticCameraPoseEstimator.estimate(
            snapshot: frame(),
            maxP90FractionOfImageWidth: .nan
        ))
    }

    func testFrameIdentityRetainedInDiagnosticCandidate() {
        let sample = frame(timestamp: 2345)
        let candidate = AutomaticCameraPoseEstimator.estimate(
            snapshot: sample
        )
        XCTAssertEqual(candidate?.timestampMilliseconds, 2345)
        XCTAssertEqual(candidate?.imageSize, sample.imageSize)
    }
}

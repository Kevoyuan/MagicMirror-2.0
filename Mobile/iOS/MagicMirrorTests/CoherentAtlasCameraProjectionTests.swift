import CoreGraphics
import simd
import XCTest
@testable import MagicMirror

/// Synthetic reprojection on constructed camera intrinsics/extrinsics.
/// No test flag or success implies actual iPhone lens or anatomy review.
final class CoherentAtlasCameraProjectionTests: XCTestCase {
    private let viewport = CGSize(width: 360, height: 640)

    private func camera() -> BodyCameraIntrinsics {
        BodyCameraIntrinsics(
            fx: 450, fy: 450, cx: 360, cy: 640,
            width: 720, height: 1280
        )
    }

    private func extrinsics() -> BodyToCameraTransform {
        BodyToCameraTransform(
            rotation: simd_quatf(
                angle: 0, axis: SIMD3<Float>(0, 1, 0)
            ),
            translation: SIMD3<Float>(0, 0, 3)
        )
    }

    private func snapshot(timestamp: Int = 1000) -> PoseSnapshot {
        var world = Array(
            repeating: PoseWorldPoint(
                x: 0, y: 0, z: 0, visibility: 1
            ), count: 33
        )
        world[11] = PoseWorldPoint(
            x: -0.2, y: 0.5, z: 0, visibility: 1
        )
        world[12] = PoseWorldPoint(
            x: 0.2, y: 0.5, z: 0, visibility: 1
        )
        world[23] = PoseWorldPoint(
            x: -0.15, y: 0, z: 0, visibility: 1
        )
        world[24] = PoseWorldPoint(
            x: 0.15, y: 0, z: 0, visibility: 1
        )
        world[13] = PoseWorldPoint(
            x: -0.4, y: 0.2, z: 0, visibility: 1
        )
        let pixels: [PosePoint] = world.map { p in
            let projection = BodyCameraProjection.project(
                bodyWorld: SIMD3(p.x, p.y, p.z),
                camera: camera(), bodyToCamera: extrinsics()
            )!
            return PosePoint(
                x: CGFloat(projection.normalizedX),
                y: CGFloat(projection.normalizedY),
                visibility: 1
            )
        }
        return PoseSnapshot(
            timestampMilliseconds: timestamp,
            imageSize: CGSize(width: 720, height: 1280),
            points: pixels, worldPoints: world
        )
    }

    private func rigManifest() -> AnatomyAtlasManifest {
        AnatomyAtlasManifest(
            atlasId: "synthetic-review-only",
            sourceURL: "test://nonlicensed",
            sourceRevision: "test",
            attribution: "synthetic source for XCTest",
            licenseIdentifier: "test-only",
            assetFilename: "test.usdz",
            assetSHA256: String(repeating: "a", count: 64),
            licenseReviewed: true,
            anatomyReviewed: true,
            bones: [
                AnatomyAtlasManifest.BoneBinding(
                    id: "left-humerus", nodePath: "test/humerus",
                    parentId: nil, proximalLandmark: 11,
                    distalLandmark: 13,
                    restStart: [-0.4, 1, 0],
                    restEnd: [-0.8, 0.4, 0],
                    anchorsReviewed: true
                )
            ]
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
            allowedScale: 1.5 ... 2.5,
            maximumPelvisResidual: 0.01
        )
        XCTAssertNotNil(result)
        return result!
    }

    private func rig(
        frame: PoseSnapshot,
        transform: BodySimilarityRegistration
    ) -> CoherentAtlasRigPose {
        let result = CoherentAtlasRigPlanner.plan(
            manifest: rigManifest(),
            reference: frame, current: frame,
            registration: transform
        )
        XCTAssertNotNil(result)
        return result!
    }

    func testReviewedSameSourceFrameProjectsKnownAtlasRootPoint() {
        let frame = snapshot()
        let transform = registration()
        let pose = rig(frame: frame, transform: transform)
        let projector = CoherentAtlasCameraProjection.prepare(
            pose: pose, matchingFrame: frame,
            registration: transform, intrinsics: camera(),
            extrinsics: extrinsics(),
            independentCameraReviewConfirmed: true
        )
        XCTAssertNotNil(projector)
        XCTAssertLessThan(
            projector!.reprojection.p90ErrorFractionOfImageWidth,
            0.0001
        )
        let projected = projector?.project(
            boneId: "left-humerus",
            restPoint: SIMD3(-0.4, 1, 0),
            viewport: viewport
        )
        XCTAssertNotNil(projected)
        // In this synthetic identity camera model:
        // u = 360 + 450 * (-0.2)/3 = 330px.
        // v = 640 + 450 * (0.5)/3 = 715px.
        // 720x1280 -> 360x640 (exact 0.5 scaling).
        XCTAssertEqual(projected!.displayPosition.x, 165, accuracy: 0.01)
        XCTAssertEqual(projected!.displayPosition.y, 357.5, accuracy: 0.01)
        XCTAssertEqual(projected!.cameraDepthMeters, 3, accuracy: 0.001)
    }

    func testUnreviewedCameraAndWrongTimestampCannotProject() {
        let frame = snapshot()
        let transform = registration()
        let pose = rig(frame: frame, transform: transform)
        XCTAssertNil(CoherentAtlasCameraProjection.prepare(
            pose: pose, matchingFrame: frame,
            registration: transform, intrinsics: camera(),
            extrinsics: extrinsics(),
            independentCameraReviewConfirmed: false
        ))
        XCTAssertNil(CoherentAtlasCameraProjection.prepare(
            pose: pose, matchingFrame: snapshot(timestamp: 1001),
            registration: transform, intrinsics: camera(),
            extrinsics: extrinsics(),
            independentCameraReviewConfirmed: true
        ))
    }

    func testProjectionGatesMismatchAndHighP90() {
        let frame = snapshot()
        let transform = registration()
        let pose = rig(frame: frame, transform: transform)
        let wrongWidth = BodyCameraIntrinsics(
            fx: 450, fy: 450, cx: 360, cy: 640,
            width: 1280, height: 720
        )
        XCTAssertNil(CoherentAtlasCameraProjection.prepare(
            pose: pose, matchingFrame: frame,
            registration: transform, intrinsics: wrongWidth,
            extrinsics: extrinsics(),
            independentCameraReviewConfirmed: true
        ))

        var shiftedPixels = frame.points
        for i in 0..<12 {
            let p = shiftedPixels[i]
            shiftedPixels[i] = PosePoint(
                x: p.x + 0.12,
                y: p.y, visibility: p.visibility
            )
        }
        let shifted = PoseSnapshot(
            timestampMilliseconds: frame.timestampMilliseconds,
            imageSize: frame.imageSize,
            points: shiftedPixels, worldPoints: frame.worldPoints
        )
        XCTAssertNil(CoherentAtlasCameraProjection.prepare(
            pose: pose, matchingFrame: shifted,
            registration: transform, intrinsics: camera(),
            extrinsics: extrinsics(),
            independentCameraReviewConfirmed: true
        ))
    }

    func testInvalidBoneAndNanCannotDrawCameraGeometry() {
        let frame = snapshot()
        let transform = registration()
        let pose = rig(frame: frame, transform: transform)
        let projector = CoherentAtlasCameraProjection.prepare(
            pose: pose, matchingFrame: frame,
            registration: transform, intrinsics: camera(),
            extrinsics: extrinsics(),
            independentCameraReviewConfirmed: true
        )
        XCTAssertNotNil(projector)
        XCTAssertNil(projector?.project(
            boneId: "not-in-reviewed-rig",
            restPoint: SIMD3(0, 0, 0),
            viewport: viewport
        ))
        XCTAssertNil(projector?.project(
            boneId: "left-humerus",
            restPoint: SIMD3(Float.nan, 0, 0),
            viewport: viewport
        ))
        XCTAssertNil(projector?.project(
            boneId: "left-humerus",
            restPoint: SIMD3(-0.4, 1, 0),
            viewport: .zero
        ))
    }
}

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

    /// Synthetic fixtures prove interface wiring, not source-model approval.
    private func meshAtlas(
        path: String = "test/humerus",
        revision: String = "test",
        distal: Int = 13
    ) -> VerifiedAnatomyAtlas {
        let manifest = MobileAtlasManifest(
            schemaVersion: 1,
            sourceRepository: "synthetic://not-real",
            sourceRevision: revision,
            sourcePath: "fixture",
            modelFile: "skeleton_atlas.mmgeom",
            modelSHA256: String(repeating: "a", count: 64),
            licenseIds: [],
            attribution: [],
            modificationNotes: ["synthetic XCTest only"],
            reviewedForDistribution: true,
            reviewedJointBindings: true,
            parts: [
                MobileAtlasBinding(
                    sourceHierarchyPath: path,
                    displayName: "Synthetic humerus",
                    group: "arms",
                    fromLandmark: 11, toLandmark: distal,
                    restFrom: [-0.4, 1, 0],
                    restTo: [-0.8, 0.4, 0],
                    vertexOffset: 0, vertexCount: 3
                )
            ]
        )
        return VerifiedAnatomyAtlas(
            manifest: manifest,
            vertices: [
                AtlasRestVertex(
                    position: SIMD3<Float>(-0.4, 1, 0),
                    normal: SIMD3<Float>(0, 0, 1)
                ),
                AtlasRestVertex(
                    position: SIMD3<Float>(-0.5, 0.9, 0),
                    normal: SIMD3<Float>(0, 0, 1)
                ),
                AtlasRestVertex(
                    position: SIMD3<Float>(-0.6, 0.8, 0),
                    normal: SIMD3<Float>(0, 0, 1)
                )
            ]
        )
    }

    func testCoherentMeshProjectsOnlyMatchingReviewedHierarchy() {
        let frame = snapshot()
        let registration = registration()
        let projector = CoherentAtlasCameraProjection.prepare(
            pose: rig(frame: frame, transform: registration),
            matchingFrame: frame,
            registration: registration,
            intrinsics: camera(),
            extrinsics: extrinsics(),
            independentCameraReviewConfirmed: true
        )
        XCTAssertNotNil(projector)
        let triangles = CoherentAtlasMeshProjection.project(
            atlas: meshAtlas(),
            hierarchy: rigManifest(),
            projector: projector!,
            viewport: viewport,
            focus: .arms
        )
        XCTAssertEqual(triangles?.count, 1)
        XCTAssertEqual(triangles?.first?.boneId, "left-humerus")
        XCTAssertEqual(triangles?.first?.vertices.count, 3)
        XCTAssertEqual(triangles?.first?.cameraNormals.count, 3)
        XCTAssertEqual(
            triangles?.first?.cameraNormals.first?.z ?? 0,
            1, accuracy: 0.001
        )
        XCTAssertEqual(
            triangles?.first?.vertices.first?.displayPosition.x ?? -1,
            165, accuracy: 0.01
        )
        XCTAssertEqual(
            CoherentAtlasMeshProjection.project(
                atlas: meshAtlas(),
                hierarchy: rigManifest(),
                projector: projector!,
                viewport: viewport,
                focus: .legs
            )?.count, 0
        )
    }

    func testMeshFailsClosedOnPathRevisionOrJointMismatch() {
        let frame = snapshot()
        let registration = registration()
        let projector = CoherentAtlasCameraProjection.prepare(
            pose: rig(frame: frame, transform: registration),
            matchingFrame: frame,
            registration: registration,
            intrinsics: camera(),
            extrinsics: extrinsics(),
            independentCameraReviewConfirmed: true
        )!
        for atlas in [
            meshAtlas(path: "unreviewed/wrong-bone"),
            meshAtlas(revision: "different-revision"),
            meshAtlas(distal: 14)
        ] {
            XCTAssertNil(CoherentAtlasMeshProjection.project(
                atlas: atlas,
                hierarchy: rigManifest(),
                projector: projector,
                viewport: viewport,
                focus: .arms
            ))
        }
        XCTAssertNil(CoherentAtlasMeshProjection.project(
            atlas: meshAtlas(),
            hierarchy: rigManifest(),
            projector: projector,
            viewport: .zero,
            focus: .arms
        ))
    }

    func testCalibratedMetalBatchPreservesFrameFocusAndViewportIdentity() {
        let frame = snapshot()
        let transform = registration()
        let projector = CoherentAtlasCameraProjection.prepare(
            pose: rig(frame: frame, transform: transform),
            matchingFrame: frame,
            registration: transform, intrinsics: camera(),
            extrinsics: extrinsics(),
            independentCameraReviewConfirmed: true
        )!
        let source = meshAtlas()
        // A nondegenerate synthetic triangle, not licensed anatomy.
        let atlas = VerifiedAnatomyAtlas(
            manifest: source.manifest,
            vertices: [
                source.vertices[0],
                source.vertices[1],
                AtlasRestVertex(
                    position: SIMD3<Float>(-0.55, 0.70, 0),
                    normal: SIMD3<Float>(0, 0, 1)
                )
            ]
        )
        let batch = CalibratedAtlasDrawBatch.build(
            atlas: atlas, hierarchy: rigManifest(),
            projector: projector, viewport: viewport,
            opacity: 0.7, focus: .arms
        )
        XCTAssertNotNil(batch)
        XCTAssertEqual(batch?.vertices.count, 3)
        XCTAssertTrue(batch!.vertices.allSatisfy {
            (0...1).contains($0.position.z) &&
            abs($0.normal.z - 1) < 0.001
        })
        XCTAssertEqual(batch?.sourceTimestampMilliseconds, 1000)
        XCTAssertEqual(batch?.sourceImageSize, frame.imageSize)
        XCTAssertTrue(batch!.matches(
            frame: frame, viewport: viewport,
            focus: .arms, opacity: 0.7
        ))
        XCTAssertFalse(batch!.matches(
            frame: snapshot(timestamp: 1001), viewport: viewport,
            focus: .arms, opacity: 0.7
        ))
        XCTAssertFalse(batch!.matches(
            frame: frame, viewport: CGSize(width: 390, height: 844),
            focus: .arms, opacity: 0.7
        ))
        XCTAssertFalse(batch!.matches(
            frame: frame, viewport: viewport,
            focus: .legs, opacity: 0.7
        ))
        XCTAssertFalse(batch!.matches(
            frame: frame, viewport: viewport,
            focus: .arms, opacity: 0.6
        ))
        XCTAssertTrue(batch!.vertices.allSatisfy {
            $0.position.x.isFinite && $0.position.y.isFinite &&
            $0.position.z.isFinite && $0.color.w > 0
        })
    }

    func testCalibratedMetalBatchRejectsDegenerateOrUnreviewedInputs() {
        let frame = snapshot()
        let transform = registration()
        let projector = CoherentAtlasCameraProjection.prepare(
            pose: rig(frame: frame, transform: transform),
            matchingFrame: frame,
            registration: transform, intrinsics: camera(),
            extrinsics: extrinsics(),
            independentCameraReviewConfirmed: true
        )!
        // The original fixture has three collinear points. A triangle
        // with zero display area must not reach the GPU vertex buffer.
        XCTAssertNil(CalibratedAtlasDrawBatch.build(
            atlas: meshAtlas(), hierarchy: rigManifest(),
            projector: projector, viewport: viewport,
            opacity: 0.7, focus: .arms
        ))
        XCTAssertNil(CalibratedAtlasDrawBatch.build(
            atlas: meshAtlas(path: "wrong/mesh"),
            hierarchy: rigManifest(), projector: projector,
            viewport: viewport, opacity: 0.7, focus: .arms
        ))
        XCTAssertNil(CalibratedAtlasDrawBatch.build(
            atlas: meshAtlas(), hierarchy: rigManifest(),
            projector: projector, viewport: viewport,
            opacity: 0, focus: .arms
        ))
    }

    func testReviewedSurfaceNormalRotatesWithBoneInCameraSpace() {
        let frame = snapshot()
        let registration = registration()
        let rotation = simd_quatf(
            angle: .pi / 2, axis: SIMD3<Float>(0, 1, 0)
        )
        let reference = rig(frame: frame, transform: registration)
        let original = reference.bones[0]
        let turned = AtlasRigBonePose(
            boneId: original.boneId,
            parentId: original.parentId,
            restPivot: original.restPivot,
            posedPivot: original.posedPivot,
            restToPosedRotation: rotation,
            restLength: original.restLength,
            confidence: original.confidence
        )
        let turnedRig = CoherentAtlasRigPose(
            sourceTimestampMilliseconds: frame.timestampMilliseconds,
            sourceImageSize: frame.imageSize,
            bones: [turned]
        )
        let projector = CoherentAtlasCameraProjection.prepare(
            pose: turnedRig, matchingFrame: frame,
            registration: registration, intrinsics: camera(),
            extrinsics: extrinsics(),
            independentCameraReviewConfirmed: true
        )
        XCTAssertNotNil(projector)
        let n = projector?.cameraNormal(
            boneId: "left-humerus",
            restNormal: SIMD3<Float>(0, 0, 1)
        )
        XCTAssertNotNil(n)
        XCTAssertEqual(n!.x, 1, accuracy: 0.001)
        XCTAssertEqual(n!.z, 0, accuracy: 0.001)
        XCTAssertNil(projector?.cameraNormal(
            boneId: "unknown", restNormal: SIMD3(0, 0, 1)
        ))
        XCTAssertNil(projector?.cameraNormal(
            boneId: "left-humerus", restNormal: SIMD3(0, 0, 0)
        ))
    }
}

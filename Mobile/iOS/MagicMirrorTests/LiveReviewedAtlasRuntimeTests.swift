import CoreGraphics
import simd
import XCTest
@testable import MagicMirror

/// Entirely synthetic "review" records test runtime control flow, not
/// copyright, human anatomy or measured phone calibration.
@MainActor
final class LiveReviewedAtlasRuntimeTests: XCTestCase {
    private let viewport = CGSize(width: 360, height: 640)

    private func intrinsics() -> BodyCameraIntrinsics {
        BodyCameraIntrinsics(
            fx: 450, fy: 450, cx: 360, cy: 640,
            width: 720, height: 1280
        )
    }

    private func cameraTransform() -> BodyToCameraTransform {
        BodyToCameraTransform(
            rotation: simd_quatf(
                angle: 0, axis: SIMD3<Float>(0, 1, 0)
            ),
            translation: SIMD3<Float>(0, 0, 3)
        )
    }

    private func referenceFrame(_ timestamp: Int) -> PoseSnapshot {
        var world = Array(repeating: PoseWorldPoint(
            x: 0, y: 0, z: 0, visibility: 0.99
        ), count: 33)
        func set(_ i: Int, _ x: Float, _ y: Float) {
            world[i] = PoseWorldPoint(
                x: x, y: y, z: 0, visibility: 0.99
            )
        }
        set(11, -0.20, 0.50)
        set(12, 0.20, 0.50)
        set(13, -0.40, 0.20)
        set(14, 0.40, 0.20)
        set(15, -0.55, -0.10)
        set(23, -0.15, 0)
        set(24, 0.15, 0)
        set(25, -0.15, -0.35)
        set(26, 0.15, -0.35)

        let pixels: [PosePoint] = world.map { p in
            let projected = BodyCameraProjection.project(
                bodyWorld: SIMD3(p.x, p.y, p.z),
                camera: intrinsics(), bodyToCamera: cameraTransform()
            )!
            return PosePoint(
                x: CGFloat(projected.normalizedX),
                y: CGFloat(projected.normalizedY),
                visibility: 0.99
            )
        }
        return PoseSnapshot(
            timestampMilliseconds: timestamp,
            imageSize: CGSize(width: 720, height: 1280),
            points: pixels, worldPoints: world,
            cameraIntrinsics: intrinsics()
        )
    }

    private func bindings() -> [AnatomyAtlasManifest.BoneBinding] {
        let segments: [
            (id: String, path: String, parent: String?,
             from: Int, to: Int, a: [Float], b: [Float])
        ] = [
            ("left-upper", "arm/left-upper", nil,
             11, 13, [-0.20, 0.50, 0], [-0.40, 0.20, 0]),
            ("left-lower", "arm/left-lower", "left-upper",
             13, 15, [-0.40, 0.20, 0], [-0.55, -0.10, 0]),
            ("right-upper", "arm/right-upper", nil,
             12, 14, [0.20, 0.50, 0], [0.40, 0.20, 0]),
            ("left-thigh", "leg/left-thigh", nil,
             23, 25, [-0.15, 0, 0], [-0.15, -0.35, 0]),
            ("right-thigh", "leg/right-thigh", nil,
             24, 26, [0.15, 0, 0], [0.15, -0.35, 0])
        ]
        return segments.map { s in
            AnatomyAtlasManifest.BoneBinding(
                id: s.id, nodePath: s.path, parentId: s.parent,
                proximalLandmark: s.from, distalLandmark: s.to,
                restStart: s.a, restEnd: s.b, anchorsReviewed: true
            )
        }
    }

    private func resources(
        brokenPath: Bool = false,
        brokenRevision: Bool = false,
        mismatchedAnchor: Bool = false
    ) -> ReviewedAtlasRuntimeResources? {
        let bones = bindings()
        let manifest = AnatomyAtlasManifest(
            atlasId: "synthetic-not-real",
            sourceURL: "test://fixture",
            sourceRevision: "fixture-revision",
            attribution: "synthetic test vertices only",
            licenseIdentifier: "fixture",
            assetFilename: "fixture.usdz",
            assetSHA256: String(repeating: "a", count: 64),
            licenseReviewed: true, anatomyReviewed: true,
            bones: bones
        )
        var parts: [MobileAtlasBinding] = []
        var vertices: [AtlasRestVertex] = []
        for (index, bone) in bones.enumerated() {
            let a = bone.restStartPoint!
            let b = bone.restEndPoint!
            let path = brokenPath && index == 0
                ? "unreviewed/not-the-same" : bone.nodePath
            let start: [Float] = (mismatchedAnchor && index == 0)
                ? [5, 5, 5] : bone.restStart
            parts.append(MobileAtlasBinding(
                sourceHierarchyPath: path,
                displayName: "Synthetic volume",
                group: index < 3 ? "arms" : "legs",
                fromLandmark: bone.proximalLandmark,
                toLandmark: bone.distalLandmark,
                restFrom: start, restTo: bone.restEnd,
                vertexOffset: index * 3, vertexCount: 3
            ))
            let guide = SIMD3<Float>(0.04, 0.02, 0)
            for position in [a, b, a + guide] {
                vertices.append(AtlasRestVertex(
                    position: position, normal: SIMD3(0, 0, 1)
                ))
            }
        }
        let mobile = MobileAtlasManifest(
            schemaVersion: 1,
            sourceRepository: "synthetic://fixture",
            sourceRevision: brokenRevision
                ? "wrong-revision" : "fixture-revision",
            sourcePath: "fixture",
            modelFile: "skeleton_atlas.mmgeom",
            modelSHA256: String(repeating: "a", count: 64),
            licenseIds: [], attribution: [],
            modificationNotes: ["XCTest only"],
            reviewedForDistribution: true,
            reviewedJointBindings: true, parts: parts
        )
        let atlas = VerifiedAnatomyAtlas(
            manifest: mobile, vertices: vertices
        )
        return ReviewedAtlasRuntimeResources(
            mesh: atlas, hierarchy: manifest
        )
    }

    private func reviewedCamera(
        _ frame: PoseSnapshot,
        approved: Bool = true,
        timestamp: Int? = nil
    ) -> ReviewedSourceCameraFrame {
        ReviewedSourceCameraFrame(
            timestampMilliseconds: timestamp ?? frame.timestampMilliseconds,
            imageSize: frame.imageSize,
            intrinsics: intrinsics(),
            bodyToCamera: cameraTransform(),
            independentReviewConfirmed: approved
        )
    }

    func testFullCaptureToRigProjectionProducesMatchingMetalTriangles() {
        let context = resources()
        XCTAssertNotNil(context)
        let runtime = LiveReviewedAtlasRuntime(resources: context!)
        for i in 0..<11 {
            let frame = referenceFrame(1000 + i * 33)
            XCTAssertNil(runtime.render(
                frame: frame, reviewedCamera: reviewedCamera(frame),
                viewport: viewport, focus: .full, opacity: 0.7
            ))
        }
        let frame = referenceFrame(1363)
        let batch = runtime.render(
            frame: frame, reviewedCamera: reviewedCamera(frame),
            viewport: viewport, focus: .full, opacity: 0.7
        )
        XCTAssertNotNil(batch)
        XCTAssertEqual(batch?.vertices.count, 15)
        XCTAssertTrue(batch!.matches(
            frame: frame, viewport: viewport,
            focus: .full, opacity: 0.7
        ))

        let nextFrame = referenceFrame(1396)
        let arms = runtime.render(
            frame: nextFrame, reviewedCamera: reviewedCamera(nextFrame),
            viewport: viewport, focus: .arms, opacity: 0.7
        )
        XCTAssertEqual(arms?.vertices.count, 9)
        XCTAssertEqual(arms?.sourceTimestampMilliseconds, 1396)
    }

    func testNoUnreviewedCameraOrMissingIntrinsicsCanRenderAtlas() {
        let runtime = LiveReviewedAtlasRuntime(resources: resources()!)
        for i in 0..<12 {
            let f = referenceFrame(1000 + i * 33)
            XCTAssertNil(runtime.render(
                frame: f, reviewedCamera: reviewedCamera(f, approved: false),
                viewport: viewport, focus: .full, opacity: 0.7
            ))
        }
        let f = referenceFrame(1396)
        XCTAssertNil(runtime.render(
            frame: f, reviewedCamera: reviewedCamera(f, timestamp: 1000),
            viewport: viewport, focus: .full, opacity: 0.7
        ))
        let g = referenceFrame(1429)
        XCTAssertNil(runtime.render(
            frame: g, reviewedCamera: nil,
            viewport: viewport, focus: .full, opacity: 0.7
        ))

        let noIntrinsic = PoseSnapshot(
            timestampMilliseconds: 1462,
            imageSize: g.imageSize, points: g.points,
            worldPoints: g.worldPoints
        )
        XCTAssertNil(runtime.render(
            frame: noIntrinsic,
            reviewedCamera: reviewedCamera(noIntrinsic),
            viewport: viewport, focus: .full, opacity: 0.7
        ))
    }

    func testSourceChangeDropoutAndReplayResetFrozenAtlasReference() {
        let runtime = LiveReviewedAtlasRuntime(resources: resources()!)
        for i in 0..<12 {
            let f = referenceFrame(1000 + i * 33)
            _ = runtime.render(
                frame: f, reviewedCamera: reviewedCamera(f),
                viewport: viewport, focus: .full, opacity: 0.7
            )
        }
        let duplicate = referenceFrame(1363)
        XCTAssertNil(runtime.render(
            frame: duplicate, reviewedCamera: reviewedCamera(duplicate),
            viewport: viewport, focus: .full, opacity: 0.7
        ))
        XCTAssertNil(runtime.render(
            frame: nil, reviewedCamera: nil,
            viewport: viewport, focus: .full, opacity: 0.7
        ))
        let next = referenceFrame(2000)
        XCTAssertNil(runtime.render(
            frame: next, reviewedCamera: reviewedCamera(next),
            viewport: viewport, focus: .full, opacity: 0.7
        ))
    }

    func testRejectsDisconnectedAndMismatchedResourcePackages() {
        XCTAssertNotNil(resources())
        XCTAssertNil(resources(brokenPath: true))
        XCTAssertNil(resources(brokenRevision: true))
        // The resource container validates anchor consistency within
        // hierarchy; per-part mesh anchor parity is rechecked by
        // CoherentAtlasMeshProjection before any triangle can draw.
        let badMeshAnchors = resources(mismatchedAnchor: true)
        XCTAssertNotNil(badMeshAnchors)
        let runtime = LiveReviewedAtlasRuntime(resources: badMeshAnchors!)
        var last: CalibratedAtlasDrawBatch?
        for i in 0..<12 {
            let f = referenceFrame(1000 + i * 33)
            last = runtime.render(
                frame: f, reviewedCamera: reviewedCamera(f),
                viewport: viewport, focus: .full, opacity: 0.7
            )
        }
        XCTAssertNil(last)
    }

    func testReviewedFourWeightSkinningUsesGPUPathAfterReferenceCapture() {
        let base = resources()!
        let bones = base.hierarchy.bones
        var vertexRecords: [ReviewedAtlasSkinningFile.Vertex] = []
        for part in base.mesh.manifest.parts {
            let id = bones.first {
                $0.nodePath == part.sourceHierarchyPath
            }!.id
            for _ in 0..<part.vertexCount {
                vertexRecords.append(ReviewedAtlasSkinningFile.Vertex(
                    boneIds: [id, id, id, id],
                    weights: [0.7, 0.3, 0, 0]
                ))
            }
        }
        let candidate = ReviewedAtlasSkinningFile(
            schemaVersion: 1,
            sourceRevision: base.mesh.manifest.sourceRevision,
            modelSHA256: base.mesh.manifest.modelSHA256,
            reviewedJointWeights: true,
            vertices: vertexRecords
        )
        let influences = try? AtlasSkinningPackage.validate(
            candidate, atlas: base.mesh, hierarchy: base.hierarchy
        )
        XCTAssertEqual(influences?.count, base.mesh.vertices.count)
        let resources = ReviewedAtlasRuntimeResources(
            mesh: base.mesh,
            hierarchy: base.hierarchy,
            skinning: influences
        )
        XCTAssertNotNil(resources)
        let live = LiveReviewedAtlasRuntime(resources: resources!)
        for index in 0..<11 {
            let sample = referenceFrame(1000 + index * 33)
            XCTAssertNil(live.render(
                frame: sample, reviewedCamera: reviewedCamera(sample),
                viewport: viewport, focus: .arms, opacity: 0.7
            ))
        }
        let sample = referenceFrame(1363)
        // The GPU path replaces the CPU-projected rigid atlas, and
        // both remain source-frame and viewport bound.
        XCTAssertNil(live.render(
            frame: sample, reviewedCamera: reviewedCamera(sample),
            viewport: viewport, focus: .arms, opacity: 0.7
        ))
        let gpu = live.skinnedFrame
        XCTAssertNotNil(gpu)
        XCTAssertEqual(gpu?.vertices.count, 9)
        XCTAssertEqual(gpu?.cameraMatrices.count, bones.count)
        XCTAssertTrue(gpu!.matches(
            frame: sample, viewport: viewport,
            focus: .arms, opacity: 0.7
        ))
        XCTAssertFalse(gpu!.matches(
            frame: referenceFrame(1396), viewport: viewport,
            focus: .arms, opacity: 0.7
        ))
        XCTAssertEqual(MemoryLayout<SkinnedAtlasVertex>.stride, 80)
        let worldPoint = base.mesh.vertices[0].position
        let gpuPoint = gpu!.cameraMatrices[0] * SIMD4<Float>(
            worldPoint.x, worldPoint.y, worldPoint.z, 1
        )
        let cameraPoint = BodyCameraProjection.project(
            bodyWorld: worldPoint, camera: intrinsics(),
            bodyToCamera: cameraTransform()
        )
        XCTAssertNotNil(cameraPoint)
        XCTAssertEqual(gpuPoint.z, 3, accuracy: 0.001)
        // Changing opacity must not rebuild immutable rest vertices;
        // only the per-frame Metal uniform changes.
        let following = referenceFrame(1396)
        _ = live.render(
            frame: following, reviewedCamera: reviewedCamera(following),
            viewport: viewport, focus: .arms, opacity: 0.2
        )
        let next = live.skinnedFrame
        XCTAssertNotNil(next)
        XCTAssertEqual(next?.geometryIdentity, gpu?.geometryIdentity)
        XCTAssertEqual(next?.vertices.count, gpu?.vertices.count)
        XCTAssertEqual(next?.opacity, 0.2)
        XCTAssertEqual(next?.vertices.first?.color.w, 1)
        XCTAssertEqual(gpu?.vertices.first?.color.w, 1)
        live.reset()
        XCTAssertNil(live.skinnedFrame)
    }

    func testInvalidSkinningHashesWeightsAndUnknownBonesFailClosed() {
        let base = resources()!
        let index = SIMD4<UInt32>(repeating: 0)
        let good = AtlasSkinInfluence(
            joints: index, weights: SIMD4<Float>(1, 0, 0, 0)
        )
        XCTAssertTrue(good.isValid(boneCount: base.hierarchy.bones.count))
        XCTAssertFalse(AtlasSkinInfluence(
            joints: index, weights: SIMD4<Float>(0.4, 0.4, 0, 0)
        ).isValid(boneCount: base.hierarchy.bones.count))
        XCTAssertFalse(AtlasSkinInfluence(
            joints: index, weights: SIMD4<Float>(.nan, 0, 0, 0)
        ).isValid(boneCount: base.hierarchy.bones.count))
        XCTAssertFalse(AtlasSkinInfluence(
            joints: SIMD4<UInt32>(99, 0, 0, 0),
            weights: SIMD4<Float>(1, 0, 0, 0)
        ).isValid(boneCount: base.hierarchy.bones.count))

        let vertices = (0..<base.mesh.vertices.count).map { _ in
            ReviewedAtlasSkinningFile.Vertex(
                boneIds: ["unknown", "unknown", "unknown", "unknown"],
                weights: [1, 0, 0, 0]
            )
        }
        let invalid = ReviewedAtlasSkinningFile(
            schemaVersion: 1,
            sourceRevision: base.mesh.manifest.sourceRevision,
            modelSHA256: "unmatched",
            reviewedJointWeights: true,
            vertices: vertices
        )
        XCTAssertThrowsError(try AtlasSkinningPackage.validate(
            invalid, atlas: base.mesh, hierarchy: base.hierarchy
        ))
        let badID = ReviewedAtlasSkinningFile(
            schemaVersion: 1,
            sourceRevision: base.mesh.manifest.sourceRevision,
            modelSHA256: base.mesh.manifest.modelSHA256,
            reviewedJointWeights: true,
            vertices: vertices
        )
        XCTAssertThrowsError(try AtlasSkinningPackage.validate(
            badID, atlas: base.mesh, hierarchy: base.hierarchy
        ))
        XCTAssertNil(ReviewedAtlasRuntimeResources(
            mesh: base.mesh, hierarchy: base.hierarchy,
            skinning: [good]
        ))
    }
}

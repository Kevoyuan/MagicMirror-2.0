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
}

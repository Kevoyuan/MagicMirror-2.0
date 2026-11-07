import CoreGraphics
import simd
import XCTest
@testable import MagicMirror

/// All positions are constructed rest-mesh triangles with one synthetic
/// 3D camera, not a real human or an independently approved atlas.
final class ReviewedAtlasHitTesterTests: XCTestCase {
    private let viewport = CGSize(width: 100, height: 100)

    private func vertex(
        _ x: Float, _ y: Float, _ z: Float
    ) -> SkinnedAtlasVertex {
        SkinnedAtlasVertex(
            position: SIMD4<Float>(x, y, z, 1),
            normal: SIMD4<Float>(0, 0, 1, 0),
            color: SIMD4<Float>(1, 1, 1, 1),
            joints: SIMD4<UInt32>(0, 0, 0, 0),
            weights: SIMD4<Float>(1, 0, 0, 0)
        )
    }

    private func batch(
        section: SIMD4<Float> = SIMD4<Float>(repeating: 0),
        twoParts: Bool = false
    ) -> SkinnedAtlasDrawBatch {
        let close = [
            vertex(-0.2, -0.2, 0),
            vertex(0.2, -0.2, 0),
            vertex(0, 0.2, 0)
        ]
        let far = [
            vertex(-0.3, -0.3, 1),
            vertex(0.3, -0.3, 1),
            vertex(0, 0.3, 1)
        ]
        var transform = matrix_identity_float4x4
        transform.columns.3 = SIMD4<Float>(0, 0, 2, 1)
        let rendered = [
            AtlasRenderedPart(
                sourceHierarchyPath: "reviewed/arm/humerus",
                displayName: "Reference humerus",
                vertexStart: 0, vertexCount: 3
            )
        ]
        let farPart = AtlasRenderedPart(
            sourceHierarchyPath: "reviewed/arm/radius",
            displayName: "Reference radius",
            vertexStart: 3, vertexCount: 3
        )
        return SkinnedAtlasDrawBatch(
            sourceTimestampMilliseconds: 1000,
            sourceImageSize: viewport,
            viewportSize: viewport,
            sourceRevision: "reviewed-fixture-only",
            geometryIdentity: UUID(),
            focus: .full,
            opacity: 0.7,
            vertices: twoParts ? close + far : close,
            renderedParts: twoParts ? rendered + [farPart] : rendered,
            cameraMatrices: [transform],
            cameraParameters: SIMD4<Float>(100, 100, 50, 50),
            viewportParameters: SIMD4<Float>(1, 0, 0, 0),
            sectionPlane: section
        )
    }

    func testSelectsActualSourceNodeAtPerspectiveTriangleTap() {
        let result = ReviewedAtlasHitTester.select(
            at: CGPoint(x: 50, y: 47),
            batch: batch(), system: .skeleton
        )
        XCTAssertEqual(result?.displayName, "Reference humerus")
        XCTAssertEqual(
            result?.sourceHierarchyPath, "reviewed/arm/humerus"
        )
        XCTAssertEqual(result?.system, .skeleton)
        XCTAssertEqual(result?.sourceRevision, "reviewed-fixture-only")
        XCTAssertTrue(result!.detail.contains("cannot measure"))
    }

    func testClosest3DSurfaceWinsOverOverlappingFarMesh() {
        let result = ReviewedAtlasHitTester.select(
            at: CGPoint(x: 50, y: 47),
            batch: batch(twoParts: true),
            system: .skeleton
        )
        XCTAssertEqual(result?.displayName, "Reference humerus")
    }

    func test3DCutRejectsClippedSurfaceAtTap() {
        let cut = SIMD4<Float>(0, 1, 0, -0.3)
        XCTAssertNil(ReviewedAtlasHitTester.select(
            at: CGPoint(x: 50, y: 47),
            batch: batch(section: cut), system: .skeleton
        ))
    }

    func testNeverLabelsProxyOrOffscreenOrEmptySpaceAsRealAnatomy() {
        XCTAssertNil(ReviewedAtlasHitTester.select(
            at: CGPoint(x: 50, y: 47),
            batch: batch(), system: .referenceProxy
        ))
        XCTAssertNil(ReviewedAtlasHitTester.select(
            at: CGPoint(x: -10, y: 48),
            batch: batch(), system: .skeleton
        ))
        XCTAssertNil(ReviewedAtlasHitTester.select(
            at: CGPoint(x: 9, y: 90),
            batch: batch(), system: .skeleton
        ))
    }
}

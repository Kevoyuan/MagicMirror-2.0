import CoreGraphics
import XCTest
@testable import MagicMirror

final class VolumetricBoneMeshTests: XCTestCase {
    private func snapshot(includeWorld: Bool = true) -> PoseSnapshot {
        var points = Array(
            repeating: PosePoint(x: 0.5, y: 0.5, visibility: 0.99),
            count: 33
        )
        points[11] = PosePoint(x: 0.37, y: 0.32, visibility: 0.99)
        points[12] = PosePoint(x: 0.63, y: 0.32, visibility: 0.99)
        points[13] = PosePoint(x: 0.25, y: 0.45, visibility: 0.99)
        points[14] = PosePoint(x: 0.75, y: 0.45, visibility: 0.99)
        points[15] = PosePoint(x: 0.2, y: 0.6, visibility: 0.99)
        points[16] = PosePoint(x: 0.8, y: 0.6, visibility: 0.99)
        points[23] = PosePoint(x: 0.42, y: 0.62, visibility: 0.99)
        points[24] = PosePoint(x: 0.58, y: 0.62, visibility: 0.99)
        points[25] = PosePoint(x: 0.4, y: 0.78, visibility: 0.99)
        points[26] = PosePoint(x: 0.6, y: 0.78, visibility: 0.99)
        points[27] = PosePoint(x: 0.38, y: 0.91, visibility: 0.99)
        points[28] = PosePoint(x: 0.62, y: 0.91, visibility: 0.99)
        points[31] = PosePoint(x: 0.37, y: 0.94, visibility: 0.99)
        points[32] = PosePoint(x: 0.63, y: 0.94, visibility: 0.99)
        let world = Array(
            repeating: PoseWorldPoint(
                x: 0, y: 0, z: 0.14, visibility: 0.98
            ),
            count: 33
        )
        return PoseSnapshot(
            timestampMilliseconds: 1000,
            imageSize: CGSize(width: 720, height: 1280),
            points: points,
            worldPoints: includeWorld ? world : []
        )
    }

    func testBuildsActual3DTrianglesFromVisiblePerson() {
        let mesh = VolumetricBoneMesh.make(
            snapshot: snapshot(),
            viewport: CGSize(width: 390, height: 844),
            opacity: 0.7
        )
        XCTAssertGreaterThan(mesh.count, 300)
        XCTAssertEqual(mesh.count % 3, 0)
        XCTAssertTrue(mesh.allSatisfy {
            $0.position.x.isFinite && $0.position.y.isFinite &&
            $0.position.z.isFinite && $0.normal.x.isFinite &&
            $0.normal.y.isFinite && $0.normal.z.isFinite
        })
        XCTAssertTrue(mesh.allSatisfy {
            $0.color.w > 0 && $0.color.w <= 1
        })
    }

    func testLossAndOpacityZeroProduceNoGeometry() {
        let size = CGSize(width: 390, height: 844)
        XCTAssertTrue(VolumetricBoneMesh.make(
            snapshot: nil, viewport: size, opacity: 0.5
        ).isEmpty)
        XCTAssertTrue(VolumetricBoneMesh.make(
            snapshot: snapshot(), viewport: size, opacity: 0
        ).isEmpty)
    }

    func testMissingWorldEstimateDoesNotInventMeasuredDepth() {
        let noDepth = snapshot(includeWorld: false)
        let p = VolumetricBoneMesh.sourcePoint(
            index: 11, snapshot: noDepth,
            viewport: CGSize(width: 390, height: 844)
        )
        XCTAssertNotNil(p)
        XCTAssertEqual(p!.z, 0, accuracy: 0.001)
    }

    func testMissingJointConfidenceSkipsUntrustedSegment() {
        let original = snapshot()
        var joints = original.points
        joints[13] = PosePoint(x: 0.25, y: 0.45, visibility: 0.01)
        let invalid = PoseSnapshot(
            timestampMilliseconds: 1010, imageSize: original.imageSize,
            points: joints, worldPoints: original.worldPoints
        )
        let size = CGSize(width: 390, height: 844)
        let withoutElbow = VolumetricBoneMesh.make(
            snapshot: invalid, viewport: size, opacity: 0.7
        )
        let all = VolumetricBoneMesh.make(
            snapshot: original, viewport: size, opacity: 0.7
        )
        XCTAssertLessThan(withoutElbow.count, all.count)
    }

    func testOutOfFrameAndNonfiniteAreRejected() {
        let source = snapshot()
        var points = source.points
        points[11] = PosePoint(
            x: .nan, y: 0.4, visibility: 0.99
        )
        let bad = PoseSnapshot(
            timestampMilliseconds: 1010, imageSize: source.imageSize,
            points: points
        )
        XCTAssertTrue(VolumetricBoneMesh.make(
            snapshot: bad,
            viewport: CGSize(width: 390, height: 844), opacity: 0.7
        ).isEmpty)
    }

    @MainActor
    func testTemporalFilterFollowsMotionAndResetsOnDropout() {
        var filter = PoseTemporalFilter()
        let old = snapshot()
        let first = filter.apply(old)
        XCTAssertEqual(first?.timestampMilliseconds, 1000)
        var changed = old.points
        changed[15] = PosePoint(
            x: 0.4, y: 0.6, visibility: 0.99
        )
        let moved = PoseSnapshot(
            timestampMilliseconds: 1033, imageSize: old.imageSize,
            points: changed, worldPoints: old.worldPoints
        )
        let filtered = filter.apply(moved)
        XCTAssertNotNil(filtered)
        XCTAssertGreaterThan(filtered!.points[15].x, old.points[15].x)
        XCTAssertLessThan(filtered!.points[15].x, changed[15].x)
        XCTAssertNil(filter.apply(nil))
        XCTAssertEqual(filter.apply(moved)?.points[15].x, changed[15].x)
    }
}

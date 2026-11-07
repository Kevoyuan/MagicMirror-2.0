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

    func testNonfiniteJointHidesOnlyItsSegments() {
        let source = snapshot()
        var points = source.points
        points[11] = PosePoint(
            x: .nan, y: 0.4, visibility: 0.99
        )
        let partial = PoseSnapshot(
            timestampMilliseconds: 1010, imageSize: source.imageSize,
            points: points
        )
        XCTAssertEqual(partial.coverage, .partial)
        let size = CGSize(width: 390, height: 844)
        let partialMesh = VolumetricBoneMesh.make(
            snapshot: partial, viewport: size, opacity: 0.7
        )
        let fullMesh = VolumetricBoneMesh.make(
            snapshot: source, viewport: size, opacity: 0.7
        )
        XCTAssertFalse(partialMesh.isEmpty)
        XCTAssertLessThan(partialMesh.count, fullMesh.count)
        XCTAssertNil(VolumetricBoneMesh.sourcePoint(
            index: 11, snapshot: partial, viewport: size
        ))
    }

    func testSingleObservedArmDrawsNoUnseenTorsoOrLegs() {
        let source = snapshot()
        var points = source.points.map {
            PosePoint(x: $0.x, y: $0.y, visibility: 0.1)
        }
        for index in [11, 13, 15] {
            points[index] = source.points[index]
        }
        let partial = PoseSnapshot(
            timestampMilliseconds: 1010, imageSize: source.imageSize,
            points: points, worldPoints: source.worldPoints
        )
        XCTAssertTrue(partial.isUsable)
        XCTAssertFalse(partial.hasTorsoAnchor)
        let size = CGSize(width: 390, height: 844)
        let whole = VolumetricBoneMesh.make(
            snapshot: partial, viewport: size, opacity: 0.7, focus: .full
        )
        let arms = VolumetricBoneMesh.make(
            snapshot: partial, viewport: size, opacity: 0.7, focus: .arms
        )
        let legs = VolumetricBoneMesh.make(
            snapshot: partial, viewport: size, opacity: 0.7, focus: .legs
        )
        XCTAssertGreaterThan(whole.count, 0)
        XCTAssertEqual(whole.count, arms.count)
        XCTAssertTrue(legs.isEmpty)
    }

    func testFullReferenceShowsRibCageAndPelvisButFocusIsSelective() {
        let s = snapshot()
        let size = CGSize(width: 390, height: 844)
        let full = VolumetricBoneMesh.make(
            snapshot: s, viewport: size, opacity: 0.7, focus: .full
        )
        let arms = VolumetricBoneMesh.make(
            snapshot: s, viewport: size, opacity: 0.7, focus: .arms
        )
        let legs = VolumetricBoneMesh.make(
            snapshot: s, viewport: size, opacity: 0.7, focus: .legs
        )
        // Educational ribs and pelvic arcs are present only in whole-body.
        XCTAssertGreaterThan(full.count, arms.count + legs.count + 1500)
        XCTAssertEqual(full.count % 3, 0)
        XCTAssertEqual(arms.count % 3, 0)
        XCTAssertEqual(legs.count % 3, 0)
        XCTAssertTrue(full.allSatisfy {
            $0.position.x.isFinite &&
            $0.position.y.isFinite &&
            $0.position.z.isFinite &&
            $0.normal.x.isFinite &&
            $0.normal.y.isFinite &&
            $0.normal.z.isFinite
        })
    }

    func testReferenceCraniumRequiresBothConfidentEarLandmarks() {
        let original = snapshot()
        var points = original.points
        points[7] = PosePoint(x: 0.44, y: 0.17, visibility: 0.98)
        points[8] = PosePoint(x: 0.56, y: 0.17, visibility: 0.98)
        let withEars = PoseSnapshot(
            timestampMilliseconds: 1001,
            imageSize: original.imageSize,
            points: points, worldPoints: original.worldPoints
        )
        points[8] = PosePoint(x: 0.56, y: 0.17, visibility: 0.1)
        let withoutBothEars = PoseSnapshot(
            timestampMilliseconds: 1002,
            imageSize: original.imageSize,
            points: points, worldPoints: original.worldPoints
        )
        let size = CGSize(width: 390, height: 844)
        let fullCranium = VolumetricBoneMesh.make(
            snapshot: withEars, viewport: size, opacity: 0.7
        )
        let hiddenCranium = VolumetricBoneMesh.make(
            snapshot: withoutBothEars, viewport: size, opacity: 0.7
        )
        XCTAssertGreaterThan(fullCranium.count, hiddenCranium.count + 500)
        XCTAssertEqual(fullCranium.count % 3, 0)
        XCTAssertTrue(fullCranium.allSatisfy {
            $0.color.x.isFinite && $0.color.w > 0 &&
            $0.color.w <= 1
        })
    }

    @MainActor
    func testTemporalFilterKeepsPartialPoseAndFreshIntrinsics() {
        var filter = PoseTemporalFilter()
        let source = snapshot()
        var points = source.points.map {
            PosePoint(x: $0.x, y: $0.y, visibility: 0.1)
        }
        for index in [11, 13, 15, 12, 14] {
            points[index] = source.points[index]
        }
        let first = PoseSnapshot(
            timestampMilliseconds: 1000, imageSize: source.imageSize,
            points: points
        )
        XCTAssertEqual(filter.apply(first)?.coverage, .partial)

        points[13] = PosePoint(
            x: 0.25, y: 0.45, visibility: 0.1
        )
        points[14] = PosePoint(
            x: 0.8, y: 0.45, visibility: 0.98
        )
        let intrinsics = BodyCameraIntrinsics(
            fx: 700, fy: 700, cx: 360, cy: 640,
            width: 720, height: 1280
        )
        let second = PoseSnapshot(
            timestampMilliseconds: 1033, imageSize: source.imageSize,
            points: points, cameraIntrinsics: intrinsics
        )
        let filtered = filter.apply(second)
        XCTAssertEqual(filtered?.coverage, .partial)
        XCTAssertFalse(filtered!.points[13].isUsable)
        XCTAssertEqual(filtered?.cameraIntrinsics?.fx, 700)
        XCTAssertTrue(filtered!.points[14].isUsable)
        XCTAssertGreaterThan(filtered!.points[14].x, first.points[14].x)
        XCTAssertLessThan(filtered!.points[14].x, points[14].x)
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

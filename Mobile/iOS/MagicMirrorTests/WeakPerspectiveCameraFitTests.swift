import CoreGraphics
import XCTest
import simd
@testable import MagicMirror

final class WeakPerspectiveCameraFitTests: XCTestCase {
    private let ids = [0,7,8,11,12,13,14,15,16,23,24,25,26,27,28]

    private func syntheticPose() -> PoseSnapshot {
        var image = Array(
            repeating: PosePoint(x: 0.5, y: 0.5, visibility: 0.99),
            count: 33
        )
        var world = Array(
            repeating: PoseWorldPoint(
                x: 0, y: 0, z: 0, visibility: 0.99
            ), count: 33
        )
        for (order, id) in ids.enumerated() {
            let x = Float(order % 5) * 0.15 - 0.3
            let y = Float(order / 5) * 0.19 - 0.3
            let z = Float((order * 3) % 7) * 0.06 - 0.18
            world[id] = PoseWorldPoint(
                x: x, y: y, z: z, visibility: 0.99
            )
            // Equal-scale orthographic reference, 720×1280 source frame.
            image[id] = PosePoint(
                x: CGFloat((360 + 420 * x) / 720),
                y: CGFloat((640 + 420 * y) / 1280),
                visibility: 0.99
            )
        }
        return PoseSnapshot(
            timestampMilliseconds: 1000,
            imageSize: CGSize(width: 720, height: 1280),
            points: image, worldPoints: world
        )
    }

    func testRecoversProjectedVisibleJointsWithinOnePixel() {
        let snapshot = syntheticPose()
        let fit = WeakPerspectiveCameraFit.estimate(snapshot: snapshot)
        XCTAssertNotNil(fit)
        XCTAssertGreaterThanOrEqual(fit!.inlierCount, 10)
        XCTAssertLessThan(fit!.p90ResidualPixels, 1)
        for id in ids {
            let w = snapshot.worldPoints[id]
            let result = fit!.imagePixel(for: SIMD3(w.x, w.y, w.z))
            XCTAssertNotNil(result)
            XCTAssertEqual(
                result!.x, Float(snapshot.points[id].x) * 720,
                accuracy: 1
            )
            XCTAssertEqual(
                result!.y, Float(snapshot.points[id].y) * 1280,
                accuracy: 1
            )
        }
    }

    func testAspectFillMapPreservesSourceImageCenter() {
        let snapshot = syntheticPose()
        let fit = WeakPerspectiveCameraFit.estimate(snapshot: snapshot)!
        let center = fit.screenPixel(
            for: SIMD3<Float>(0, 0, 0),
            sourceImageSize: snapshot.imageSize,
            viewport: CGSize(width: 390, height: 844)
        )
        XCTAssertNotNil(center)
        XCTAssertEqual(center!.x, 195, accuracy: 2)
        XCTAssertEqual(center!.y, 422, accuracy: 2)
    }

    func testAbsentOrUnreviewableWorldPoseFailsClosed() {
        let source = syntheticPose()
        let missing = PoseSnapshot(
            timestampMilliseconds: 1001,
            imageSize: source.imageSize,
            points: source.points
        )
        XCTAssertNil(WeakPerspectiveCameraFit.estimate(snapshot: missing))
        var poor = source.worldPoints
        for id in ids { poor[id] = PoseWorldPoint(
            x: .nan, y: 0, z: 0, visibility: 0.2
        ) }
        let invalid = PoseSnapshot(
            timestampMilliseconds: 1002,
            imageSize: source.imageSize,
            points: source.points, worldPoints: poor
        )
        XCTAssertNil(WeakPerspectiveCameraFit.estimate(snapshot: invalid))
    }

    func testRejectsImplausiblyNoisyImageCorrespondences() {
        let source = syntheticPose()
        var corrupted = source.points
        for (i, id) in ids.enumerated() {
            let original = corrupted[id]
            corrupted[id] = PosePoint(
                x: CGFloat((i % 2 == 0) ? 0.03 : 0.94),
                y: original.y, visibility: 0.99
            )
        }
        let invalid = PoseSnapshot(
            timestampMilliseconds: 1003, imageSize: source.imageSize,
            points: corrupted, worldPoints: source.worldPoints
        )
        XCTAssertNil(WeakPerspectiveCameraFit.estimate(
            snapshot: invalid, maxP90FractionOfImageWidth: 0.015
        ))
    }
}

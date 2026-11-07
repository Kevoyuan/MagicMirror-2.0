import CoreGraphics
import simd
import XCTest
@testable import MagicMirror

/// Constructed 3D points and camera pixels; no real human anatomy/phone.
@MainActor
final class LiveProxyRigRetargeterTests: XCTestCase {
    private let size = CGSize(width: 720, height: 1280)

    private func frame(
        timestamp: Int,
        armBent: Bool = false,
        imageSize: CGSize = CGSize(width: 720, height: 1280),
        visibleHips: Bool = true
    ) -> PoseSnapshot {
        var world: [PoseWorldPoint] = []
        world.reserveCapacity(33)
        for index in 0..<33 {
            let x: Float = Float(index % 6) * 0.038 - 0.10
            let y: Float = Float(index / 6) * 0.055 - 0.12
            let z: Float = Float(index % 3) * 0.005
            world.append(PoseWorldPoint(
                x: x, y: y, z: z, visibility: 0.98
            ))
        }
        func set(_ i: Int, _ x: Float, _ y: Float, _ z: Float = 0) {
            world[i] = PoseWorldPoint(
                x: x, y: y, z: z, visibility: 0.98
            )
        }
        set(11, -0.24, 0.52)
        set(12,  0.24, 0.52)
        set(13, armBent ? -0.47 : -0.43,
                armBent ? 0.27 : 0.25, 0.02)
        set(15, armBent ? -0.56 : -0.62,
                armBent ? -0.02 : -0.05, 0.02)
        set(14,  0.43, 0.25, 0.02)
        set(16,  0.62, -0.05, 0.02)
        set(23, -0.18, -0.04)
        set(24,  0.18, -0.04)
        set(25, -0.20, -0.45)
        set(26,  0.20, -0.45)
        set(27, -0.21, -0.86)
        set(28,  0.21, -0.86)
        set(0, 0, 0.79)
        set(7, -0.13, 0.69)
        set(8, 0.13, 0.69)

        var points: [PosePoint] = []
        points.reserveCapacity(33)
        let width: Float = Float(imageSize.width)
        let height: Float = Float(imageSize.height)
        for index in 0..<world.count {
            let point = world[index]
            let normalizedX: Float = (width * 0.5 + 300 * point.x) / width
            let normalizedY: Float = (height * 0.5 + 300 * point.y) / height
            let obscuredHip = !visibleHips && (index == 23 || index == 24)
            let visibility: Float = obscuredHip ? 0.1 : 0.98
            points.append(PosePoint(
                x: CGFloat(normalizedX),
                y: CGFloat(normalizedY),
                visibility: visibility
            ))
        }
        return PoseSnapshot(
            timestampMilliseconds: timestamp,
            imageSize: imageSize, points: points, worldPoints: world
        )
    }

    private func acquire(
        _ rig: inout LiveProxyRigRetargeter,
        from firstTimestamp: Int = 1000
    ) {
        for i in 0..<11 {
            XCTAssertNil(rig.update(frame(
                timestamp: firstTimestamp + 33 * i
            )))
        }
        // The twelfth stable camera frame captures a frozen world
        // reference; a live IK proxy may become eligible immediately.
        let result = rig.update(frame(
            timestamp: firstTimestamp + 33 * 11
        ))
        XCTAssertNotNil(result)
    }

    func testLiveRetargetingUsesFrozenLengthsAndMatchingSourceFrame() {
        var rig = LiveProxyRigRetargeter()
        acquire(&rig)
        let input = frame(timestamp: 1420, armBent: true)
        let result = rig.update(input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.timestampMilliseconds, 1420)
        XCTAssertEqual(result?.imageSize, size)
        XCTAssertEqual(result?.points.count, 33)
        XCTAssertEqual(result?.worldPoints.count, 33)
        XCTAssertTrue(result!.points[13].isUsable)
        XCTAssertTrue(result!.points[15].isUsable)

        let reference = frame(timestamp: 1000)
        func distance(_ a: PoseWorldPoint, _ b: PoseWorldPoint) -> Float {
            simd_length(
                SIMD3<Float>(a.x - b.x, a.y - b.y, a.z - b.z)
            )
        }
        // When a chain is retargeted, it preserves the captured
        // reference lengths rather than stretching to noisy targets.
        let upper = distance(
            result!.worldPoints[11], result!.worldPoints[13]
        )
        let lower = distance(
            result!.worldPoints[13], result!.worldPoints[15]
        )
        XCTAssertEqual(upper, distance(
            reference.worldPoints[11], reference.worldPoints[13]
        ), accuracy: 0.002)
        XCTAssertEqual(lower, distance(
            reference.worldPoints[13], reference.worldPoints[15]
        ), accuracy: 0.002)
    }

    func testDropoutResetsReferenceAndRequiresStableReacquisition() {
        var rig = LiveProxyRigRetargeter()
        acquire(&rig)
        XCTAssertNil(rig.update(nil))
        XCTAssertNil(rig.update(frame(timestamp: 2000)))
        XCTAssertNil(rig.update(frame(
            timestamp: 2033, visibleHips: false
        )))
        XCTAssertNil(rig.update(frame(timestamp: 2066)))
        rig.reset()
        acquire(&rig, from: 3000)
    }

    func testSourceResolutionChangeAndTimestampReplayFailClosed() {
        var rig = LiveProxyRigRetargeter()
        acquire(&rig)
        XCTAssertNil(rig.update(frame(timestamp: 1363)))
        XCTAssertNil(rig.update(frame(
            timestamp: 1400,
            imageSize: CGSize(width: 1080, height: 1920)
        )))
        XCTAssertNil(rig.update(frame(timestamp: 1433)))
    }

    func testMissingWorldAndPartialBodyDoNotInventIK() {
        var rig = LiveProxyRigRetargeter()
        acquire(&rig)
        let partial = frame(timestamp: 1500, visibleHips: false)
        XCTAssertNil(rig.update(partial))

        let source = frame(timestamp: 1600)
        let withoutWorld = PoseSnapshot(
            timestampMilliseconds: 1600,
            imageSize: source.imageSize,
            points: source.points
        )
        XCTAssertNil(rig.update(withoutWorld))
    }
}

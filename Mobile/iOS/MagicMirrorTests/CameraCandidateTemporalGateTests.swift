import CoreGraphics
import simd
import XCTest
@testable import MagicMirror

/// Synthetic model-space camera candidates; no independently calibrated
/// iPhone camera or anatomical atlas is represented by these fixtures.
final class CameraCandidateTemporalGateTests: XCTestCase {
    private func candidate(
        timestamp: Int = 1000,
        yaw: Float = 0,
        z: Float = 2.5,
        error: Float = 0.01,
        count: Int = 12,
        size: CGSize = CGSize(width: 720, height: 1280)
    ) -> AutomaticCameraPoseCandidate {
        AutomaticCameraPoseCandidate(
            timestampMilliseconds: timestamp,
            imageSize: size,
            transform: BodyToCameraTransform(
                rotation: simd_quatf(
                    angle: yaw, axis: SIMD3<Float>(0, 1, 0)
                ),
                translation: SIMD3<Float>(0, 0, z)
            ),
            landmarkCount: count,
            p90ReprojectionErrorFractionOfWidth: error
        )
    }

    func testThreeConsistentIndependentSourceCandidatesRequired() {
        var gate = CameraCandidateTemporalGate()
        XCTAssertNil(gate.observe(candidate(timestamp: 1000)))
        XCTAssertNil(gate.observe(candidate(timestamp: 1750, yaw: 0.05)))
        let stable = gate.observe(candidate(timestamp: 2500, yaw: 0.08))
        XCTAssertEqual(stable?.timestampMilliseconds, 2500)
        XCTAssertNil(gate.observe(nil))
        XCTAssertNil(gate.observe(candidate(timestamp: 4000)))
    }

    func testRejectReplayedSourcePoseCameraFlipAndInterruption() {
        var gate = CameraCandidateTemporalGate()
        XCTAssertNil(gate.observe(candidate(timestamp: 1000)))
        XCTAssertNil(gate.observe(candidate(timestamp: 1000)))
        XCTAssertNil(gate.observe(candidate(timestamp: 1750)))
        XCTAssertNil(gate.observe(candidate(timestamp: 2400, yaw: 2.3)))
        XCTAssertNil(gate.observe(candidate(timestamp: 4800, yaw: 2.3)))
        XCTAssertNil(gate.observe(candidate(timestamp: 5400, yaw: 2.3)))
        XCTAssertEqual(
            gate.observe(candidate(timestamp: 6100, yaw: 2.3))?
                .timestampMilliseconds, 6100
        )
    }

    func testLowQualityOrChangedSourceDimensionsEraseContinuity() {
        var gate = CameraCandidateTemporalGate()
        XCTAssertNil(gate.observe(candidate(timestamp: 1000)))
        XCTAssertNil(gate.observe(candidate(timestamp: 1700, count: 7)))
        XCTAssertNil(gate.observe(candidate(timestamp: 2400)))
        XCTAssertNil(gate.observe(candidate(
            timestamp: 3100, size: CGSize(width: 1280, height: 720)
        )))
        XCTAssertNil(gate.observe(candidate(timestamp: 3800, error: 0.1)))
        XCTAssertNil(gate.observe(candidate(timestamp: 4500)))
    }

    func testVeryFastPersonMotionNeedsNewContinuityWindow() {
        var gate = CameraCandidateTemporalGate()
        XCTAssertNil(gate.observe(candidate(timestamp: 1000)))
        XCTAssertNil(gate.observe(candidate(timestamp: 1750, z: 3.3)))
        XCTAssertNil(gate.observe(candidate(timestamp: 2500, z: 3.35)))
        XCTAssertEqual(
            gate.observe(candidate(timestamp: 3250, z: 3.4))?
                .timestampMilliseconds, 3250
        )
    }
}

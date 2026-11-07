import XCTest
@testable import MagicMirror

final class PoseDeliveryQualityMonitorTests: XCTestCase {
    func testThirtyFPSPoseCallbackCadencePublishesHonestMetrics() {
        var monitor = PoseDeliveryQualityMonitor()
        var latest: PoseDeliveryReport?
        for index in 0...75 {
            if let report = monitor.observe(
                timestampMilliseconds: 1000 + 33 * index,
                callbackUptime: 20 + 0.033 * Double(index)
            ) {
                latest = report
            }
        }
        XCTAssertNotNil(latest)
        XCTAssertGreaterThan(latest!.outputFPS, 28)
        XCTAssertLessThan(latest!.outputFPS, 32)
        XCTAssertEqual(latest!.p95DeliveryGapMilliseconds, 33, accuracy: 0.001)
        XCTAssertGreaterThan(latest!.acceptedFrames, 30)
        XCTAssertEqual(
            latest!.latestPoseTimestampMilliseconds % 33,
            1000 % 33
        )
    }

    func testP95CountsActualCallbackGapsNotSourceTimestampSpacing() {
        var monitor = PoseDeliveryQualityMonitor(
            reportEverySeconds: 0.001, maxSamples: 10
        )
        XCTAssertNil(monitor.observe(
            timestampMilliseconds: 1000, callbackUptime: 1.0
        ))
        _ = monitor.observe(
            timestampMilliseconds: 1033, callbackUptime: 1.020
        )
        _ = monitor.observe(
            timestampMilliseconds: 1066, callbackUptime: 1.040
        )
        let report = monitor.observe(
            timestampMilliseconds: 1099, callbackUptime: 1.100
        )
        XCTAssertNotNil(report)
        XCTAssertEqual(
            report!.p95DeliveryGapMilliseconds, 60,
            accuracy: 0.0001
        )
        XCTAssertEqual(report!.outputFPS, 30, accuracy: 0.1)
    }

    func testRejectsInvalidUptimeAndReplayedFrames() {
        var monitor = PoseDeliveryQualityMonitor(
            reportEverySeconds: 0.01
        )
        XCTAssertNil(monitor.observe(
            timestampMilliseconds: -1, callbackUptime: 1
        ))
        XCTAssertNil(monitor.observe(
            timestampMilliseconds: 100, callbackUptime: .nan
        ))
        XCTAssertNil(monitor.observe(
            timestampMilliseconds: 100, callbackUptime: 1
        ))
        XCTAssertNil(monitor.observe(
            timestampMilliseconds: 100, callbackUptime: 2
        ))
        XCTAssertNil(monitor.observe(
            timestampMilliseconds: 120, callbackUptime: 0.5
        ))
        let good = monitor.observe(
            timestampMilliseconds: 120, callbackUptime: 2.1
        )
        XCTAssertNotNil(good)
        XCTAssertEqual(good?.acceptedFrames, 2)
    }

    func testLongInterruptionStartsNewWindow() {
        var monitor = PoseDeliveryQualityMonitor(
            reportEverySeconds: 0.01
        )
        XCTAssertNil(monitor.observe(
            timestampMilliseconds: 1000, callbackUptime: 10
        ))
        XCTAssertNotNil(monitor.observe(
            timestampMilliseconds: 1033, callbackUptime: 10.033
        ))
        XCTAssertNil(monitor.observe(
            timestampMilliseconds: 4000, callbackUptime: 13.5
        ))
        let resumed = monitor.observe(
            timestampMilliseconds: 4033, callbackUptime: 13.54
        )
        XCTAssertNotNil(resumed)
        XCTAssertEqual(resumed!.acceptedFrames, 2)
    }

    func testExplicitResetDoesNotLeakPreviousSessionCounters() {
        var monitor = PoseDeliveryQualityMonitor(
            reportEverySeconds: 0.01
        )
        _ = monitor.observe(
            timestampMilliseconds: 1000, callbackUptime: 50
        )
        XCTAssertNotNil(monitor.observe(
            timestampMilliseconds: 1030, callbackUptime: 50.030
        ))
        monitor.reset()
        XCTAssertNil(monitor.observe(
            timestampMilliseconds: 100, callbackUptime: 100
        ))
        let report = monitor.observe(
            timestampMilliseconds: 125, callbackUptime: 100.025
        )
        XCTAssertEqual(report?.acceptedFrames, 2)
    }
}

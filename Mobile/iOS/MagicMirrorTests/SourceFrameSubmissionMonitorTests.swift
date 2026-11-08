import XCTest
@testable import MagicMirror

final class SourceFrameSubmissionMonitorTests: XCTestCase {
    func testReportsSourceCallbackToCommandSubmitAgeNotPoseCallbackRate() {
        var monitor = SourceFrameSubmissionMonitor()
        var report: SourceFrameSubmissionReport?
        for i in 0...60 {
            report = monitor.observe(
                timestampMilliseconds: 1000 + 33 * i,
                captureCallbackUptime: 20 + Double(i) * 0.033,
                submittedUptime: 20.050 + Double(i) * 0.033
            ) ?? report
        }
        XCTAssertNotNil(report)
        XCTAssertEqual(report?.p50CallbackToSubmitMilliseconds ?? -1,
                       50, accuracy: 0.001)
        XCTAssertEqual(report?.p95CallbackToSubmitMilliseconds ?? -1,
                       50, accuracy: 0.001)
        XCTAssertGreaterThan(report?.submittedFrames ?? 0, 30)
    }

    func testRepeatedDrawOfSameImageDoesNotInflateCounter() {
        var monitor = SourceFrameSubmissionMonitor(reportEverySeconds: 0.001)
        XCTAssertNil(monitor.observe(
            timestampMilliseconds: 101, captureCallbackUptime: 1,
            submittedUptime: 1.03
        ))
        XCTAssertNil(monitor.observe(
            timestampMilliseconds: 101, captureCallbackUptime: 1,
            submittedUptime: 1.05
        ))
        let report = monitor.observe(
            timestampMilliseconds: 132, captureCallbackUptime: 1.01,
            submittedUptime: 1.06
        )
        XCTAssertEqual(report?.submittedFrames, 2)
        XCTAssertEqual(report?.p95CallbackToSubmitMilliseconds ?? -1,
                       50, accuracy: 0.001)
    }

    func testRejectsBadClockAndSourceOrderingWithoutFalseLatency() {
        var monitor = SourceFrameSubmissionMonitor(reportEverySeconds: 0.001)
        XCTAssertNil(monitor.observe(
            timestampMilliseconds: 1, captureCallbackUptime: .nan,
            submittedUptime: 1.01
        ))
        XCTAssertNil(monitor.observe(
            timestampMilliseconds: 2, captureCallbackUptime: 2,
            submittedUptime: 1.02
        ))
        XCTAssertNil(monitor.observe(
            timestampMilliseconds: 3, captureCallbackUptime: -1,
            submittedUptime: 1.03
        ))
        XCTAssertNil(monitor.observe(
            timestampMilliseconds: 4, captureCallbackUptime: nil,
            submittedUptime: 1.04
        ))
        XCTAssertNil(monitor.observe(
            timestampMilliseconds: 5, captureCallbackUptime: 0,
            submittedUptime: 1.05
        ))
        XCTAssertNil(monitor.observe(
            timestampMilliseconds: 6, captureCallbackUptime: 1.05,
            submittedUptime: 1.06
        ))
        XCTAssertNil(monitor.observe(
            timestampMilliseconds: 6, captureCallbackUptime: 1.06,
            submittedUptime: 1.07
        ))
        let report = monitor.observe(
            timestampMilliseconds: 7, captureCallbackUptime: 1.07,
            submittedUptime: 1.08
        )
        XCTAssertEqual(report?.submittedFrames, 2)
        XCTAssertEqual(report?.p95CallbackToSubmitMilliseconds ?? -1,
                       10, accuracy: 0.001)
    }

    func testDifferentWindowAndInterruptionReset() {
        var monitor = SourceFrameSubmissionMonitor(
            reportEverySeconds: 0.01, maxSamples: 3
        )
        XCTAssertNil(monitor.observe(
            timestampMilliseconds: 1000, captureCallbackUptime: 10,
            submittedUptime: 10.01
        ))
        _ = monitor.observe(
            timestampMilliseconds: 1010, captureCallbackUptime: 10.005,
            submittedUptime: 10.025
        )
        _ = monitor.observe(
            timestampMilliseconds: 1020, captureCallbackUptime: 10.01,
            submittedUptime: 10.040
        )
        let report = monitor.observe(
            timestampMilliseconds: 1030, captureCallbackUptime: 10.01,
            submittedUptime: 10.055
        )
        XCTAssertEqual(report?.p95CallbackToSubmitMilliseconds ?? -1,
                       45, accuracy: 0.001)
        XCTAssertNil(monitor.observe(
            timestampMilliseconds: 2000, captureCallbackUptime: 14.0,
            submittedUptime: 14.01
        ))
        let resumed = monitor.observe(
            timestampMilliseconds: 2010, captureCallbackUptime: 14.01,
            submittedUptime: 14.03
        )
        XCTAssertEqual(resumed?.submittedFrames, 2)
        XCTAssertEqual(resumed?.p95CallbackToSubmitMilliseconds ?? -1,
                       20, accuracy: 0.001)
        monitor.reset()
        XCTAssertNil(monitor.observe(
            timestampMilliseconds: 1, captureCallbackUptime: 20,
            submittedUptime: 20.02
        ))
    }
}

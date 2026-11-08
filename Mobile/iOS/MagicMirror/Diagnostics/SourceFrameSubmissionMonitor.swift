import Foundation

/// Submission age of the exact AVFoundation video buffer paired with a
/// MediaPipe result. Measured from captureOutput callback receipt to
/// CPU-side Metal commandBuffer.commit(), using the same monotonic clock.
///
/// This is NOT camera exposure-to-photon latency, display FPS, GPU
/// completion time or measured human movement response.
struct SourceFrameSubmissionReport: Equatable {
    let submittedFrames: Int
    let p50CallbackToSubmitMilliseconds: Double
    let p95CallbackToSubmitMilliseconds: Double
    let latestPoseTimestampMilliseconds: Int
}

/// The renderer may redraw the same pose/video buffer multiple times due
/// to SwiftUI updates. Only the first submitted drawable per strictly
/// increasing source timestamp contributes a sample. Windowed and local.
struct SourceFrameSubmissionMonitor {
    private let reportEverySeconds: Double
    private let maxSamples: Int
    private var lastTimestamp = -1
    private var lastSubmittedUptime: Double?
    private var lastReportedUptime: Double?
    private var agesMilliseconds: [Double] = []
    private var accepted = 0

    init(reportEverySeconds: Double = 1, maxSamples: Int = 120) {
        precondition(reportEverySeconds > 0 && reportEverySeconds.isFinite)
        precondition(maxSamples > 0)
        self.reportEverySeconds = reportEverySeconds
        self.maxSamples = maxSamples
    }

    mutating func reset() {
        lastTimestamp = -1
        lastSubmittedUptime = nil
        lastReportedUptime = nil
        agesMilliseconds.removeAll(keepingCapacity: true)
        accepted = 0
    }

    /// A missing or invalid callback timestamp is not a timing sample.
    /// Samples older than 1000 ms are rejected instead of stretching
    /// an unrelated rendering session across app pauses.
    mutating func observe(
        timestampMilliseconds: Int,
        captureCallbackUptime: Double?,
        submittedUptime: Double
    ) -> SourceFrameSubmissionReport? {
        guard timestampMilliseconds >= 0,
              submittedUptime.isFinite, submittedUptime >= 0,
              lastSubmittedUptime.map({ submittedUptime >= $0 }) ?? true else {
            return nil
        }

        if let previous = lastSubmittedUptime,
           submittedUptime - previous >= 2 {
            reset()
        }
        guard timestampMilliseconds > lastTimestamp else { return nil }

        // A valid frame may be redrawn after a bad timestamp. Mark its
        // identity as visited even if its timing sample is rejected.
        lastTimestamp = timestampMilliseconds
        lastSubmittedUptime = submittedUptime
        guard let callback = captureCallbackUptime,
              callback.isFinite, callback >= 0,
              callback <= submittedUptime else { return nil }
        let age = (submittedUptime - callback) * 1000
        guard age.isFinite, age >= 0, age <= 1000 else { return nil }

        agesMilliseconds.append(age)
        if agesMilliseconds.count > maxSamples {
            agesMilliseconds.removeFirst(agesMilliseconds.count - maxSamples)
        }
        accepted += 1

        guard agesMilliseconds.count > 1 else {
            lastReportedUptime = submittedUptime
            return nil
        }
        if let previous = lastReportedUptime,
           submittedUptime - previous < reportEverySeconds {
            return nil
        }

        let ordered = agesMilliseconds.sorted()
        func percentile(_ fraction: Double) -> Double {
            let index = max(0, min(
                ordered.count - 1,
                Int(ceil(fraction * Double(ordered.count))) - 1
            ))
            return ordered[index]
        }
        lastReportedUptime = submittedUptime
        return SourceFrameSubmissionReport(
            submittedFrames: accepted,
            p50CallbackToSubmitMilliseconds: percentile(0.50),
            p95CallbackToSubmitMilliseconds: percentile(0.95),
            latestPoseTimestampMilliseconds: timestampMilliseconds
        )
    }
}

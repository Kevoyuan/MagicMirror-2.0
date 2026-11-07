import Foundation

/// Native device-local delivery metrics. These describe the interval
/// between accepted MediaPipe pose callbacks, NOT display refresh rate,
/// GPU-completion latency or camera-to-photon delay.
/// No camera pixels, body landmarks, accounts or network data are stored.
struct PoseDeliveryReport: Equatable {
    let acceptedFrames: Int
    let outputFPS: Double
    let p95DeliveryGapMilliseconds: Double
    let latestPoseTimestampMilliseconds: Int
}

struct PoseDeliveryQualityMonitor {
    private let reportEverySeconds: Double
    private let maxSamples: Int
    private var lastUptime: Double?
    private var lastPoseTimestamp = -1
    private var lastReportedUptime: Double?
    private var gapsMilliseconds: [Double] = []
    private var count = 0

    init(reportEverySeconds: Double = 1, maxSamples: Int = 120) {
        precondition(reportEverySeconds > 0 && reportEverySeconds.isFinite)
        precondition(maxSamples > 0)
        self.reportEverySeconds = reportEverySeconds
        self.maxSamples = maxSamples
    }

    mutating func reset() {
        lastUptime = nil
        lastPoseTimestamp = -1
        lastReportedUptime = nil
        gapsMilliseconds.removeAll(keepingCapacity: true)
        count = 0
    }

    /// Feed only accepted source-time-monotonic pose outputs, using
    /// ProcessInfo.processInfo.systemUptime on the receiving thread.
    /// Inference/model startup and camera loss start a new session.
    mutating func observe(
        timestampMilliseconds timestamp: Int,
        callbackUptime: Double
    ) -> PoseDeliveryReport? {
        guard timestamp >= 0,
              timestamp > lastPoseTimestamp,
              callbackUptime.isFinite, callbackUptime >= 0,
              lastUptime.map({ callbackUptime > $0 }) ?? true else {
            return nil
        }

        if let previous = lastUptime {
            let gap = (callbackUptime - previous) * 1000
            if gap >= 2000 {
                // App was paused or camera dropped out; never combine
                // pre-interruption delivery rates with the new session.
                reset()
            } else if gap > 0 && gap.isFinite {
                gapsMilliseconds.append(gap)
                if gapsMilliseconds.count > maxSamples {
                    gapsMilliseconds.removeFirst(
                        gapsMilliseconds.count - maxSamples
                    )
                }
            }
        }
        lastUptime = callbackUptime
        lastPoseTimestamp = timestamp
        count += 1

        guard !gapsMilliseconds.isEmpty else {
            lastReportedUptime = callbackUptime
            return nil
        }
        if let previous = lastReportedUptime,
           callbackUptime - previous < reportEverySeconds {
            return nil
        }

        let ordered = gapsMilliseconds.sorted()
        let averageGap = ordered.reduce(0, +) / Double(ordered.count)
        guard averageGap > 0, averageGap.isFinite else { return nil }
        let index = min(
            ordered.count - 1,
            Int(ceil(0.95 * Double(ordered.count))) - 1
        )
        lastReportedUptime = callbackUptime
        return PoseDeliveryReport(
            acceptedFrames: count,
            outputFPS: 1000 / averageGap,
            p95DeliveryGapMilliseconds: ordered[index],
            latestPoseTimestampMilliseconds: timestamp
        )
    }
}

import AVFoundation
import Observation
import SwiftUI

@Observable
@MainActor
final class MirrorViewModel {
    let pipeline = CameraPosePipeline()

    var phase: MirrorPhase = .idle
    var snapshot: PoseSnapshot?
    var opacity = 0.64
    var isPaused = false

    private var isActive = false
    private var mostRecentTimestamp = -1
    private var lastPoseReceiptUptime = 0.0
    private var temporalFilter = PoseTemporalFilter()
    private var expiryTask: Task<Void, Never>?

    init() {
        pipeline.onPose = { [weak self] result in
            guard let self, self.isActive, !self.isPaused else { return }
            if let result {
                guard result.timestampMilliseconds > self.mostRecentTimestamp else {
                    return
                }
                self.mostRecentTimestamp = result.timestampMilliseconds
            }
            self.snapshot = self.temporalFilter.apply(result)
            if result != nil {
                self.lastPoseReceiptUptime = ProcessInfo.processInfo.systemUptime
            }
        }
        pipeline.onPhase = { [weak self] phase in
            guard let self, self.isActive else { return }
            if self.phase != phase {
                self.phase = phase
            }
        }
    }

    func start() {
        guard !isActive else { return }
        isActive = true
        isPaused = false
        mostRecentTimestamp = -1
        temporalFilter.reset()
        expiryTask?.cancel()
        expiryTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(120))
                guard let self, self.isActive else { return }
                if self.snapshot != nil &&
                   ProcessInfo.processInfo.systemUptime - self.lastPoseReceiptUptime > 0.30 {
                    self.snapshot = nil
                    self.temporalFilter.reset()
                    self.phase = .searching
                }
            }
        }
        pipeline.start()
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        expiryTask?.cancel()
        expiryTask = nil
        temporalFilter.reset()
        snapshot = nil
        phase = .idle
        pipeline.stop()
    }

    func togglePause() {
        isPaused.toggle()
        if isPaused {
            temporalFilter.reset()
            snapshot = nil  // Never present stale tracked bones as live data.
        } else {
            mostRecentTimestamp = -1
        }
    }
}

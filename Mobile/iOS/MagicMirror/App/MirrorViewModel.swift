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

    init() {
        pipeline.onPose = { [weak self] result in
            guard let self, self.isActive, !self.isPaused else { return }
            if let result {
                guard result.timestampMilliseconds > self.mostRecentTimestamp else {
                    return
                }
                self.mostRecentTimestamp = result.timestampMilliseconds
            }
            self.snapshot = result
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
        pipeline.start()
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        snapshot = nil
        phase = .idle
        pipeline.stop()
    }

    func togglePause() {
        isPaused.toggle()
        if isPaused {
            snapshot = nil  // Never present stale tracked bones as live data.
        } else {
            mostRecentTimestamp = -1
        }
    }
}

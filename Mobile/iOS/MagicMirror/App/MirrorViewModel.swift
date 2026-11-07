import AVFoundation
import Observation
import SwiftUI

@Observable
@MainActor
final class MirrorViewModel {
    let pipeline = CameraPosePipeline()

    var phase: MirrorPhase = .idle
    var snapshot: PoseSnapshot?
    var alignedFrame: AlignedPoseVideoFrame?
    var opacity = 0.64
    var focus: AnatomyFocus = .full
    var isPaused = false

    private var isActive = false
    private var mostRecentTimestamp = -1
    private var lastPoseReceiptUptime = 0.0
    private var temporalFilter = PoseTemporalFilter()
    private var expiryTask: Task<Void, Never>?

    init() {
        pipeline.onAlignedFrame = { [weak self] incoming in
            guard let self, self.isActive, !self.isPaused else { return }
            if let incoming {
                guard incoming.pose.timestampMilliseconds
                        > self.mostRecentTimestamp else { return }
                self.mostRecentTimestamp = incoming.pose.timestampMilliseconds
                let smooth = self.temporalFilter.apply(incoming.pose)
                self.snapshot = smooth
                self.alignedFrame = smooth.map {
                    AlignedPoseVideoFrame(
                        pose: $0, pixelBuffer: incoming.pixelBuffer
                    )
                }
                self.lastPoseReceiptUptime = ProcessInfo.processInfo.systemUptime
            } else {
                self.temporalFilter.reset()
                self.snapshot = nil
                self.alignedFrame = nil
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
                    self.alignedFrame = nil
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
        alignedFrame = nil
        phase = .idle
        pipeline.stop()
    }

    func togglePause() {
        isPaused.toggle()
        if isPaused {
            temporalFilter.reset()
            snapshot = nil
            alignedFrame = nil  // No frozen video or stale tracked bones.
        } else {
            mostRecentTimestamp = -1
        }
    }
}

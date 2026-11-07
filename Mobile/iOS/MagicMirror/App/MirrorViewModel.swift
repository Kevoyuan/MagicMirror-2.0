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
    /// Geometry-only, fixed-length reference pose for this source frame.
    var proxyRigPose: PoseSnapshot?
    var opacity = 0.64
    var focus: AnatomyFocus = .full
    var isPaused = false
    var showDiagnostics = false
    var deliveryReport: PoseDeliveryReport?

    private var isActive = false
    private var mostRecentTimestamp = -1
    private var lastPoseReceiptUptime = 0.0
    private var temporalFilter = PoseTemporalFilter()
    private var proxyRig = LiveProxyRigRetargeter()
    private var deliveryMonitor = PoseDeliveryQualityMonitor()
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
                self.proxyRigPose = self.proxyRig.update(smooth)
                self.alignedFrame = smooth.map {
                    AlignedPoseVideoFrame(
                        pose: $0, pixelBuffer: incoming.pixelBuffer
                    )
                }
                let now = ProcessInfo.processInfo.systemUptime
                self.lastPoseReceiptUptime = now
                if let report = self.deliveryMonitor.observe(
                    timestampMilliseconds: incoming.pose.timestampMilliseconds,
                    callbackUptime: now
                ) {
                    self.deliveryReport = report
                }
            } else {
                self.temporalFilter.reset()
                self.deliveryMonitor.reset()
                self.deliveryReport = nil
                self.snapshot = nil
                self.alignedFrame = nil
                self.proxyRigPose = nil
                self.proxyRig.reset()
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
        proxyRig.reset()
        proxyRigPose = nil
        deliveryMonitor.reset()
        deliveryReport = nil
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
                    self.proxyRig.reset()
                    self.proxyRigPose = nil
                    self.deliveryMonitor.reset()
                    self.deliveryReport = nil
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
        proxyRig.reset()
        proxyRigPose = nil
        deliveryMonitor.reset()
        deliveryReport = nil
        snapshot = nil
        alignedFrame = nil
        phase = .idle
        pipeline.stop()
    }

    func toggleDiagnostics() {
        showDiagnostics.toggle()
    }

    func togglePause() {
        isPaused.toggle()
        if isPaused {
            temporalFilter.reset()
            proxyRig.reset()
            proxyRigPose = nil
            deliveryMonitor.reset()
            deliveryReport = nil
            snapshot = nil
            alignedFrame = nil  // No frozen video or stale tracked bones.
        } else {
            mostRecentTimestamp = -1
        }
    }
}

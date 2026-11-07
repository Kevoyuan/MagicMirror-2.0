import AVFoundation
import Observation
import SwiftUI

@Observable
@MainActor
final class MirrorViewModel {
    let pipeline = CameraPosePipeline()

    var phase: MirrorPhase = .idle
    var snapshot: PoseSnapshot?
    /// Stable visual recognition class; unlike snapshot, rarely changes.
    var currentCoverage: PoseCoverage = .none
    var alignedFrame: AlignedPoseVideoFrame?
    /// Geometry-only, fixed-length reference pose for this source frame.
    var proxyRigPose: PoseSnapshot?
    var calibratedAtlasBatch: CalibratedAtlasDrawBatch?
    var skinnedAtlasBatch: SkinnedAtlasDrawBatch?
    var activeSection: AnatomySectionPlane?
    var sectionOffset: Double = 0
    var canSectionReviewedAtlas = false
    var opacity = 0.64
    var focus: AnatomyFocus = .full
    var isPaused = false
    var showDiagnostics = false
    var deliveryReport: PoseDeliveryReport?
    /// Diagnostic pose fit only; never an approved atlas calibration.
    var automaticCameraCandidate: AutomaticCameraPoseCandidate?

    private var isActive = false
    private var mostRecentTimestamp = -1
    private var lastPoseReceiptUptime = 0.0
    private var temporalFilter = PoseTemporalFilter()
    private var proxyRig = LiveProxyRigRetargeter()
    private var reviewedAtlas: LiveReviewedAtlasRuntime?
    private var reviewedAtlasLoad: Task<Void, Never>?
    private var reviewedCameraForFrame: ((PoseSnapshot) -> ReviewedSourceCameraFrame?)?
    private var viewportSize: CGSize = .zero
    private var deliveryMonitor = PoseDeliveryQualityMonitor()
    private var expiryTask: Task<Void, Never>?
    private var cameraEstimateTask: Task<Void, Never>?
    private var cameraEstimateLastStart = 0.0
    private var cameraEstimateEpoch: UInt64 = 0

    init() {
        pipeline.onAlignedFrame = { [weak self] incoming in
            guard let self, self.isActive, !self.isPaused else { return }
            if let incoming {
                guard incoming.pose.timestampMilliseconds
                        > self.mostRecentTimestamp else { return }
                self.mostRecentTimestamp = incoming.pose.timestampMilliseconds
                let smooth = self.temporalFilter.apply(incoming.pose)
                if self.snapshot?.imageSize != smooth?.imageSize {
                    self.resetAutomaticCamera()
                }
                self.snapshot = smooth
                let coverage = smooth?.coverage ?? .none
                if self.currentCoverage != coverage {
                    self.currentCoverage = coverage
                }
                self.proxyRigPose = self.proxyRig.update(smooth)
                self.calibratedAtlasBatch = self.reviewedAtlas?.render(
                    frame: smooth,
                    reviewedCamera: smooth.flatMap {
                        self.reviewedCameraForFrame?($0)
                    },
                    viewport: self.viewportSize,
                    focus: self.focus,
                    opacity: Float(self.opacity),
                    section: self.activeSection,
                    sectionOffset: Float(self.sectionOffset)
                )
                self.skinnedAtlasBatch = self.reviewedAtlas?.skinnedFrame
                self.canSectionReviewedAtlas = self.skinnedAtlasBatch != nil
                if !self.canSectionReviewedAtlas {
                    self.activeSection = nil
                }
                self.alignedFrame = smooth.map {
                    AlignedPoseVideoFrame(
                        pose: $0, pixelBuffer: incoming.pixelBuffer
                    )
                }
                let now = ProcessInfo.processInfo.systemUptime
                self.lastPoseReceiptUptime = now
                if let smooth {
                    self.maybeEstimateCamera(from: smooth, now: now)
                }
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
                self.currentCoverage = .none
                self.alignedFrame = nil
                self.proxyRigPose = nil
                self.proxyRig.reset()
                self.reviewedAtlas?.reset()
                self.calibratedAtlasBatch = nil
                self.skinnedAtlasBatch = nil
                self.canSectionReviewedAtlas = false
                self.activeSection = nil
                self.resetAutomaticCamera()
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
        resetAutomaticCamera()
        mostRecentTimestamp = -1
        currentCoverage = .none
        temporalFilter.reset()
        proxyRig.reset()
        proxyRigPose = nil
        calibratedAtlasBatch = nil
        skinnedAtlasBatch = nil
        canSectionReviewedAtlas = false
        activeSection = nil
        reviewedAtlas?.reset()
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
                    self.currentCoverage = .none
                    self.alignedFrame = nil
                    self.temporalFilter.reset()
                    self.proxyRig.reset()
                    self.proxyRigPose = nil
                    self.reviewedAtlas?.reset()
                    self.calibratedAtlasBatch = nil
                    self.skinnedAtlasBatch = nil
                    self.canSectionReviewedAtlas = false
                    self.activeSection = nil
                    self.resetAutomaticCamera()
                    self.deliveryMonitor.reset()
                    self.deliveryReport = nil
                    self.phase = .searching
                }
            }
        }
        // Verify large atlas/companion USDZ assets off the main actor.
        // No reviewed model is present in the normal app bundle.
        if reviewedAtlas == nil {
            reviewedAtlasLoad?.cancel()
            reviewedAtlasLoad = Task.detached(priority: .utility) { [weak self] in
                let assets = try? ReviewedAtlasRuntimeResources.load()
                await MainActor.run {
                    guard let self, self.isActive, let assets else { return }
                    self.reviewedAtlas = LiveReviewedAtlasRuntime(
                        resources: assets
                    )
                }
            }
        }
        pipeline.start()
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        resetAutomaticCamera()
        expiryTask?.cancel()
        expiryTask = nil
        reviewedAtlasLoad?.cancel()
        reviewedAtlasLoad = nil
        temporalFilter.reset()
        proxyRig.reset()
        proxyRigPose = nil
        calibratedAtlasBatch = nil
        skinnedAtlasBatch = nil
        canSectionReviewedAtlas = false
        activeSection = nil
        reviewedAtlas?.reset()
        deliveryMonitor.reset()
        deliveryReport = nil
        snapshot = nil
        currentCoverage = .none
        alignedFrame = nil
        phase = .idle
        pipeline.stop()
    }

    /// Used only by an independently verified live camera/body registration
    /// implementation. It is deliberately nil in the current product.
    func installIndependentlyReviewedCameraProvider(
        _ provider: @escaping (PoseSnapshot) -> ReviewedSourceCameraFrame?
    ) {
        reviewedCameraForFrame = provider
        reviewedAtlas?.reset()
        calibratedAtlasBatch = nil
        skinnedAtlasBatch = nil
        canSectionReviewedAtlas = false
        activeSection = nil
    }

    func setViewportSize(_ size: CGSize) {
        guard size != viewportSize else { return }
        viewportSize = size
        calibratedAtlasBatch = nil
        skinnedAtlasBatch = nil
        canSectionReviewedAtlas = false
        activeSection = nil
    }

    private func resetAutomaticCamera() {
        cameraEstimateEpoch &+= 1
        cameraEstimateTask?.cancel()
        cameraEstimateTask = nil
        automaticCameraCandidate = nil
        cameraEstimateLastStart = 0
    }

    /// Scheduled at most once every 750 ms and never on the actor that
    /// displays camera frames. Candidate results cannot enable an
    /// independently-reviewed atlas camera gate.
    private func maybeEstimateCamera(
        from frame: PoseSnapshot, now: Double
    ) {
        guard frame.hasTorsoAnchor,
              frame.cameraIntrinsics != nil,
              cameraEstimateTask == nil,
              now - cameraEstimateLastStart >= 0.75
        else { return }
        cameraEstimateLastStart = now
        let epoch = cameraEstimateEpoch
        cameraEstimateTask = Task.detached(priority: .utility) { [weak self] in
            if Task.isCancelled { return }
            let result = AutomaticCameraPoseEstimator.estimate(
                snapshot: frame
            )
            if Task.isCancelled { return }
            await MainActor.run {
                guard let self,
                      self.isActive, !self.isPaused,
                      self.cameraEstimateEpoch == epoch else { return }
                self.cameraEstimateTask = nil
                guard self.snapshot?.imageSize == frame.imageSize,
                      self.mostRecentTimestamp >= frame.timestampMilliseconds,
                      self.mostRecentTimestamp -
                        frame.timestampMilliseconds <= 750 else {
                    self.automaticCameraCandidate = nil
                    return
                }
                self.automaticCameraCandidate = result
            }
        }
    }

    func toggleDiagnostics() {
        showDiagnostics.toggle()
    }

    func togglePause() {
        isPaused.toggle()
        if isPaused {
            resetAutomaticCamera()
            temporalFilter.reset()
            proxyRig.reset()
            proxyRigPose = nil
            calibratedAtlasBatch = nil
            skinnedAtlasBatch = nil
            canSectionReviewedAtlas = false
            activeSection = nil
            reviewedAtlas?.reset()
            deliveryMonitor.reset()
            deliveryReport = nil
            snapshot = nil
            currentCoverage = .none
            alignedFrame = nil  // No frozen video or stale tracked bones.
        } else {
            mostRecentTimestamp = -1
        }
    }
}

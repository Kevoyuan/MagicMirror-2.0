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
    var reviewedSkinnedFrames: [ReviewedSkinnedLayerFrame] = []
    var reviewedRigidFrames: [ReviewedRigidLayerFrame] = []
    var referenceSelection: AnatomyReferenceSelection?
    var reviewedPartSelection: ReviewedAnatomySelection?
    /// A system is selectable only after its own approved registered
    /// source atlas has produced coherent geometry on this capture.
    var readyAnatomyLayers: Set<AnatomyDisplayLayer> = []
    var selectedAnatomyLayer: AnatomyDisplayLayer = .skeleton
    /// Persistent layer visibility intent; actual GPU frames stay gated
    /// to approved source models on the same camera timestamp.
    var visibleAnatomyLayers: Set<AnatomyDisplayLayer> = [.skeleton]
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
    private var reviewedAtlasLayers: [AnatomyDisplayLayer: LiveReviewedAtlasRuntime] = [:]
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
                self.calibratedAtlasBatch = nil
                self.skinnedAtlasBatch = nil
                self.reviewedSkinnedFrames = []
                self.reviewedRigidFrames = []
                let reviewedCamera = smooth.flatMap {
                    self.reviewedCameraForFrame?($0)
                }
                // Stable draw order matches the anatomy notebook and
                // supports correct topmost visible-source tap selection.
                for layer in AnatomyDisplayLayer.allCases
                    where layer != .referenceProxy {
                    guard let runtime = self.reviewedAtlasLayers[layer]
                    else { continue }
                    let visible = self.visibleAnatomyLayers.contains(layer)
                    // Unselected packages are probed only until they
                    // first produce verified, registered geometry.
                    guard visible ||
                        !self.readyAnatomyLayers.contains(layer)
                    else { continue }
                    let rigid = runtime.render(
                        frame: smooth, reviewedCamera: reviewedCamera,
                        viewport: self.viewportSize, focus: self.focus,
                        opacity: Float(self.opacity),
                        section: visible ? self.activeSection : nil,
                        sectionOffset: Float(self.sectionOffset)
                    )
                    let skinned = runtime.skinnedFrame
                    if rigid != nil || skinned != nil {
                        self.readyAnatomyLayers.insert(layer)
                    }
                    guard visible else { continue }
                    if let skinned {
                        self.reviewedSkinnedFrames.append(
                            ReviewedSkinnedLayerFrame(
                                layer: layer, batch: skinned
                            )
                        )
                    } else if let rigid {
                        self.reviewedRigidFrames.append(
                            ReviewedRigidLayerFrame(
                                layer: layer, batch: rigid
                            )
                        )
                    }
                    if self.selectedAnatomyLayer == layer {
                        self.calibratedAtlasBatch = rigid
                        self.skinnedAtlasBatch = skinned
                    }
                }
                if let selectedPart = self.reviewedPartSelection {
                    let matches = self.reviewedSkinnedFrames.contains {
                        frame in
                        selectedPart.system == frame.layer &&
                        selectedPart.sourceRevision ==
                            frame.batch.sourceRevision &&
                        frame.batch.renderedParts.contains {
                            $0.sourceHierarchyPath ==
                                selectedPart.sourceHierarchyPath
                        }
                    }
                    if !matches { self.reviewedPartSelection = nil }
                }
                if self.skinnedAtlasBatch != nil ||
                   self.calibratedAtlasBatch != nil {
                    self.referenceSelection = nil
                } else if let selected = self.referenceSelection,
                          !(smooth.map { selected.visible(in: $0) } ?? false) {
                    self.referenceSelection = nil
                    self.reviewedPartSelection = nil
                }
                self.canSectionReviewedAtlas = !self.reviewedSkinnedFrames.isEmpty
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
                self.reviewedAtlasLayers.values.forEach { $0.reset() }
                self.readyAnatomyLayers = []
                self.calibratedAtlasBatch = nil
                self.skinnedAtlasBatch = nil
                self.reviewedSkinnedFrames = []
                self.reviewedRigidFrames = []
                self.referenceSelection = nil
                self.reviewedPartSelection = nil
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
        reviewedSkinnedFrames = []
        reviewedRigidFrames = []
        referenceSelection = nil
        reviewedPartSelection = nil
        canSectionReviewedAtlas = false
        activeSection = nil
        reviewedAtlasLayers.values.forEach { $0.reset() }
        readyAnatomyLayers = []
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
                    self.reviewedAtlasLayers.values.forEach { $0.reset() }
                self.readyAnatomyLayers = []
                    self.calibratedAtlasBatch = nil
                    self.skinnedAtlasBatch = nil
                    self.reviewedSkinnedFrames = []
                    self.reviewedRigidFrames = []
                    self.referenceSelection = nil
                    self.reviewedPartSelection = nil
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
        if reviewedAtlasLayers.isEmpty {
            reviewedAtlasLoad?.cancel()
            reviewedAtlasLoad = Task.detached(priority: .utility) { [weak self] in
                var loaded: [AnatomyDisplayLayer: ReviewedAtlasRuntimeResources] = [:]
                for layer in AnatomyDisplayLayer.allCases {
                    guard layer != .referenceProxy,
                          !Task.isCancelled else { continue }
                    if let resources = try? ReviewedAtlasRuntimeResources.load(
                        system: layer
                    ) {
                        loaded[layer] = resources
                    }
                }
                await MainActor.run {
                    guard let self, self.isActive,
                          !Task.isCancelled else { return }
                    for (layer, resources) in loaded {
                        self.reviewedAtlasLayers[layer] = LiveReviewedAtlasRuntime(
                            resources: resources
                        )
                    }
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
        reviewedSkinnedFrames = []
        reviewedRigidFrames = []
        referenceSelection = nil
        reviewedPartSelection = nil
        canSectionReviewedAtlas = false
        activeSection = nil
        reviewedAtlasLayers.values.forEach { $0.reset() }
        readyAnatomyLayers = []
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
        reviewedAtlasLayers.values.forEach { $0.reset() }
        readyAnatomyLayers = []
        calibratedAtlasBatch = nil
        skinnedAtlasBatch = nil
        reviewedSkinnedFrames = []
        reviewedRigidFrames = []
        referenceSelection = nil
        reviewedPartSelection = nil
        canSectionReviewedAtlas = false
        activeSection = nil
    }

    func setViewportSize(_ size: CGSize) {
        guard size != viewportSize else { return }
        viewportSize = size
        calibratedAtlasBatch = nil
        skinnedAtlasBatch = nil
        reviewedSkinnedFrames = []
        reviewedRigidFrames = []
        referenceSelection = nil
        reviewedPartSelection = nil
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

    /// The installed view uses one tap handler for both source-authored
    /// atlas triangles and the fallback visible proxy, never conflating them.
    func selectReference(at location: CGPoint, viewport: CGSize) {
        guard !isPaused else {
            referenceSelection = nil
            reviewedPartSelection = nil
            return
        }
        if let snapshot, !reviewedSkinnedFrames.isEmpty {
            reviewedPartSelection = nil
            // The compositor draws later layers last without a depth
            // buffer, so tap inspection chooses their visible surface
            // first, then falls through to earlier layers.
            for frame in reviewedSkinnedFrames.reversed() {
                let batch = frame.batch
                guard batch.matches(
                    frame: snapshot, viewport: viewport,
                    focus: focus, opacity: Float(opacity)
                ) else { continue }
                if let hit = ReviewedAtlasHitTester.select(
                    at: location, batch: batch, system: frame.layer
                ) {
                    reviewedPartSelection = hit
                    break
                }
            }
            referenceSelection = nil
            return
        }
        reviewedPartSelection = nil
        guard calibratedAtlasBatch == nil,
              reviewedRigidFrames.isEmpty else {
            referenceSelection = nil
            return
        }
        referenceSelection = AnatomyReferenceHitTester.select(
            at: location, snapshot: snapshot,
            viewport: viewport, focus: focus
        )
    }

    func dismissReferenceSelection() {
        referenceSelection = nil
        reviewedPartSelection = nil
    }

    func canSelectAnatomyLayer(_ layer: AnatomyDisplayLayer) -> Bool {
        layer == .referenceProxy || readyAnatomyLayers.contains(layer)
    }

    func isAnatomyLayerVisible(_ layer: AnatomyDisplayLayer) -> Bool {
        layer == .referenceProxy
            ? visibleAnatomyLayers.isEmpty
            : visibleAnatomyLayers.contains(layer)
    }

    /// Tapping a verified system toggles its *actual* 3D layer while
    /// keeping other independently approved systems visible.
    func selectAnatomyLayer(_ layer: AnatomyDisplayLayer) {
        guard canSelectAnatomyLayer(layer) else { return }
        visibleAnatomyLayers = AnatomyLayerVisibilityPolicy.toggled(
            layer: layer, ready: readyAnatomyLayers,
            visible: visibleAnatomyLayers
        )
        selectedAnatomyLayer = AnatomyLayerVisibilityPolicy.primary(
            preferred: layer, visible: visibleAnatomyLayers
        )
        calibratedAtlasBatch = nil
        skinnedAtlasBatch = nil
        reviewedSkinnedFrames = []
        reviewedRigidFrames = []
        canSectionReviewedAtlas = false
        activeSection = nil
        referenceSelection = nil
        reviewedPartSelection = nil
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
            reviewedSkinnedFrames = []
            reviewedRigidFrames = []
            referenceSelection = nil
            reviewedPartSelection = nil
            canSectionReviewedAtlas = false
            activeSection = nil
            reviewedAtlasLayers.values.forEach { $0.reset() }
            readyAnatomyLayers = []
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

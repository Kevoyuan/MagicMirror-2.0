import SwiftUI
import UIKit

/// One-screen phone experience. Only PoseSkeletonOverlay reads 30 Hz pose
/// updates; labels/controls read stable phase and opacity independently.
struct MirrorScreen: View {
    @State private var model = MirrorViewModel()
    @State private var showLayers = false
    @State private var showOpacity = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreview(session: model.pipeline.session)
                .ignoresSafeArea()

            GeometryReader { geometry in
                MetalSkeletonOverlay(
                    alignedFrame: model.isPaused ? nil : model.alignedFrame,
                    proxyPose: model.isPaused ? nil : model.proxyRigPose,
                    opacity: model.opacity, focus: model.focus,
                    calibratedAtlasBatch: model.isPaused
                        ? nil : model.calibratedAtlasBatch
                )
                .onAppear {
                    model.setViewportSize(geometry.size)
                }
                .onChange(of: geometry.size) { _, newSize in
                    model.setViewportSize(newSize)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            LinearGradient(
                colors: [
                    .black.opacity(0.48), .clear,
                    .clear, .black.opacity(0.50)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                header
                if model.showDiagnostics {
                    poseDiagnostics
                        .padding(.top, 10)
                }
                Spacer()
                if model.snapshot == nil || model.isPaused {
                    guidance
                        .padding(.bottom, 8)
                }
                controls
            }
            .padding(.horizontal, 14)
            .padding(.top, 2)
            .padding(.bottom, 5)
        }
        .task { model.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.start()
            } else {
                model.stop()
            }
        }
        .onDisappear { model.stop() }
        .sheet(isPresented: $showLayers) {
            AnatomyLayersSheet()
        }
    }

private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "book.closed")
                    .font(.system(size: 13, weight: .medium))
                    .accessibilityHidden(true)
                Text("MAGICMIRROR")
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .tracking(1.0)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(LeonardoPalette.ivory)
            .padding(.horizontal, 10)
            .frame(minHeight: 34)
            .background(LeonardoPalette.cameraScrim.opacity(0.65),
                        in: Capsule())

            Spacer(minLength: 1)

            Button {
                model.toggleDiagnostics()
            } label: {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(model.showDiagnostics
                        ? LeonardoPalette.ivory : LeonardoPalette.ivory.opacity(0.88))
                    .frame(width: 44, height: 44)
                    .background(LeonardoPalette.cameraScrim.opacity(0.7),
                                in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.showDiagnostics
                ? "Hide on-device pose diagnostics"
                : "Show on-device pose diagnostics")

            Label(trackingLabel, systemImage: statusIcon)
                .labelStyle(.titleAndIcon)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(LeonardoPalette.ivory)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(minHeight: 34)
                .background(LeonardoPalette.cameraScrim.opacity(0.86),
                            in: Capsule())
                .accessibilityLabel("Pose status: \(trackingLabel)")
        }
        // The 34-pt manuscript strip is visual only; controls retain
        // at least 44-pt hit targets and respect the real iPhone safe area.
        .frame(minHeight: 44)
        .accessibilityElement(children: .contain)
    }

    /// On-device callback cadence, not camera or GPU display FPS.
    /// No camera images, tracking points or diagnostics leave the phone.
    private var poseDiagnostics: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let report = model.deliveryReport {
                HStack(spacing: 16) {
                    Text(String(
                        format: "POSE %.1f fps", report.outputFPS
                    ))
                    Text(String(
                        format: "p95 gap %.0f ms",
                        report.p95DeliveryGapMilliseconds
                    ))
                }
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.semibold)
            } else {
                Text("Collecting pose callback intervals…")
                    .font(.caption)
            }
            Text("Local delivery estimate · not display FPS or camera latency")
                .font(.system(.caption2))
                .foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            .black.opacity(0.58),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .accessibilityElement(children: .combine)
    }

    private var trackingLabel: String {
        if model.isPaused { return "PAUSED" }
        switch model.phase {
        case .idle: return "PREPARING"
        case .permissionRequested: return "CAMERA ACCESS"
        case .permissionDenied: return "CAMERA OFF"
        case .unavailable: return "INTERRUPTED"
        case .searching, .partialTracking, .tracking:
            switch model.snapshot?.coverage ?? .none {
            case .none: return "SEARCHING"
            case .partial: return "PARTIAL"
            case .torsoAnchored: return "TRACKING"
            }
        }
    }

    private var statusIcon: String {
        if model.isPaused { return "pause.circle" }
        switch model.phase {
        case .permissionDenied, .unavailable: return "exclamationmark.circle"
        case .idle, .permissionRequested: return "camera"
        case .searching, .partialTracking, .tracking:
            return model.snapshot == nil ? "viewfinder" : "figure.stand"
        }
    }

@ViewBuilder
    private var guidance: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: model.isPaused ? "pause.circle" : "viewfinder")
                .font(.title3)
                .foregroundStyle(LeonardoPalette.ivory)
                .accessibilityHidden(true)

            Text(guidanceText)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.leading)
                .foregroundStyle(LeonardoPalette.ivory)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if case .permissionDenied = model.phase {
                Button("Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString)
                    else { return }
                    UIApplication.shared.open(url)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LeonardoPalette.ivory)
                .frame(minWidth: 64, minHeight: 44)
                .background(LeonardoPalette.verdigris, in: Capsule())
                .accessibilityHint("Open iOS Settings to enable camera permission")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(LeonardoPalette.cameraScrim.opacity(0.85),
                    in: RoundedRectangle(cornerRadius: 15))
        .accessibilityElement(children: .contain)
    }

    private var guidanceText: String {
        if model.isPaused { return "Overlay paused · camera still live" }
        switch model.phase {
        case .idle, .permissionRequested:
            return "Allow camera access to begin"
        case .searching:
            return "Point at one person\nShow shoulders or a visible limb"
        case .partialTracking:
            return "Partial skeleton tracking"
        case .tracking:
            return "Reference skeleton tracking"
        case .permissionDenied:
            return "Camera permission is required"
        case .unavailable(let message):
            return message
        }
    }

private var controls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("FOLIO · I")
                    .font(.system(size: 10, weight: .semibold, design: .serif))
                    .tracking(1.4)
                ManuscriptRule()
                Text("ANATOMIA")
                    .font(.system(size: 10, weight: .medium, design: .serif))
                    .tracking(1.1)
            }
            .foregroundStyle(LeonardoPalette.mutedInk)
            .accessibilityHidden(true)

            Picker("Body region", selection: $model.focus) {
                ForEach(AnatomyFocus.allCases) { region in
                    Text(region.rawValue).tag(region)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Reference skeleton body region")

            actionRow

            if showOpacity {
                HStack(spacing: 9) {
                    Text("Opacity")
                        .font(.caption.weight(.medium))
                    Slider(value: $model.opacity, in: 0.15...0.90)
                        .tint(LeonardoPalette.verdigris)
                        .accessibilityLabel("Skeleton opacity")
                    Text("\(Int(model.opacity * 100))%")
                        .font(.caption.monospacedDigit())
                        .frame(minWidth: 38, alignment: .trailing)
                }
                .accessibilityElement(children: .contain)
            }

            HStack(alignment: .center, spacing: 7) {
                Image(systemName: "info.circle")
                    .accessibilityHidden(true)
                Text("ILLUSTRATIVE REFERENCE · NOT YOUR REAL BONES")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.25)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(LeonardoPalette.mutedInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Illustrative reference proxy. Not your real bones or medical imaging."
            )
        }
        .foregroundStyle(LeonardoPalette.ink)
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            LeonardoPalette.parchment.opacity(0.97),
            in: RoundedRectangle(cornerRadius: 19)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 19)
                .strokeBorder(LeonardoPalette.copper.opacity(0.55),
                              lineWidth: 0.7)
                .allowsHitTesting(false)
        }
        .environment(\.colorScheme, .light)
    }

    @ViewBuilder
    private var actionRow: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 7) {
                layersButton
                opacityButton
                pauseButton
            }
        } else {
            HStack(spacing: 7) {
                layersButton
                opacityButton
                pauseButton
            }
        }
    }

    private var layersButton: some View {
        LeonardoActionButton("Layers", symbol: "square.3.layers.3d") {
            showLayers = true
        }
        .accessibilityHint("Open anatomy catalogue; unverified layers are unavailable")
    }

    private var opacityButton: some View {
        LeonardoActionButton(
            showOpacity ? "Hide slider" : "Opacity",
            symbol: "circle.lefthalf.filled"
        ) {
            if reduceMotion {
                showOpacity.toggle()
            } else {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showOpacity.toggle()
                }
            }
        }
        .accessibilityValue("\(Int(model.opacity * 100)) percent")
        .accessibilityHint("Expand or collapse the reference opacity slider")
    }

    private var pauseButton: some View {
        LeonardoActionButton(
            model.isPaused ? "Resume" : "Pause",
            symbol: model.isPaused ? "play.fill" : "pause.fill",
            emphasized: true
        ) {
            model.togglePause()
        }
        .accessibilityLabel(
            model.isPaused ? "Resume pose overlay" : "Pause pose overlay"
        )
    }
}

private struct LeonardoActionButton: View {
    let title: String
    let symbol: String
    var emphasized = false
    let action: () -> Void

    init(
        _ title: String, symbol: String,
        emphasized: Bool = false, action: @escaping () -> Void
    ) {
        self.title = title
        self.symbol = symbol
        self.emphasized = emphasized
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(emphasized
                    ? LeonardoPalette.ivory : LeonardoPalette.ink)
                .padding(.horizontal, 5)
                .background(
                    emphasized
                        ? LeonardoPalette.verdigris
                        : LeonardoPalette.agedPaper.opacity(0.60),
                    in: RoundedRectangle(cornerRadius: 11)
                )
        }
        .buttonStyle(.plain)
    }
}


}

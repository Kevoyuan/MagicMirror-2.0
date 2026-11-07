import SwiftUI
import UIKit

/// Camera-first native interface. MirrorLiveRenderSurface owns the high-
/// frequency frame observation; controls read stable phase and focus state.
struct MirrorScreen: View {
    private enum MirrorSheet: String, Identifiable {
        case anatomy
        case guide
        var id: String { rawValue }
    }

    @State private var model = MirrorViewModel()
    @State private var presentedSheet: MirrorSheet?
    @State private var showOpacity = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreview(session: model.pipeline.session)
                .ignoresSafeArea()

            MirrorLiveRenderSurface(model: model)
                .ignoresSafeArea()

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
                if presentation.guidanceForUser != nil {
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
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .anatomy:
                AnatomyLayersSheet(model: model)
            case .guide:
                MirrorGuideSheet(showDiagnostics: $model.showDiagnostics)
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    headerBrand
                    Spacer(minLength: 0)
                    fieldNotesButton
                }
                HStack {
                    trackingBadge
                    Spacer(minLength: 0)
                }
            }
            .accessibilityElement(children: .contain)
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    headerBrand
                    Spacer(minLength: 0)
                    fieldNotesButton
                    trackingBadge
                }
                HStack(spacing: 8) {
                    compactBrand
                    Spacer(minLength: 0)
                    fieldNotesButton
                    trackingBadge
                }
            }
            .frame(minHeight: 44)
            .accessibilityElement(children: .contain)
        }
    }

    private var headerBrand: some View {
        HStack(spacing: 7) {
            Image(systemName: "book.closed")
                .font(.caption)
                .accessibilityHidden(true)
            Text("MAGICMIRROR")
                .font(.system(.caption, design: .serif, weight: .bold))
                .tracking(0.6)
                .lineLimit(1)
        }
        .foregroundStyle(LeonardoPalette.ivory)
        .padding(.horizontal, 10)
        .frame(minHeight: 34)
        .background(LeonardoPalette.cameraScrim.opacity(0.7),
                    in: Capsule())
    }

    /// Compact brand fallback when larger localized status text would
    /// otherwise squeeze the camera controls on a narrow iPhone.
    private var compactBrand: some View {
        Text("MM")
            .font(.system(.caption, design: .serif, weight: .bold))
            .tracking(1)
            .foregroundStyle(LeonardoPalette.ivory)
            .frame(minWidth: 44, minHeight: 44)
            .background(LeonardoPalette.cameraScrim.opacity(0.7),
                        in: Circle())
            .accessibilityLabel("MagicMirror")
    }

    private var fieldNotesButton: some View {
        Button {
            presentedSheet = .guide
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.headline)
                .foregroundStyle(LeonardoPalette.ivory)
                .frame(width: 44, height: 44)
                .background(LeonardoPalette.cameraScrim.opacity(0.72),
                            in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open field notes and privacy guide")
    }

    private var trackingBadge: some View {
        Label(LocalizedStringKey(presentation.statusTitle),
              systemImage: presentation.statusSymbol)
            .font(.caption2.weight(.semibold))
            .tracking(0.3)
            .foregroundStyle(LeonardoPalette.ivory)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 10)
            .frame(minHeight: 34)
            .background(LeonardoPalette.cameraScrim.opacity(0.86),
                        in: Capsule())
            .accessibilityLabel(LocalizedStringKey(presentation.statusTitle))
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
            if let candidate = model.automaticCameraCandidate {
                Text(String(
                    format: "AUTO CAMERA candidate · %d joints · p90 %.1f%%",
                    candidate.landmarkCount,
                    candidate.p90ReprojectionErrorFractionOfWidth * 100
                ))
                .font(.system(.caption2, design: .monospaced))
            } else {
                Text("Auto camera fit: insufficient 3D / intrinsic evidence")
                    .font(.caption2)
            }
            Text("Unreviewed pose hypothesis · never anatomical calibration")
                .font(.system(.caption2))
                .foregroundStyle(.white.opacity(0.7))
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

    private var presentation: MirrorPresentationState {
        MirrorPresentationState(
            phase: model.phase,
            coverage: model.currentCoverage,
            isPaused: model.isPaused
        )
    }

    @ViewBuilder
    private var guidance: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: model.isPaused ? "pause.circle" : "viewfinder")
                .font(.title3)
                .foregroundStyle(LeonardoPalette.ivory)
                .accessibilityHidden(true)

            Text(LocalizedStringKey(presentation.guidanceForUser ?? ""))
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.leading)
                .foregroundStyle(LeonardoPalette.ivory)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if presentation.canOpenCameraSettings {
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
                    Text(LocalizedStringKey(region.rawValue)).tag(region)
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
                    Text(model.opacity, format: .percent)
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
            presentedSheet = .anatomy
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
        .accessibilityValue(Text(model.opacity, format: .percent))
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
            Label(LocalizedStringKey(title), systemImage: symbol)
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

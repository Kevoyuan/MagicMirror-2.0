import SwiftUI
import UIKit

/// Camera-first native interface. MirrorLiveRenderSurface owns the high-
/// frequency frame observation; controls read stable phase and focus state.
struct MirrorScreen: View {
    private enum MirrorSheet: Identifiable {
        case anatomy
        case guide
        case study(MirrorStudyNote)

        var id: String {
            switch self {
            case .anatomy: return "anatomy"
            case .guide: return "guide"
            case .study(let note): return "study-\(note.id)"
            }
        }
    }

    @State private var model = MirrorViewModel()
    @State private var presentedSheet: MirrorSheet?
    @State private var showAdjustments = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreview(session: model.pipeline.session)
                .ignoresSafeArea()

            MirrorLiveRenderSurface(model: model)
                .ignoresSafeArea()

            GeometryReader { geometry in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { event in
                        model.selectReference(
                            at: event.location, viewport: geometry.size
                        )
                    })
            }
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
                if let part = model.reviewedPartSelection {
                    selectionPreview(title: part.displayName) {
                        let education = AnatomyEducationCatalog.installed.note(
                            for: part,
                            language: locale.language.languageCode?.identifier ?? "en"
                        )
                        presentedSheet = .study(MirrorStudyNote(
                            title: education?.title ?? part.displayName,
                            summary: education?.summary ??
                                "Reviewed reference geometry. A camera image cannot measure your internal anatomy.",
                            function: education?.function,
                            authorCredit: education?.authorCredit,
                            isProxy: false
                        ))
                    }
                    .padding(.bottom, 8)
                } else if let selected = model.referenceSelection {
                    selectionPreview(title: selected.title) {
                        presentedSheet = .study(MirrorStudyNote(
                            title: selected.title,
                            summary: selected.explanation,
                            function: nil,
                            authorCredit: nil,
                            isProxy: true
                        ))
                    }
                    .padding(.bottom, 8)
                }
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
            case .study(let note):
                MirrorStudySheet(note: note)
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

    /// Selection is a small one-line invitation, never a large camera-blocking
    /// article. The full educational description lives in the study sheet.
    private func selectionPreview(
        title: String, onStudy: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.point.up.left")
                .foregroundStyle(LeonardoPalette.ivory)
                .accessibilityHidden(true)

            Text(LocalizedStringKey(title))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(LeonardoPalette.ivory)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Study", action: onStudy)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LeonardoPalette.ivory)
                .frame(minWidth: 58, minHeight: 44)
                .background(LeonardoPalette.verdigris,
                            in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHint("Open the selected anatomy reference note")

            Button {
                model.dismissReferenceSelection()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LeonardoPalette.ivory)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close anatomy detail")
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 4)
        .background(LeonardoPalette.cameraScrim.opacity(0.91),
                    in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
    }

    private var controls: some View {
        VStack(spacing: 8) {
            if showAdjustments {
                HStack(spacing: 8) {
                    Text("FOLIO · I")
                        .font(.system(.caption2, design: .serif, weight: .semibold))
                        .tracking(1)
                    ManuscriptRule()
                    Text("ANATOMIA")
                        .font(.system(.caption2, design: .serif))
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

                HStack(spacing: 9) {
                    Text("Opacity")
                        .font(.subheadline.weight(.medium))
                    Slider(value: $model.opacity, in: 0.15...0.90)
                        .tint(LeonardoPalette.verdigris)
                        .accessibilityLabel("Skeleton opacity")
                    Text(model.opacity, format: .percent)
                        .font(.caption.monospacedDigit())
                        .frame(minWidth: 38, alignment: .trailing)
                }
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 7) {
                    HStack(spacing: 7) {
                        regionMenu
                        layersButton
                    }
                    HStack(spacing: 7) {
                        pauseButton
                        adjustmentsButton
                    }
                }
            } else {
                HStack(spacing: 7) {
                    regionMenu
                    layersButton
                    pauseButton
                    adjustmentsButton
                }
            }

            HStack(alignment: .center, spacing: 7) {
                Image(systemName: "info.circle")
                    .accessibilityHidden(true)
                Text("ILLUSTRATIVE REFERENCE · NOT YOUR REAL BONES")
                    .font(.caption2.weight(.medium))
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            LeonardoPalette.parchment.opacity(0.97),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(LeonardoPalette.copper.opacity(0.48),
                              lineWidth: 0.7)
                .allowsHitTesting(false)
        }
        .environment(\.colorScheme, .light)
    }

    /// Whole / Arms / Legs stay available from the collapsed camera dock.
    /// The menu is a native, accessible control, not a custom gesture.
    private var regionMenu: some View {
        Menu {
            ForEach(AnatomyFocus.allCases) { region in
                Button {
                    model.focus = region
                } label: {
                    if model.focus == region {
                        Label(LocalizedStringKey(region.rawValue),
                              systemImage: "checkmark")
                    } else {
                        Text(LocalizedStringKey(region.rawValue))
                    }
                }
            }
        } label: {
            Label(LocalizedStringKey(model.focus.rawValue),
                  systemImage: "figure.stand")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(LeonardoPalette.ink)
                .padding(.horizontal, 3)
                .background(LeonardoPalette.agedPaper.opacity(0.60),
                            in: RoundedRectangle(cornerRadius: 11))
        }
        .accessibilityLabel("Body region")
        .accessibilityValue(LocalizedStringKey(model.focus.rawValue))
        .accessibilityHint("Choose whole body, arms or legs")
    }

    private var layersButton: some View {
        LeonardoActionButton("Layers", symbol: "square.3.layers.3d") {
            presentedSheet = .anatomy
        }
        .accessibilityHint("Open anatomy catalogue; unverified layers are unavailable")
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

    private var adjustmentsButton: some View {
        Button {
            if reduceMotion {
                showAdjustments.toggle()
            } else {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showAdjustments.toggle()
                }
            }
        } label: {
            Image(systemName: showAdjustments
                  ? "chevron.down" : "slider.horizontal.3")
                .font(.headline)
                .foregroundStyle(LeonardoPalette.ink)
                .frame(width: 44, height: 44)
                .background(LeonardoPalette.agedPaper.opacity(0.60),
                            in: RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showAdjustments
            ? "Hide mirror adjustments" : "Show mirror adjustments")
        .accessibilityAddTraits(showAdjustments ? [.isSelected] : [])
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

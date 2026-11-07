import SwiftUI
import UIKit

/// One-screen phone experience. Only PoseSkeletonOverlay reads 30 Hz pose
/// updates; labels/controls read stable phase and opacity independently.
struct MirrorScreen: View {
    @State private var model = MirrorViewModel()
    @State private var showLayers = false
    @State private var showOpacity = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreview(session: model.pipeline.session)
                .ignoresSafeArea()

            MetalSkeletonOverlay(
                alignedFrame: model.isPaused ? nil : model.alignedFrame,
                opacity: model.opacity, focus: model.focus
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    .black.opacity(0.52), .clear,
                    .clear, .black.opacity(0.66)
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
                        .padding(.bottom, 10)
                }
                controls
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 8)
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
        HStack(spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "book.closed")
                    .font(.caption)
                    .accessibilityHidden(true)
                Text("MAGICMIRROR")
                    .font(.system(.caption, design: .serif, weight: .bold))
                    .tracking(1.1)
            }
            .foregroundStyle(Color(red: 0.96, green: 0.92, blue: 0.83))
            .lineLimit(1)

            Spacer(minLength: 4)

            Button {
                model.toggleDiagnostics()
            } label: {
                Image(systemName: "waveform.path.ecg")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(model.showDiagnostics
                        ? Color(red: 0.74, green: 0.93, blue: 0.83)
                        : .white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.42), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.showDiagnostics
                ? "Hide local pose delivery diagnostics"
                : "Show local pose delivery diagnostics")

            Text(trackingLabel)
                .font(.caption2.weight(.bold))
                .tracking(0.6)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(
                    Color(red: 0.09, green: 0.12, blue: 0.11)
                        .opacity(0.84), in: Capsule()
                )
                .accessibilityAddTraits(.updatesFrequently)
        }
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
        switch model.snapshot?.coverage ?? .none {
        case .none: return "SEARCHING"
        case .partial: return "PARTIAL"
        case .torsoAnchored: return "TRACKING"
        }
    }

    @ViewBuilder
    private var guidance: some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.stand")
                .font(.system(size: 34, weight: .ultraLight))
                .foregroundStyle(.cyan.opacity(0.92))

            Text(guidanceText)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            if case .permissionDenied = model.phase {
                Button("Open Camera Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString)
                    else { return }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .accessibilityHint("Open system settings to allow camera access")
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 22))
        .accessibilityElement(children: .contain)
    }

    private var guidanceText: String {
        if model.isPaused { return "Tracking paused" }
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
        VStack(spacing: 10) {
            Picker("Body region", selection: $model.focus) {
                ForEach(AnatomyFocus.allCases) { region in
                    Text(region.rawValue).tag(region)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Reference skeleton body region")

            HStack(spacing: 8) {
                Button {
                    showLayers = true
                } label: {
                    Label("Layers", systemImage: "square.3.layers.3d")
                        .frame(minHeight: 44)
                        .frame(maxWidth: .infinity)
                }
                .accessibilityHint("Shows current proxy and unavailable anatomical layers")

                Button {
                    showOpacity.toggle()
                } label: {
                    Label("Opacity", systemImage: "circle.lefthalf.filled")
                        .frame(minHeight: 44)
                        .frame(maxWidth: .infinity)
                }
                .accessibilityValue("\(Int(model.opacity * 100)) percent")
                .accessibilityHint("Expand or collapse skeleton opacity slider")

                Button {
                    model.togglePause()
                } label: {
                    Label(model.isPaused ? "Resume" : "Pause",
                          systemImage: model.isPaused ? "play.fill" : "pause.fill")
                        .frame(minHeight: 44)
                        .frame(maxWidth: .infinity)
                }
                .accessibilityLabel(
                    model.isPaused ? "Resume pose overlay" : "Pause pose overlay"
                )
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.bordered)
            .tint(Color(red: 0.22, green: 0.40, blue: 0.36))

            if showOpacity {
                HStack(spacing: 8) {
                    Text("Skeleton opacity")
                        .font(.caption)
                    Slider(value: $model.opacity, in: 0.15...0.90)
                        .tint(Color(red: 0.22, green: 0.40, blue: 0.36))
                        .accessibilityLabel("Skeleton opacity")
                    Text("\(Int(model.opacity * 100))%")
                        .font(.caption.monospacedDigit())
                }
                .accessibilityElement(children: .contain)
            }

            Text("ILLUSTRATIVE 3D REFERENCE · NOT YOUR REAL BONES")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(Color(red: 0.28, green: 0.25, blue: 0.22))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(
                    "Illustrative 3D reference proxy. Not medical imaging or your real bones."
                )
        }
        .foregroundStyle(Color(red: 0.20, green: 0.18, blue: 0.15))
        .padding(12)
        .background(
            Color(red: 0.953, green: 0.922, blue: 0.867).opacity(0.94),
            in: RoundedRectangle(cornerRadius: 20)
        )
    }
}

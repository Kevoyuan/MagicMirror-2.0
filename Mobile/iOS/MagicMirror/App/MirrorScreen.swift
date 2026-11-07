import SwiftUI
import UIKit

/// One-screen phone experience. Only PoseSkeletonOverlay reads 30 Hz pose
/// updates; labels/controls read stable phase and opacity independently.
struct MirrorScreen: View {
    @State private var model = MirrorViewModel()
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
                        .padding(.bottom, 22)
                }
                controls
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 20)
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
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("MAGICMIRROR")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .tracking(2.2)
                Text("3D PROXY BONES · ON DEVICE")
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .tracking(0.9)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Button {
                model.toggleDiagnostics()
            } label: {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(.subheadline, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .foregroundStyle(
                        model.showDiagnostics ? Color.cyan : Color.white
                    )
                    .background(.black.opacity(0.44), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                model.showDiagnostics
                    ? "Hide local pose delivery diagnostics"
                    : "Show local pose delivery diagnostics"
            )
            .padding(.trailing, 7)
            Label(
                trackingLabel,
                systemImage: model.snapshot == nil
                    ? "viewfinder" : "checkmark.circle.fill"
            )
            .font(.caption2.weight(.bold))
            .foregroundStyle(
                model.snapshot == nil ? Color.white : Color.cyan
            )
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(.black.opacity(0.44), in: Capsule())
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
        .padding(.vertical, 24)
        .padding(.horizontal, 26)
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
        VStack(spacing: 16) {
            Picker("Body region", selection: $model.focus) {
                ForEach(AnatomyFocus.allCases) { region in
                    Text(region.rawValue).tag(region)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Reference skeleton body region")

            HStack {
                Image(systemName: "circle.lefthalf.filled")
                    .foregroundStyle(.cyan)
                    .accessibilityHidden(true)
                Text("Skeleton opacity")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(Int(model.opacity * 100))%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.78))
            }
            Slider(value: $model.opacity, in: 0.15...0.90)
                .tint(.cyan)
                .accessibilityLabel("Skeleton opacity")
                .accessibilityValue("\(Int(model.opacity * 100)) percent")

            HStack(spacing: 12) {
                Text("3D REFERENCE PROXY · NOT YOUR REAL BONES")
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.64))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Spacer()

                Button {
                    model.togglePause()
                } label: {
                    Label(
                        model.isPaused ? "Resume" : "Pause",
                        systemImage: model.isPaused ? "play.fill" : "pause.fill"
                    )
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.black.opacity(0.78))
                .foregroundStyle(.white)
                .accessibilityLabel(
                    model.isPaused ? "Resume pose overlay" : "Pause pose overlay"
                )
            }
        }
        .padding(19)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 24))
    }
}

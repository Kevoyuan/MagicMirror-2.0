import SwiftUI

/// Optional native reference folio. It never gates the camera or creates a
/// second capture session; it provides contextual help, privacy and research
/// limitations without adding a multi-tab application shell.
struct MirrorGuideSheet: View {
    @Binding var showDiagnostics: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var page: GuidePage = .using

    private enum GuidePage: String, CaseIterable, Identifiable {
        case using = "Use"
        case privacy = "Privacy"
        case about = "About"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heading

                    Picker("Guide section", selection: $page) {
                        ForEach(GuidePage.allCases) { page in
                            Text(page.rawValue).tag(page)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Select guide, privacy, or about")

                    switch page {
                    case .using: usagePage
                    case .privacy: privacyPage
                    case .about: aboutPage
                    }

                    ManuscriptRule()

                    Text("AN EDUCATIONAL REFERENCE · NEVER A PERSONAL X-RAY")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(LeonardoPalette.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
                .frame(maxWidth: 600, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(LeonardoPalette.parchment.ignoresSafeArea())
            .navigationTitle("Field notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(LeonardoPalette.verdigris)
                }
            }
        }
        .tint(LeonardoPalette.verdigris)
        .preferredColorScheme(.light)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("LEONARDO · STUDIO")
                    .foregroundStyle(LeonardoPalette.copper)
                Spacer()
                Text("FOLIO · III")
                    .foregroundStyle(LeonardoPalette.mutedInk)
            }
            .font(.system(.caption, design: .serif, weight: .semibold))
            .tracking(1.3)
            .accessibilityHidden(true)

            Text("The observer's notes")
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(LeonardoPalette.ink)
                .accessibilityAddTraits(.isHeader)

            Text("A guide to moving, seeing and understanding the reference figure.")
                .font(.subheadline)
                .foregroundStyle(LeonardoPalette.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            ManuscriptRule().padding(.top, 4)
        }
    }

    private var usagePage: some View {
        VStack(alignment: .leading, spacing: 13) {
            guideSectionTitle("START AN OBSERVATION", systemImage: "viewfinder")
            instructionRow(
                number: "01",
                title: "Point the rear camera at one person",
                detail: "A visible arm or shoulder span can begin partial tracking. Full torso alignment requires the shoulders and hips."
            )
            instructionRow(
                number: "02",
                title: "Move naturally",
                detail: "The translucent reference follows only sufficiently visible landmarks. Missing parts may disappear."
            )
            instructionRow(
                number: "03",
                title: "Select a body region",
                detail: "Whole, Arms and Legs change the visible region. This is different from anatomical system layers."
            )
            instructionRow(
                number: "04",
                title: "Explore the paper controls",
                detail: "Opacity adjusts the reference; Pause hides the overlay but keeps the camera preview live."
            )

            VStack(alignment: .leading, spacing: 8) {
                guideSectionTitle("ANATOMY SYSTEMS", systemImage: "square.3.layers.3d")
                Text("The Layers folio describes planned anatomy systems and section planes. Only the illustrative reference proxy is currently selectable; reviewed multi-system 3D assets are not bundled.")
                    .font(.subheadline)
                    .foregroundStyle(LeonardoPalette.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
        }
    }

    private var privacyPage: some View {
        VStack(alignment: .leading, spacing: 13) {
            guideSectionTitle("CAMERA AND PRIVACY", systemImage: "hand.raised")
            noteRow(
                icon: "iphone",
                title: "Processed on this iPhone",
                detail: "Pose detection uses a bundled MediaPipe model. The current app has no cloud inference or account requirement."
            )
            noteRow(
                icon: "camera",
                title: "Camera only when in use",
                detail: "Access is requested through iOS. The camera session stops when the app leaves the foreground."
            )
            noteRow(
                icon: "externaldrive",
                title: "No automatic recording",
                detail: "The current app does not save, upload or share camera frames, pose history or screenshots."
            )
            noteRow(
                icon: "hand.raised",
                title: "You control permission",
                detail: "Change Camera access in iOS Settings. If permission is denied, the mirror shows a recovery message."
            )
            Text("These statements describe the current app source. Third-party SDK privacy manifests and actual App Store declarations still need release review.")
                .font(.footnote)
                .foregroundStyle(LeonardoPalette.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var aboutPage: some View {
        VStack(alignment: .leading, spacing: 13) {
            guideSectionTitle("WHAT THE MIRROR SHOWS", systemImage: "book.closed")
            noteRow(
                icon: "figure.stand",
                title: "An illustrative skeleton",
                detail: "The visible proxy is derived from estimated body-surface pose landmarks, not from a scan of your internal bones."
            )
            noteRow(
                icon: "lock.shield",
                title: "Reviewed anatomy comes later",
                detail: "Z-Anatomy-derived muscles, organs, vessels, nerves and bone meshes require source-rights and anatomical review before distribution."
            )
            noteRow(
                icon: "cross.case",
                title: "Not a medical tool",
                detail: "MagicMirror is for educational exploration. Do not use it to assess injuries, diagnose conditions or measure actual skeletal geometry."
            )

            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $showDiagnostics) {
                    Label("Show local tracking diagnostics", systemImage: "waveform.path.ecg")
                        .font(.subheadline.weight(.semibold))
                }
                .tint(LeonardoPalette.verdigris)

                Text("Displays pose callback cadence and delivery gaps, not verified camera FPS, total latency or anatomical accuracy.")
                    .font(.footnote)
                    .foregroundStyle(LeonardoPalette.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(13)
            .background(LeonardoPalette.agedPaper.opacity(0.48),
                        in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func guideSectionTitle(
        _ title: String, systemImage: String
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .tracking(1.0)
            .foregroundStyle(LeonardoPalette.verdigris)
            .accessibilityAddTraits(.isHeader)
    }

    private func instructionRow(
        number: String, title: String, detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Text(number)
                .font(.system(.headline, design: .serif))
                .foregroundStyle(LeonardoPalette.copper)
                .frame(width: 29, alignment: .leading)
                .accessibilityHidden(true)
            noteBody(title: title, detail: detail)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private func noteRow(
        icon: String, title: String, detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(LeonardoPalette.verdigris)
                .frame(width: 29, alignment: .leading)
                .accessibilityHidden(true)
            noteBody(title: title, detail: detail)
        }
        .padding(12)
        .background(LeonardoPalette.ivory.opacity(0.46),
                    in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func noteBody(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LeonardoPalette.ink)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(LeonardoPalette.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

import SwiftUI

/// A living anatomical notebook, shown over the unchanged camera session.
/// Real multi-system toggles and mesh sectioning remain gated until their
/// independently reviewed 3D resources and native renderer actually exist.
struct AnatomyLayersSheet: View {
    @Bindable var model: MirrorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var page: NotebookPage = .systems

    private enum NotebookPage: String, CaseIterable, Identifiable {
        case systems = "Systems"
        case sections = "Sections"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    manuscriptHeader

                    Picker("Anatomy study", selection: $page) {
                        ForEach(NotebookPage.allCases) { item in
                            Text(LocalizedStringKey(item.rawValue)).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Choose anatomical systems or section planes")

                    if page == .systems {
                        systemStudies
                    } else {
                        sectionStudies
                    }

                    ManuscriptRule()

                    Label(
                        "Educational reference only · not medical imaging",
                        systemImage: "info.circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(LeonardoPalette.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
                }
                .padding(.horizontal, 19)
                .padding(.top, 18)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .background(LeonardoPalette.parchment.ignoresSafeArea())
            .navigationTitle("Anatomy folio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(LeonardoPalette.verdigris)
                        .accessibilityLabel("Close anatomy notebook")
                }
            }
        }
        .tint(LeonardoPalette.verdigris)
        .preferredColorScheme(.light)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var manuscriptHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("STUDI DI ANATOMIA")
                    .font(.system(size: 11, weight: .semibold, design: .serif))
                    .tracking(2.0)
                    .foregroundStyle(LeonardoPalette.copperInk)
                Spacer(minLength: 8)
                Text("FOLIO · II")
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .tracking(1.3)
                    .foregroundStyle(LeonardoPalette.mutedInk)
            }

            Text("The anatomy notebook")
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(LeonardoPalette.ink)

            Text("Explore six separately reviewed anatomical systems as their approved offline resources become available. The illustrative reference proxy remains the fallback.")
                .font(.subheadline)
                .foregroundStyle(LeonardoPalette.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            ManuscriptRule()
                .padding(.top, 2)
        }
    }

    private var systemStudies: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "square.3.layers.3d")
                    .foregroundStyle(LeonardoPalette.verdigris)
                Text("ANATOMICAL SYSTEMS")
                    .font(.caption.weight(.semibold))
                    .tracking(1.1)
            }
            .foregroundStyle(LeonardoPalette.ink)

            Text("Tap a verified system to display it. Only independently reviewed, camera-registered 3D resources unlock; unavailable systems remain locked.")
                .font(.footnote)
                .foregroundStyle(LeonardoPalette.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(AnatomyDisplayLayer.allCases) { layer in
                layerRow(layer)
            }
        }
    }

    private func layerRow(_ layer: AnatomyDisplayLayer) -> some View {
        let available = model.canSelectAnatomyLayer(layer)
        let selected = model.selectedAnatomyLayer == layer
        return Button {
            model.selectAnatomyLayer(layer)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: layerSymbol(layer))
                    .font(.title3)
                    .foregroundStyle(available
                        ? LeonardoPalette.verdigris
                        : LeonardoPalette.mutedInk)
                    .frame(width: 30, height: 44)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(layer.title))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LeonardoPalette.ink)
                    Text(LocalizedStringKey(layer.detail))
                        .font(.caption)
                        .foregroundStyle(LeonardoPalette.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 3)

                VStack(spacing: 4) {
                    Image(systemName: available
                        ? (selected ? "checkmark.circle.fill" : "circle")
                        : "lock.fill")
                        .font(.subheadline)
                    Text(available
                        ? (selected ? "SELECTED" : "READY") : "LOCKED")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.5)
                }
                .foregroundStyle(available
                    ? LeonardoPalette.verdigris
                    : LeonardoPalette.mutedInk)
                .frame(minWidth: 63)
                .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                available
                    ? LeonardoPalette.agedPaper.opacity(0.50)
                    : LeonardoPalette.ivory.opacity(0.43),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(LeonardoPalette.copper.opacity(0.26),
                                  lineWidth: 0.7)
            }
        }
        .buttonStyle(.plain)
        .disabled(!available)
        .accessibilityLabel(layer.title)
        .accessibilityHint(available
            ? "Select an educational 3D reference system"
            : "Requires independently reviewed and registered anatomy")
    }

    private var sectionStudies: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "square.stack.3d.up")
                    .foregroundStyle(LeonardoPalette.verdigris)
                Text("STUDIES IN SECTION")
                    .font(.caption.weight(.semibold))
                    .tracking(1.1)
            }
            .foregroundStyle(LeonardoPalette.ink)

            Text(model.canSectionReviewedAtlas
                ? "3D surface section clipping is available for the reviewed and registered skinned atlas. This shows cut surfaces without generating anatomical cross-section caps."
                : "3D surface section controls unlock only when a reviewed, registered, GPU-skinned atlas is actually available. A drawn guide line is not a real cut.")
                .font(.subheadline)
                .foregroundStyle(LeonardoPalette.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            if model.canSectionReviewedAtlas {
                Button("Show complete reference atlas") {
                    model.activeSection = nil
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Disable the 3D half-space cut")
            }
            ForEach(AnatomySectionPlane.allCases) { plane in
                Button {
                    guard model.canSectionReviewedAtlas else { return }
                    model.activeSection = plane
                } label: {
                HStack(spacing: 14) {
                    sectionDiagram(plane)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(LocalizedStringKey(plane.title))
                            .font(.system(.headline, design: .serif))
                        Text(LocalizedStringKey(sectionExplanation(plane)))
                            .font(.caption)
                            .foregroundStyle(LeonardoPalette.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    VStack(spacing: 4) {
                        Image(systemName: model.canSectionReviewedAtlas
                            ? (model.activeSection == plane
                                ? "checkmark.circle.fill" : "circle")
                            : "lock.fill")
                            .font(.caption)
                            .accessibilityHidden(true)
                        Text(model.canSectionReviewedAtlas
                            ? (model.activeSection == plane ? "ACTIVE" : "SELECT")
                            : "LOCKED")
                            .font(.system(.caption2, weight: .semibold))
                    }
                    .foregroundStyle(LeonardoPalette.mutedInk)
                }
                .foregroundStyle(LeonardoPalette.ink)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LeonardoPalette.ivory.opacity(0.48),
                            in: RoundedRectangle(cornerRadius: 12))
                .accessibilityElement(children: .combine)
                }
                .buttonStyle(.plain)
                .disabled(!model.canSectionReviewedAtlas)
                .accessibilityHint(model.canSectionReviewedAtlas
                    ? "Apply the selected half-space clip to the registered atlas"
                    : "Requires independently reviewed anatomy and camera registration")
            }

            if model.canSectionReviewedAtlas, model.activeSection != nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Section offset · shoulder-width units")
                        .font(.caption)
                    Slider(value: $model.sectionOffset, in: -0.5...0.5)
                        .accessibilityLabel("Move anatomy section plane")
                    Text("Only the visible mesh surface is clipped; no watertight cut face or tissue reconstruction")
                        .font(.caption2)
                        .foregroundStyle(LeonardoPalette.mutedInk)
                }
            }

            Text(model.canSectionReviewedAtlas
                ? "GPU 3D SURFACE CLIPPING · REFERENCE GEOMETRY ONLY"
                : "NO REGISTERED ATLAS AVAILABLE FOR CUTTING")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(LeonardoPalette.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionDiagram(_ plane: AnatomySectionPlane) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(LeonardoPalette.copper.opacity(0.58),
                              lineWidth: 0.8)
            Ellipse()
                .stroke(LeonardoPalette.mutedInk.opacity(0.65),
                        lineWidth: 1)
                .frame(width: 29, height: 39)
            Rectangle()
                .fill(LeonardoPalette.verdigris.opacity(0.88))
                .frame(
                    width: plane == .sagittal ? 2 : 32,
                    height: plane == .sagittal ? 39
                        : (plane == .axial ? 2 : 20)
                )
                .rotationEffect(plane == .coronal ? .degrees(90) : .zero)
        }
        .frame(width: 54, height: 54)
        .accessibilityHidden(true)
    }

    private func sectionExplanation(_ plane: AnatomySectionPlane) -> String {
        switch plane {
        case .axial: return "Transverse · upper and lower portions"
        case .sagittal: return "Divides left and right portions"
        case .coronal: return "Divides front and back portions"
        }
    }

    private func layerSymbol(_ layer: AnatomyDisplayLayer) -> String {
        switch layer {
        case .referenceProxy: return "figure.stand"
        case .skeleton: return "figure.arms.open"
        case .muscles: return "figure.strengthtraining.traditional"
        case .organs: return "heart.text.square"
        case .vessels: return "waveform.path.ecg"
        case .nerves: return "point.3.connected.trianglepath.dotted"
        case .joints: return "figure.flexibility"
        }
    }
}

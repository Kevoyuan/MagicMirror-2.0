import SwiftUI

/// A living anatomical notebook, shown over the unchanged camera session.
/// Real multi-system toggles and mesh sectioning remain gated until their
/// independently reviewed 3D resources and native renderer actually exist.
struct AnatomyLayersSheet: View {
    @Bindable var model: MirrorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var page: NotebookPage = .systems
    @State private var showLayerExplanation = false
    @State private var showSectionExplanation = false

    private enum NotebookPage: String, CaseIterable, Identifiable {
        case systems = "Systems"
        case sections = "Sections"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
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

    /// The first useful layer must be visible at the medium sheet detent:
    /// keep editorial branding in one line and avoid a decorative title card.
    private var manuscriptHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("STUDI DI ANATOMIA")
                    .font(.system(.caption2, design: .serif, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(LeonardoPalette.copperInk)

                Text("The anatomy notebook")
                    .font(.system(.headline, design: .serif, weight: .semibold))
                    .foregroundStyle(LeonardoPalette.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 8)
            Text("FOLIO · II")
                .font(.system(.caption2, design: .serif))
                .tracking(0.8)
                .foregroundStyle(LeonardoPalette.mutedInk)
                .accessibilityHidden(true)
        }
    }

    private var systemStudies: some View {
        let visibleSystems = model.enabledAnatomyLayers
            .intersection(model.readyAnatomyLayers)
        let readySystems = model.readyAnatomyLayers.filter {
            $0 != .referenceProxy
        }
        return VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 10) {
                Image(systemName: visibleSystems.isEmpty
                      ? "figure.stand" : "square.stack.3d.up.fill")
                    .font(.title3)
                    .foregroundStyle(LeonardoPalette.verdigris)
                    .frame(width: 32)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(visibleSystems.isEmpty
                         ? "Reference proxy on camera"
                         : "Reviewed systems selected")
                        .font(.subheadline.weight(.semibold))
                    Text(visibleSystems.isEmpty
                         ? "Only the pose-driven reference is visible"
                         : "Only currently registered meshes are counted")
                        .font(.caption)
                        .foregroundStyle(LeonardoPalette.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                if !visibleSystems.isEmpty {
                    Button("Reset") {
                        model.selectAnatomyLayer(.referenceProxy)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LeonardoPalette.verdigris)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityHint("Return to the illustrative pose reference")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LeonardoPalette.agedPaper.opacity(0.45),
                        in: RoundedRectangle(cornerRadius: 13))
            .accessibilityElement(children: .contain)

            ForEach(AnatomyDisplayLayer.allCases) { layer in
                layerRow(layer)
            }

            DisclosureGroup(
                "How anatomy layers work",
                isExpanded: $showLayerExplanation
            ) {
                Text("Select more than one registered system, or use Solo to view one alone. Locked models are not installed and registered.")
                    .font(.footnote)
                    .foregroundStyle(LeonardoPalette.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 7)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(LeonardoPalette.verdigris)
            .padding(.vertical, 4)
        }
    }

    private func layerRow(_ layer: AnatomyDisplayLayer) -> some View {
        let presentation = AnatomyLayerPresentation(
            layer: layer,
            enabled: model.enabledAnatomyLayers,
            ready: model.readyAnatomyLayers
        )
        let available = presentation.available
        let selected = presentation.selected
        return VStack(alignment: .leading, spacing: 5) {
        Button {
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
                    Text(LocalizedStringKey(
                        available && layer != .referenceProxy
                            ? "Registered approved local reference mesh"
                            : layer.detail
                    ))
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
                    Text(LocalizedStringKey(
                        presentation.statusKey
                    ))
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
        .accessibilityLabel(LocalizedStringKey(layer.title))
        .accessibilityValue(LocalizedStringKey(
            presentation.statusKey
        ))
        .accessibilityHint(LocalizedStringKey(
            available ? (layer == .referenceProxy
                ? "Hide the anatomical systems and use the reference proxy"
                : "Toggle this reviewed anatomical system")
            : "Requires independently reviewed and registered anatomy"
        ))

        if available, layer != .referenceProxy {
            let isAlreadySolo = model.enabledAnatomyLayers
                .intersection(model.readyAnatomyLayers) == Set([layer])

            HStack(spacing: 9) {
                if selected {
                    Text("Opacity")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(LeonardoPalette.mutedInk)
                    Slider(
                        value: Binding(
                            get: { model.layerOpacity(layer) },
                            set: { model.setLayerOpacity(layer, $0) }
                        ),
                        in: 0.05...1
                    )
                    .tint(LeonardoPalette.verdigris)
                    .accessibilityLabel("Layer opacity")
                    .accessibilityHint(LocalizedStringKey(layer.title))
                    Text(model.layerOpacity(layer), format: .percent)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(LeonardoPalette.mutedInk)
                        .frame(minWidth: 40, alignment: .trailing)
                } else {
                    Spacer(minLength: 0)
                }

                Button("Solo") {
                    model.soloAnatomyLayer(layer)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LeonardoPalette.verdigris)
                .frame(minWidth: 44, minHeight: 44)
                .disabled(isAlreadySolo)
                .accessibilityHint("Show only this registered anatomy system")
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 5)
        }
        }
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

            Label(
                model.canSectionReviewedAtlas
                    ? "Surface clipping available"
                    : "Requires registered 3D anatomy",
                systemImage: model.canSectionReviewedAtlas
                    ? "checkmark.circle" : "lock"
            )
            .font(.footnote.weight(.medium))
            .foregroundStyle(LeonardoPalette.mutedInk)
            .fixedSize(horizontal: false, vertical: true)

            if model.canSectionReviewedAtlas, model.activeSection != nil {
                Button("Show complete reference atlas") {
                    model.activeSection = nil
                    model.sectionOffset = 0
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
                        Text(LocalizedStringKey(model.canSectionReviewedAtlas
                            ? (model.activeSection == plane ? "ACTIVE" : "SELECT")
                            : "LOCKED"))
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
                .accessibilityValue(LocalizedStringKey(model.canSectionReviewedAtlas
                    ? (model.activeSection == plane ? "ACTIVE" : "SELECT")
                    : "LOCKED"))
                .accessibilityHint(LocalizedStringKey(model.canSectionReviewedAtlas
                    ? "Apply the selected half-space clip to the registered atlas"
                    : "Requires independently reviewed anatomy and camera registration"))
            }

            if model.canSectionReviewedAtlas, model.activeSection != nil {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Section offset · shoulder-width units")
                            .font(.caption)
                        Spacer(minLength: 5)
                        Text(model.sectionOffset, format: .number.precision(
                            .fractionLength(2)))
                            .font(.caption.monospacedDigit())
                    }
                    Slider(value: $model.sectionOffset, in: -0.5...0.5)
                        .tint(LeonardoPalette.verdigris)
                        .accessibilityLabel("Move anatomy section plane")
                    Button("Center plane") {
                        model.sectionOffset = 0
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .disabled(abs(model.sectionOffset) < 0.001)
                    .accessibilityHint("Reset the section plane to its center")
                    Text("Only the visible mesh surface is clipped; no watertight cut face or tissue reconstruction")
                        .font(.caption2)
                        .foregroundStyle(LeonardoPalette.mutedInk)
                }
            }

            DisclosureGroup(
                "What do section planes show?",
                isExpanded: $showSectionExplanation
            ) {
                Text(LocalizedStringKey(model.canSectionReviewedAtlas
                    ? "3D surface section clipping is available for the reviewed and registered skinned atlas. This shows cut surfaces without generating anatomical cross-section caps."
                    : "3D surface section controls unlock only when a reviewed, registered, GPU-skinned atlas is actually available. A drawn guide line is not a real cut."))
                    .font(.footnote)
                    .foregroundStyle(LeonardoPalette.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 7)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(LeonardoPalette.verdigris)
            .padding(.vertical, 4)

            Text(LocalizedStringKey(model.canSectionReviewedAtlas
                ? "GPU 3D SURFACE CLIPPING · REFERENCE GEOMETRY ONLY"
                : "NO REGISTERED ATLAS AVAILABLE FOR CUTTING"))
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

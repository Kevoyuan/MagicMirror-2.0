import SwiftUI

/// Informational native sheet. It intentionally does not offer toggles for
/// missing Z-Anatomy meshes or decorative clipping controls.
struct AnatomyLayersSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let paper = Color(red: 0.953, green: 0.922, blue: 0.867)
    private let ink = Color(red: 0.20, green: 0.176, blue: 0.153)
    private let mutedInk = Color(red: 0.455, green: 0.408, blue: 0.353)
    private let green = Color(red: 0.22, green: 0.404, blue: 0.365)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Only the illustrative reference proxy is currently rendered. Other layers remain unavailable until source licensing, anatomy review and camera alignment are verified.")
                        .font(.subheadline)
                        .foregroundStyle(mutedInk)

                    VStack(spacing: 0) {
                        ForEach(AnatomyDisplayLayer.allCases) { layer in
                            HStack(spacing: 12) {
                                Image(systemName: layer.isAvailable
                                      ? "checkmark.circle.fill" : "lock")
                                    .foregroundStyle(layer.isAvailable ? green : mutedInk)
                                    .frame(width: 22)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(layer.title).font(.subheadline.weight(.semibold))
                                    Text(layer.detail)
                                        .font(.caption)
                                        .foregroundStyle(mutedInk)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 4)
                                Text(layer.isAvailable ? "Current" : "Planned")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(layer.isAvailable ? green : mutedInk)
                            }
                            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                            .padding(.vertical, 8)
                            .accessibilityElement(children: .combine)
                            if layer != AnatomyDisplayLayer.allCases.last {
                                Divider().overlay(mutedInk.opacity(0.2))
                            }
                        }
                    }

                    Divider()
                    Text("Section planes")
                        .font(.headline)
                    Text("Axial, sagittal and coronal sections require a verified 3D mesh and real clipping. No slices are available in this prototype.")
                        .font(.subheadline)
                        .foregroundStyle(mutedInk)
                    HStack {
                        ForEach(AnatomySectionPlane.allCases) { plane in
                            Text(plane.title)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(ink.opacity(0.06), in: Capsule())
                                .accessibilityLabel("\(plane.title), not available")
                        }
                    }
                    .accessibilityElement(children: .contain)
                    Text("Educational reference only · not medical imaging")
                        .font(.caption)
                        .foregroundStyle(mutedInk)
                }
                .foregroundStyle(ink)
                .padding(20)
            }
            .background(paper.ignoresSafeArea())
            .navigationTitle("Anatomy layers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(green)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

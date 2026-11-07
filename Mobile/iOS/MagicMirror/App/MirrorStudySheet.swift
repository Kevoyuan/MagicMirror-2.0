import SwiftUI

/// Stable reading snapshot captured when someone explicitly opens a selected
/// reference part. Camera/pose updates may continue behind the sheet without
/// discarding the educational note or implying new anatomical measurements.
struct MirrorStudyNote: Identifiable {
    let id = UUID()
    let title: String
    let summary: String
    let function: String?
    let authorCredit: String?
    let isProxy: Bool
}

/// A dedicated manuscript page keeps detailed educational prose away from
/// the live person. It is not an X-ray, clinical result, or saved photograph.
struct MirrorStudySheet: View {
    let note: MirrorStudyNote
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("STUDI DI ANATOMIA")
                            .font(.system(.caption, design: .serif, weight: .semibold))
                            .tracking(1.3)
                            .foregroundStyle(LeonardoPalette.copperInk)
                        Spacer()
                        Text("FOLIO · IV")
                            .font(.system(.caption, design: .serif))
                            .foregroundStyle(LeonardoPalette.mutedInk)
                    }
                    .accessibilityHidden(true)

                    Text(LocalizedStringKey(note.title))
                        .font(.system(.title, design: .serif, weight: .semibold))
                        .foregroundStyle(LeonardoPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    ManuscriptRule()

                    Label(note.isProxy ? "Observed pose reference" : "Reviewed anatomy reference",
                          systemImage: "book.closed")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LeonardoPalette.verdigris)

                    Text(LocalizedStringKey(note.summary))
                        .font(.body)
                        .foregroundStyle(LeonardoPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    if let function = note.function {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Function")
                                .font(.headline)
                                .foregroundStyle(LeonardoPalette.verdigris)
                            Text(function)
                                .font(.body)
                                .foregroundStyle(LeonardoPalette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if let author = note.authorCredit {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Educational text credit")
                                .font(.caption.weight(.semibold))
                            Text(author)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(LeonardoPalette.mutedInk)
                    }

                    ManuscriptRule()

                    Label("Illustrative reference only · not personal medical imaging",
                          systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(LeonardoPalette.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .frame(maxWidth: 600, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(LeonardoPalette.parchment.ignoresSafeArea())
            .navigationTitle("Anatomy study")
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
}

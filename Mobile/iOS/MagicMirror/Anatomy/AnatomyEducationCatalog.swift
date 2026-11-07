import Foundation

/// Reviewed, offline educational notes are bound to the SAME named
/// source-mesh nodes as the native 3D anatomical selection pipeline.
/// Missing/unreviewed content must never invent descriptions of a
/// specific person's internal bones.
struct ReviewedAnatomyEducationNote {
    let title: String
    let summary: String
    let function: String?
    let authorCredit: String
}

struct AnatomyEducationSidecar: Decodable {
    struct Entry: Decodable {
        let sourceHierarchyPath: String
        let title: String
        let titleZh: String?
        let summary: String
        let summaryZh: String?
        let functionalNote: String?
        let functionalNoteZh: String?
    }

    let schemaVersion: Int
    let anatomicalSystem: String
    let sourceRevision: String
    let reviewedForEducationalDisplay: Bool
    let authorCredit: String
    let entries: [Entry]

    func note(
        for selection: ReviewedAnatomySelection,
        language: String
    ) -> ReviewedAnatomyEducationNote? {
        guard schemaVersion == 1,
              anatomicalSystem == selection.system.rawValue,
              sourceRevision == selection.sourceRevision,
              reviewedForEducationalDisplay,
              !authorCredit.trimmingCharacters(
                in: .whitespacesAndNewlines
              ).isEmpty,
              authorCredit.count <= 240,
              !entries.isEmpty, entries.count <= 3_000
        else { return nil }

        // Fail the entire sidecar closed rather than allowing the first
        // duplicate hierarchy path to silently win.
        var paths = Set<String>()
        for item in entries {
            guard !item.sourceHierarchyPath.isEmpty,
                  !item.sourceHierarchyPath.hasPrefix("/"),
                  !item.sourceHierarchyPath.contains(".."),
                  paths.insert(item.sourceHierarchyPath).inserted,
                  Self.isValid(item.title, maxLength: 120),
                  Self.isValid(item.summary, maxLength: 1_200),
                  Self.validOptional(item.titleZh, limit: 120),
                  Self.validOptional(item.summaryZh, limit: 1_200),
                  Self.validOptional(item.functionalNote, limit: 600),
                  Self.validOptional(item.functionalNoteZh, limit: 600)
            else { return nil }
        }

        guard let item = entries.first(where: {
            $0.sourceHierarchyPath == selection.sourceHierarchyPath
        }) else { return nil }

        let chinese = language.lowercased().hasPrefix("zh")
        let title = chinese ? (item.titleZh ?? item.title) : item.title
        let summary = chinese
            ? (item.summaryZh ?? item.summary) : item.summary
        let role = chinese
            ? (item.functionalNoteZh ?? item.functionalNote)
            : item.functionalNote
        return ReviewedAnatomyEducationNote(
            title: title, summary: summary,
            function: role, authorCredit: authorCredit
        )
    }

    private static func isValid(
        _ value: String, maxLength: Int
    ) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && value.count <= maxLength
    }

    private static func validOptional(
        _ value: String?, limit: Int
    ) -> Bool {
        value == nil || isValid(value!, maxLength: limit)
    }
}

/// Small, read-only bundle index. Each optional sidecar is loaded once
/// when the user first opens a reviewed model detail card. This is not
/// a query to any network, LLM or anatomy-data backend.
struct AnatomyEducationCatalog {
    private let reviewedSidecars: [AnatomyDisplayLayer: AnatomyEducationSidecar]

    init(bundle: Bundle = .main) {
        var found: [AnatomyDisplayLayer: AnatomyEducationSidecar] = [:]
        for layer in AnatomyDisplayLayer.allCases {
            guard let base = layer.resourceBaseName,
                  let url = bundle.url(
                    forResource: "\(base).education",
                    withExtension: "json"
                  ), let attributes = try? FileManager.default.attributesOfItem(
                    atPath: url.path
                  ),
                  let size = attributes[.size] as? NSNumber,
                  size.intValue <= 512_000,
                  let data = try? Data(contentsOf: url),
                  let sidecar = try? JSONDecoder().decode(
                    AnatomyEducationSidecar.self, from: data
                  ) else { continue }
            found[layer] = sidecar
        }
        reviewedSidecars = found
    }

    /// Explicit initializer for entirely synthetic XCTest content.
    init(sidecars: [AnatomyDisplayLayer: AnatomyEducationSidecar]) {
        reviewedSidecars = sidecars
    }

    func note(
        for selection: ReviewedAnatomySelection,
        language: String = Locale.current.language.languageCode?
            .identifier ?? "en"
    ) -> ReviewedAnatomyEducationNote? {
        reviewedSidecars[selection.system]?.note(
            for: selection, language: language
        )
    }

    static let installed = AnatomyEducationCatalog()
}

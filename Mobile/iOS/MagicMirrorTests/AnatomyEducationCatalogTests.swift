import Foundation
import XCTest
@testable import MagicMirror

final class AnatomyEducationCatalogTests: XCTestCase {
    private let identity = ReviewedAnatomySelection(
        system: .skeleton,
        sourceHierarchyPath: "synthetic/upper-arm",
        displayName: "Reviewed reference upper arm",
        sourceRevision: "synthetic-source-revision"
    )

    private func sidecar(
        system: String = "skeleton",
        revision: String = "synthetic-source-revision",
        reviewed: Bool = true,
        paths: [String] = ["synthetic/upper-arm"]
    ) throws -> AnatomyEducationSidecar {
        let records = paths.map { path -> [String: Any] in
            [
                "sourceHierarchyPath": path,
                "title": "Upper arm reference",
                "titleZh": "上臂参考结构",
                "summary": "Source-specific illustrative anatomical note.",
                "summaryZh": "对应来源的教学解剖说明。",
                "functionalNote": "An educational example function.",
                "functionalNoteZh": "教学用途的功能介绍。"
            ]
        }
        let payload: [String: Any] = [
            "schemaVersion": 1,
            "anatomicalSystem": system,
            "sourceRevision": revision,
            "reviewedForEducationalDisplay": reviewed,
            "authorCredit": "Synthetic XCTest author",
            "entries": records
        ]
        let data = try JSONSerialization.data(
            withJSONObject: payload
        )
        return try JSONDecoder().decode(
            AnatomyEducationSidecar.self, from: data
        )
    }

    func testReturnsReviewedBilingualSourceBoundEducation() throws {
        let catalog = AnatomyEducationCatalog(sidecars: [
            .skeleton: try sidecar()
        ])
        let english = catalog.note(
            for: identity, language: "en"
        )
        XCTAssertEqual(english?.title, "Upper arm reference")
        XCTAssertEqual(
            english?.function, "An educational example function."
        )
        XCTAssertEqual(
            english?.authorCredit, "Synthetic XCTest author"
        )

        let chinese = catalog.note(
            for: identity, language: "zh-Hans"
        )
        XCTAssertEqual(chinese?.title, "上臂参考结构")
        XCTAssertEqual(chinese?.summary, "对应来源的教学解剖说明。")
        XCTAssertEqual(chinese?.function, "教学用途的功能介绍。")
    }

    func testRejectsUnreviewedWrongVersionOrSystem() throws {
        for rejected in [
            try sidecar(reviewed: false),
            try sidecar(revision: "other-release"),
            try sidecar(system: "muscles")
        ] {
            XCTAssertNil(rejected.note(
                for: identity, language: "en"
            ))
        }
        let catalog = AnatomyEducationCatalog(sidecars: [
            .muscles: try sidecar(system: "muscles")
        ])
        XCTAssertNil(catalog.note(
            for: identity, language: "en"
        ))
    }

    func testRejectsDuplicatedOrInventedSourceNodes() throws {
        let duplicated = try sidecar(paths: [
            "synthetic/upper-arm", "synthetic/upper-arm"
        ])
        XCTAssertNil(duplicated.note(
            for: identity, language: "en"
        ))

        let unrelated = try sidecar(paths: ["synthetic/unknown"])
        XCTAssertNil(unrelated.note(
            for: identity, language: "en"
        ))

        let unsafe = try sidecar(paths: ["../not-a-source"])
        XCTAssertNil(unsafe.note(
            for: identity, language: "en"
        ))
    }
}

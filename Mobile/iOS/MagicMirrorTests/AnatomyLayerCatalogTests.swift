import XCTest
@testable import MagicMirror

final class AnatomyLayerCatalogTests: XCTestCase {
    func testOnlyIllustrativeReferenceProxyIsAvailable() {
        let available = AnatomyDisplayLayer.allCases.filter(\.isAvailable)
        XCTAssertEqual(available, [.referenceProxy])
        XCTAssertFalse(AnatomyDisplayLayer.skeleton.isAvailable)
        XCTAssertFalse(AnatomyDisplayLayer.muscles.isAvailable)
        XCTAssertFalse(AnatomyDisplayLayer.organs.isAvailable)
        XCTAssertFalse(AnatomyDisplayLayer.vessels.isAvailable)
        XCTAssertFalse(AnatomyDisplayLayer.nerves.isAvailable)
        XCTAssertFalse(AnatomyDisplayLayer.joints.isAvailable)
    }

    func testPlannedSectionPlanesStayUnavailable() {
        XCTAssertEqual(AnatomySectionPlane.allCases.count, 3)
        XCTAssertTrue(AnatomySectionPlane.allCases.allSatisfy {
            !$0.isAvailable
        })
    }

    func testEveryVisibleLayerHasNonemptyExplanation() {
        for layer in AnatomyDisplayLayer.allCases {
            XCTAssertFalse(layer.title.isEmpty)
            XCTAssertFalse(layer.detail.isEmpty)
        }
    }

    func testEveryRealSystemHasItsOwnOfflineResourceNames() {
        let systems = AnatomyDisplayLayer.allCases.filter {
            $0 != .referenceProxy
        }
        let resources = systems.compactMap(\.resourceBaseName)
        let manifests = systems.compactMap(\.hierarchyManifestName)
        XCTAssertEqual(systems.count, 6)
        XCTAssertEqual(resources.count, systems.count)
        XCTAssertEqual(manifests.count, systems.count)
        XCTAssertEqual(Set(resources).count, systems.count)
        XCTAssertEqual(Set(manifests).count, systems.count)
        XCTAssertEqual(
            AnatomyDisplayLayer.skeleton.resourceBaseName,
            "skeleton_atlas"
        )
        XCTAssertNil(AnatomyDisplayLayer.referenceProxy.resourceBaseName)
        XCTAssertNil(
            AnatomyDisplayLayer.referenceProxy.hierarchyManifestName
        )
        XCTAssertEqual(
            AnatomyDisplayLayer.organs.hierarchyManifestName,
            "organs_atlas_manifest"
        )
    }
}

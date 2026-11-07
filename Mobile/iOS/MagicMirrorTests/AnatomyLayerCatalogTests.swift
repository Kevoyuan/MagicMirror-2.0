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
}

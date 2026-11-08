import XCTest
@testable import MagicMirror

final class AnatomyLayerPresentationTests: XCTestCase {
    func testRequestedButUnregisteredSystemDoesNotLookSelected() {
        let enabled: Set<AnatomyDisplayLayer> = [.skeleton]
        let ready: Set<AnatomyDisplayLayer> = []
        let skeleton = AnatomyLayerPresentation(
            layer: .skeleton, enabled: enabled, ready: ready
        )
        XCTAssertFalse(skeleton.available)
        XCTAssertFalse(skeleton.selected)
        XCTAssertEqual(skeleton.statusKey, "LOCKED")

        let proxy = AnatomyLayerPresentation(
            layer: .referenceProxy, enabled: enabled, ready: ready
        )
        XCTAssertTrue(proxy.available)
        XCTAssertTrue(proxy.selected)
    }

    func testReviewedSystemOnlySelectedWhenReadyAndEnabled() {
        let enabled: Set<AnatomyDisplayLayer> = [.skeleton]
        let ready: Set<AnatomyDisplayLayer> = [.skeleton, .muscles]
        let skeleton = AnatomyLayerPresentation(
            layer: .skeleton, enabled: enabled, ready: ready
        )
        XCTAssertTrue(skeleton.available)
        XCTAssertTrue(skeleton.selected)
        XCTAssertEqual(skeleton.statusKey, "SELECTED")

        let muscles = AnatomyLayerPresentation(
            layer: .muscles, enabled: enabled, ready: ready
        )
        XCTAssertTrue(muscles.available)
        XCTAssertFalse(muscles.selected)
        XCTAssertEqual(muscles.statusKey, "READY")

        let proxy = AnatomyLayerPresentation(
            layer: .referenceProxy, enabled: enabled, ready: ready
        )
        XCTAssertFalse(proxy.selected)
    }

    func testMultipleAvailableSystemsShowIndependentSelectedStates() {
        let enabled: Set<AnatomyDisplayLayer> = [.skeleton, .muscles, .vessels]
        let ready: Set<AnatomyDisplayLayer> = [.skeleton, .muscles]
        XCTAssertTrue(AnatomyLayerPresentation(
            layer: .skeleton, enabled: enabled, ready: ready
        ).selected)
        XCTAssertTrue(AnatomyLayerPresentation(
            layer: .muscles, enabled: enabled, ready: ready
        ).selected)
        XCTAssertFalse(AnatomyLayerPresentation(
            layer: .vessels, enabled: enabled, ready: ready
        ).selected)
        XCTAssertTrue(AnatomyLayerPresentation(
            layer: .referenceProxy, enabled: enabled, ready: ready
        ).available)
    }

    func testFallbackReturnsToProxyWhenNoReadySystemsSelected() {
        let enabled: Set<AnatomyDisplayLayer> = []
        let ready: Set<AnatomyDisplayLayer> = [.skeleton]
        let proxy = AnatomyLayerPresentation(
            layer: .referenceProxy, enabled: enabled, ready: ready
        )
        XCTAssertTrue(proxy.selected)
        XCTAssertEqual(proxy.statusKey, "SELECTED")
    }
    func testSoloRejectsUnregisteredAndProxyLayers() {
        let ready: Set<AnatomyDisplayLayer> = [.skeleton, .muscles]
        XCTAssertNil(AnatomyLayerPresentation.soloSelection(
            for: .organs, ready: ready
        ))
        XCTAssertNil(AnatomyLayerPresentation.soloSelection(
            for: .referenceProxy, ready: ready
        ))
        XCTAssertNil(AnatomyLayerPresentation.soloSelection(
            for: .skeleton, ready: []
        ))
    }

    func testSoloSelectsExactlyOneRegisteredAnatomySystem() {
        let ready: Set<AnatomyDisplayLayer> = [.skeleton, .muscles]
        XCTAssertEqual(AnatomyLayerPresentation.soloSelection(
            for: .muscles, ready: ready
        ), Set([.muscles]))
        XCTAssertEqual(AnatomyLayerPresentation.soloSelection(
            for: .skeleton, ready: ready
        ), Set([.skeleton]))
    }

}

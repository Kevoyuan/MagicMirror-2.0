import XCTest
@testable import MagicMirror

final class AnatomyLayerVisibilityPolicyTests: XCTestCase {
    private let ready: Set<AnatomyDisplayLayer> = [
        .skeleton, .muscles, .organs, .nerves
    ]

    func testVerifiedSourcesCanBeLayeredIndependently() {
        let first = AnatomyLayerVisibilityPolicy.toggled(
            layer: .skeleton, ready: ready, visible: []
        )
        XCTAssertEqual(first, [.skeleton])
        let two = AnatomyLayerVisibilityPolicy.toggled(
            layer: .muscles, ready: ready, visible: first
        )
        XCTAssertEqual(two, [.skeleton, .muscles])
        let three = AnatomyLayerVisibilityPolicy.toggled(
            layer: .organs, ready: ready, visible: two
        )
        XCTAssertEqual(three, [.skeleton, .muscles, .organs])
        let hideMuscles = AnatomyLayerVisibilityPolicy.toggled(
            layer: .muscles, ready: ready, visible: three
        )
        XCTAssertEqual(hideMuscles, [.skeleton, .organs])
        XCTAssertEqual(
            AnatomyLayerVisibilityPolicy.primary(
                preferred: .muscles, visible: hideMuscles
            ),
            .skeleton
        )
    }

    func testUnreviewedLayersStayLockedAndProxyClearsSelection() {
        let current: Set<AnatomyDisplayLayer> = [.skeleton, .muscles]
        XCTAssertEqual(
            AnatomyLayerVisibilityPolicy.toggled(
                layer: .vessels, ready: ready, visible: current
            ),
            current
        )
        let proxy = AnatomyLayerVisibilityPolicy.toggled(
            layer: .referenceProxy, ready: ready, visible: current
        )
        XCTAssertTrue(proxy.isEmpty)
        XCTAssertEqual(
            AnatomyLayerVisibilityPolicy.primary(
                preferred: .muscles, visible: proxy
            ),
            .referenceProxy
        )
    }

    func testFocusReturnsToFirstStillVisibleLayer() {
        let visible: Set<AnatomyDisplayLayer> = [.nerves, .organs]
        XCTAssertEqual(
            AnatomyLayerVisibilityPolicy.primary(
                preferred: .organs, visible: visible
            ),
            .organs
        )
        XCTAssertEqual(
            AnatomyLayerVisibilityPolicy.primary(
                preferred: .skeleton, visible: visible
            ),
            .organs
        )
    }
}

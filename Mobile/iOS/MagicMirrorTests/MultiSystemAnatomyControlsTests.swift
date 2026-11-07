import XCTest
@testable import MagicMirror

/// No real model or camera is bundled in these state and palette checks.
@MainActor
final class MultiSystemAnatomyControlsTests: XCTestCase {
    func testIndependentSystemTogglesWithProxyFallback() {
        let model = MirrorViewModel()
        XCTAssertEqual(model.enabledAnatomyLayers, [.skeleton])
        XCTAssertTrue(model.canSelectAnatomyLayer(.referenceProxy))
        XCTAssertFalse(model.canSelectAnatomyLayer(.muscles))

        model.selectAnatomyLayer(.muscles)
        XCTAssertEqual(model.enabledAnatomyLayers, [.skeleton])

        // Synthetic ready set exercises UI controls without overriding
        // the real model-loader or independently-reviewed camera gate.
        model.readyAnatomyLayers = [.skeleton, .muscles, .organs]
        model.selectAnatomyLayer(.muscles)
        XCTAssertEqual(model.enabledAnatomyLayers, [.skeleton, .muscles])
        model.selectAnatomyLayer(.organs)
        XCTAssertEqual(
            model.enabledAnatomyLayers, [.skeleton, .muscles, .organs]
        )
        model.selectAnatomyLayer(.muscles)
        XCTAssertEqual(model.enabledAnatomyLayers, [.skeleton, .organs])

        model.selectAnatomyLayer(.referenceProxy)
        XCTAssertTrue(model.enabledAnatomyLayers.isEmpty)
        XCTAssertEqual(model.selectedAnatomyLayer, .referenceProxy)
        XCTAssertNil(model.activeSection)
        XCTAssertFalse(model.canSectionReviewedAtlas)
    }

    func testLayerOpacitiesAreIndependentFiniteAndBounded() {
        let model = MirrorViewModel()
        model.readyAnatomyLayers = [.skeleton, .muscles]
        let originalSkeleton = model.layerOpacity(.skeleton)

        model.setLayerOpacity(.muscles, 0.25)
        XCTAssertEqual(model.layerOpacity(.muscles), 0.25)
        XCTAssertEqual(model.layerOpacity(.skeleton), originalSkeleton)

        model.setLayerOpacity(.muscles, 50)
        XCTAssertEqual(model.layerOpacity(.muscles), 1)
        model.setLayerOpacity(.muscles, -4)
        XCTAssertEqual(model.layerOpacity(.muscles), 0.05)
        model.setLayerOpacity(.muscles, .nan)
        XCTAssertEqual(model.layerOpacity(.muscles), 0.05)

        model.setLayerOpacity(.organs, 0.99)
        XCTAssertNotEqual(model.layerOpacity(.organs), 0.99)
    }

    func testSixSystemsHaveDistinctApprovedSourceNamesAndTint() {
        let layers = AnatomyDisplayLayer.allCases.filter {
            $0 != .referenceProxy
        }
        XCTAssertEqual(layers.count, 6)
        XCTAssertEqual(
            Set(layers.compactMap(\.resourceBaseName)).count,
            layers.count
        )
        for layer in layers {
            XCTAssertNotNil(layer.hierarchyManifestName)
            let color = layer.referencePigment
            XCTAssertTrue(color.x.isFinite)
            XCTAssertTrue(color.y.isFinite)
            XCTAssertTrue(color.z.isFinite)
            XCTAssertEqual(color.w, 1)
        }
        XCTAssertNotEqual(
            AnatomyDisplayLayer.skeleton.referencePigment.x,
            AnatomyDisplayLayer.muscles.referencePigment.x
        )
        XCTAssertNotEqual(
            AnatomyDisplayLayer.nerves.referencePigment.y,
            AnatomyDisplayLayer.organs.referencePigment.y
        )
    }
}

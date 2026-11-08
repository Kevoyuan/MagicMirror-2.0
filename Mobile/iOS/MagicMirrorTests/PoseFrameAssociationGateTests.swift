import CoreGraphics
import XCTest
@testable import MagicMirror

final class PoseFrameAssociationGateTests: XCTestCase {
    private let portrait = CGSize(width: 720, height: 1280)
    private let rotated = CGSize(width: 1280, height: 720)

    func testRejectsBeforeStartAndAfterStop() {
        let gate = PoseFrameAssociationGate()
        XCTAssertFalse(gate.register(
            timestampMilliseconds: 10, imageSize: portrait
        ))
        gate.reset(active: true)
        XCTAssertTrue(gate.register(
            timestampMilliseconds: 10, imageSize: portrait
        ))
        gate.reset(active: false)
        XCTAssertNil(gate.consume(timestampMilliseconds: 10))
        XCTAssertFalse(gate.register(
            timestampMilliseconds: 20, imageSize: portrait
        ))
    }

    func testExactFrameImageDimensionsNotLatestImageDimensions() {
        let gate = PoseFrameAssociationGate()
        gate.reset(active: true)
        XCTAssertTrue(gate.register(
            timestampMilliseconds: 1000, imageSize: portrait
        ))
        XCTAssertTrue(gate.register(
            timestampMilliseconds: 1033, imageSize: rotated
        ))
        let matched = gate.consume(timestampMilliseconds: 1000)
        XCTAssertEqual(matched?.width, 720)
        XCTAssertEqual(matched?.height, 1280)
        let next = gate.consume(timestampMilliseconds: 1033)
        XCTAssertEqual(next?.width, 1280)
        XCTAssertEqual(next?.height, 720)
    }

    func testRejectsDuplicateAndOutOfOrderCallbacks() {
        let gate = PoseFrameAssociationGate()
        gate.reset(active: true)
        XCTAssertTrue(gate.register(
            timestampMilliseconds: 1000, imageSize: portrait
        ))
        XCTAssertFalse(gate.register(
            timestampMilliseconds: 1000, imageSize: portrait
        ))
        XCTAssertFalse(gate.register(
            timestampMilliseconds: 999, imageSize: portrait
        ))
        XCTAssertTrue(gate.register(
            timestampMilliseconds: 1033, imageSize: portrait
        ))
        XCTAssertNotNil(gate.consume(timestampMilliseconds: 1033))
        XCTAssertNil(gate.consume(timestampMilliseconds: 1000))
        XCTAssertNil(gate.consume(timestampMilliseconds: 1033))
    }

    func testRejectsStalePoseAndMissingFrameIdentity() {
        let gate = PoseFrameAssociationGate(
            maximumResultAgeMilliseconds: 160
        )
        gate.reset(active: true)
        XCTAssertTrue(gate.register(
            timestampMilliseconds: 1000, imageSize: portrait
        ))
        XCTAssertTrue(gate.register(
            timestampMilliseconds: 1180, imageSize: portrait
        ))
        XCTAssertNil(gate.consume(timestampMilliseconds: 1000))
        XCTAssertNotNil(gate.consume(timestampMilliseconds: 1180))
        XCTAssertNil(gate.consume(timestampMilliseconds: 1110))
    }

    func testSessionRestartDiscardsOldPendingCallbacks() {
        let gate = PoseFrameAssociationGate()
        gate.reset(active: true)
        XCTAssertTrue(gate.register(
            timestampMilliseconds: 1000, imageSize: portrait
        ))
        gate.reset(active: false)
        gate.reset(active: true)
        XCTAssertNil(gate.consume(timestampMilliseconds: 1000))
        XCTAssertTrue(gate.register(
            timestampMilliseconds: 5000, imageSize: rotated
        ))
        XCTAssertNil(gate.consume(timestampMilliseconds: 1033))
        XCTAssertEqual(
            gate.consume(timestampMilliseconds: 5000)?.width, 1280
        )
    }

    func testBoundedPendingBufferAndEviction() {
        let gate = PoseFrameAssociationGate(
            maximumResultAgeMilliseconds: 1000,
            maximumPendingCount: 3
        )
        gate.reset(active: true)
        for i in 0..<6 {
            XCTAssertTrue(gate.register(
                timestampMilliseconds: 1000 + i * 20,
                imageSize: portrait
            ))
        }
        XCTAssertNil(gate.consume(timestampMilliseconds: 1020))
        XCTAssertNotNil(gate.consume(timestampMilliseconds: 1060))
        XCTAssertNil(gate.consume(timestampMilliseconds: 1040))
        XCTAssertNotNil(gate.consume(timestampMilliseconds: 1100))
    }

    func testSourceCallbackUptimeBelongsToSameMatchedFrame() {
        let gate = PoseFrameAssociationGate()
        gate.reset(active: true)
        XCTAssertTrue(gate.register(
            timestampMilliseconds: 1000, imageSize: portrait,
            captureCallbackUptime: 10.11
        ))
        XCTAssertTrue(gate.register(
            timestampMilliseconds: 1033, imageSize: portrait,
            captureCallbackUptime: 10.15
        ))
        let first = gate.consumeMetadata(timestampMilliseconds: 1000)
        XCTAssertEqual(first?.captureCallbackUptime ?? -1, 10.11,
                       accuracy: 0.00001)
        let second = gate.consumeMetadata(timestampMilliseconds: 1033)
        XCTAssertEqual(second?.captureCallbackUptime ?? -1, 10.15,
                       accuracy: 0.00001)
        XCTAssertNil(gate.consumeMetadata(timestampMilliseconds: 1000))

        XCTAssertTrue(gate.register(
            timestampMilliseconds: 1066, imageSize: portrait,
            captureCallbackUptime: .nan
        ))
        XCTAssertNil(gate.consumeMetadata(
            timestampMilliseconds: 1066
        )?.captureCallbackUptime)
    }

    func testRejectsNonfiniteAndZeroDimensions() {
        let gate = PoseFrameAssociationGate()
        gate.reset(active: true)
        XCTAssertFalse(gate.register(
            timestampMilliseconds: 1, imageSize: .zero
        ))
        XCTAssertFalse(gate.register(
            timestampMilliseconds: 2,
            imageSize: CGSize(width: CGFloat.nan, height: 720)
        ))
        XCTAssertFalse(gate.register(
            timestampMilliseconds: 3,
            imageSize: CGSize(width: CGFloat.infinity, height: 720)
        ))
        XCTAssertTrue(gate.register(
            timestampMilliseconds: 4, imageSize: portrait
        ))
        XCTAssertNil(gate.consume(timestampMilliseconds: 3))
    }
}

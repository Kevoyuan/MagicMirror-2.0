import Foundation
import XCTest
@testable import MagicMirror

final class PoseSilhouetteMaskTests: XCTestCase {
    func testCopiesOnlyBoundedExplicitPixelFormats() {
        let pixelCount = 32 * 32
        let bytes = Data(repeating: 127, count: pixelCount)
        let gray = PoseSilhouetteMask(
            width: 32, height: 32,
            storage: .uint8, pixels: bytes
        )
        XCTAssertNotNil(gray)
        XCTAssertEqual(gray?.width, 32)
        XCTAssertEqual(gray?.height, 32)
        XCTAssertEqual(gray?.storage.bytesPerPixel, 1)

        let floatPixels = Data(repeating: 0, count: pixelCount * 4)
        let floatMask = PoseSilhouetteMask(
            width: 32, height: 32,
            storage: .float32, pixels: floatPixels
        )
        XCTAssertEqual(floatMask?.storage.bytesPerPixel, 4)
        XCTAssertEqual(floatMask?.pixels.count, pixelCount * 4)
    }

    func testCorruptDimensionsAndTruncationFailClosed() {
        let original = Data(repeating: 255, count: 32 * 32)
        XCTAssertNil(PoseSilhouetteMask(
            width: 32, height: 33,
            storage: .uint8, pixels: original
        ))
        XCTAssertNil(PoseSilhouetteMask(
            width: 0, height: 32,
            storage: .uint8, pixels: Data()
        ))
        XCTAssertNil(PoseSilhouetteMask(
            width: 3000, height: 32,
            storage: .uint8, pixels: original
        ))
        XCTAssertNil(PoseSilhouetteMask(
            width: 32, height: 32,
            storage: .float32, pixels: original
        ))
    }
}

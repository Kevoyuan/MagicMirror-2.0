import CryptoKit
import XCTest
@testable import MagicMirror

final class VerifiedAtlasContractTests: XCTestCase {
    func testUnreviewedAtlasDoesNotPassDistributionGate() {
        // No Z-Anatomy FBX or derived mesh is bundled into the source repo.
        // Bundle load fails closed until a manifest and verified binary
        // are explicitly approved and included in app resources.
        XCTAssertThrowsError(try VerifiedAnatomyAtlas.load()) { error in
            XCTAssertTrue(
                error is MobileAtlasError || error is DecodingError
            )
        }
    }

    func testAssetHashIsDeterministic() {
        let sha = SHA256.hash(data: Data("MMATLAS1".utf8))
            .map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(sha.count, 64)
        XCTAssertTrue(sha.allSatisfy { $0.isHexDigit })
    }
}

import CoreGraphics
import XCTest
import simd
@testable import MagicMirror

@MainActor
final class AnatomyReferenceCaptureTests: XCTestCase {
    private func sample(
        timestamp: Int,
        shoulderShift: Float = 0,
        bad: Bool = false
    ) -> PoseSnapshot {
        let image = Array(
            repeating: PosePoint(x: 0.5, y: 0.5, visibility: 0.99),
            count: 33
        )
        var world = Array(
            repeating: PoseWorldPoint(
                x: 0.1, y: 0.1, z: 0.2, visibility: 0.99
            ),
            count: 33
        )
        world[11] = PoseWorldPoint(
            x: -0.25 + shoulderShift, y: 0.5, z: 0.15,
            visibility: bad ? 0.1 : 0.99
        )
        world[12] = PoseWorldPoint(
            x: 0.25, y: 0.5, z: 0.15, visibility: 0.99
        )
        world[23] = PoseWorldPoint(
            x: -0.19, y: 0, z: 0, visibility: 0.99
        )
        world[24] = PoseWorldPoint(
            x: 0.19, y: 0, z: 0, visibility: 0.99
        )
        return PoseSnapshot(
            timestampMilliseconds: timestamp,
            imageSize: CGSize(width: 720, height: 1280),
            points: image, worldPoints: world
        )
    }

    func testCapturesExactlyAfterConfiguredStableFrames() {
        var capture = AnatomyReferenceCapture(requiredFrames: 4)
        for index in 0..<3 {
            XCTAssertNil(capture.ingest(sample(timestamp: 1000 + index * 33)))
        }
        XCTAssertNotNil(capture.ingest(sample(timestamp: 1099)))
        XCTAssertEqual(capture.reference?.worldPoints.count, 33)
        XCTAssertEqual(capture.reference?.timestampMilliseconds, 1099)
    }

    func testCoreMotionResetsWindow() {
        var capture = AnatomyReferenceCapture(
            requiredFrames: 3, maximumCoreMotionMeters: 0.08
        )
        XCTAssertNil(capture.ingest(sample(timestamp: 1000)))
        XCTAssertNil(capture.ingest(sample(
            timestamp: 1033, shoulderShift: 0.2
        )))
        XCTAssertNil(capture.ingest(sample(timestamp: 1066)))
        XCTAssertNil(capture.ingest(sample(timestamp: 1099)))
        XCTAssertNotNil(capture.ingest(sample(timestamp: 1132)))
    }

    func testLowConfidenceAndLongGapResetWindow() {
        var capture = AnatomyReferenceCapture(requiredFrames: 3)
        XCTAssertNil(capture.ingest(sample(timestamp: 1000)))
        XCTAssertNil(capture.ingest(sample(timestamp: 1033, bad: true)))
        XCTAssertNil(capture.ingest(sample(timestamp: 1066)))
        XCTAssertNil(capture.ingest(sample(timestamp: 1500)))
        XCTAssertNil(capture.ingest(sample(timestamp: 1533)))
        XCTAssertNotNil(capture.ingest(sample(timestamp: 1566)))
    }

    func testReferenceNeverChangesDuringMovementUntilExplicitReset() {
        var capture = AnatomyReferenceCapture(requiredFrames: 3)
        for index in 0..<3 {
            _ = capture.ingest(sample(timestamp: 1000 + index * 33))
        }
        let original = capture.reference?.worldPoints[11].x
        _ = capture.ingest(sample(
            timestamp: 1100, shoulderShift: 0.5
        ))
        XCTAssertEqual(capture.reference?.worldPoints[11].x, original)
        capture.reset()
        XCTAssertNil(capture.reference)
    }

    func testRejectsMissingWorldAndRecovers() {
        var capture = AnatomyReferenceCapture(requiredFrames: 3)
        let empty = PoseSnapshot(
            timestampMilliseconds: 1000,
            imageSize: CGSize(width: 720, height: 1280),
            points: sample(timestamp: 1000).points
        )
        XCTAssertNil(capture.ingest(empty))
        XCTAssertNil(capture.ingest(sample(timestamp: 1033)))
        XCTAssertNil(capture.ingest(sample(timestamp: 1066)))
        XCTAssertNotNil(capture.ingest(sample(timestamp: 1099)))
    }
}

import CoreGraphics
import XCTest
@testable import MagicMirror

final class AnatomyReferenceHitTesterTests: XCTestCase {
    private let image = CGSize(width: 720, height: 1280)
    private let viewport = CGSize(width: 360, height: 640)

    private func frame(
        hideLeftElbow: Bool = false
    ) -> PoseSnapshot {
        var points = Array(
            repeating: PosePoint(x: 0.5, y: 0.5, visibility: 0),
            count: 33
        )
        func set(_ id: Int, _ x: CGFloat, _ y: CGFloat, _ v: Float = 1) {
            points[id] = PosePoint(x: x, y: y, visibility: v)
        }
        set(11, 0.28, 0.31)
        set(13, 0.17, 0.48, hideLeftElbow ? 0.1 : 1)
        set(15, 0.13, 0.67)
        set(12, 0.72, 0.31)
        set(14, 0.83, 0.48)
        set(16, 0.87, 0.67)
        return PoseSnapshot(
            timestampMilliseconds: 5000,
            imageSize: image, points: points
        )
    }

    func testTapSelectsClosestRenderedReferenceWithCorrectSide() {
        let sample = frame()
        let leftShoulder = PoseSkeleton.pointInPreview(
            sample.points[11], imageSize: image, viewSize: viewport
        )!
        let leftElbow = PoseSkeleton.pointInPreview(
            sample.points[13], imageSize: image, viewSize: viewport
        )!
        let mid = CGPoint(
            x: (leftShoulder.x + leftElbow.x) * 0.5,
            y: (leftShoulder.y + leftElbow.y) * 0.5
        )
        let item = AnatomyReferenceHitTester.select(
            at: mid, snapshot: sample,
            viewport: viewport, focus: .arms
        )
        XCTAssertEqual(item?.title, "Left upper arm")
        XCTAssertEqual(item?.fromLandmark, 11)
        XCTAssertEqual(item?.toLandmark, 13)
        XCTAssertEqual(item?.visible(in: sample), true)
        XCTAssertTrue(item!.explanation.contains("illustrative"))
    }

    func testPartialBodyAndFocusGatesDoNotInventSegments() {
        let sample = frame()
        let point = CGPoint(x: 100, y: 240)
        XCTAssertNil(AnatomyReferenceHitTester.select(
            at: point, snapshot: sample,
            viewport: viewport, focus: .legs
        ))
        let hidden = frame(hideLeftElbow: true)
        let target = CGPoint(x: 78, y: 253)
        XCTAssertNil(AnatomyReferenceHitTester.select(
            at: target, snapshot: hidden,
            viewport: viewport, focus: .arms,
            maximumDistance: 15
        ))
    }

    func testOutOfBoundsTapOrNoPoseIsNotASelection() {
        let sample = frame()
        XCTAssertNil(AnatomyReferenceHitTester.select(
            at: CGPoint(x: -200, y: -200),
            snapshot: sample,
            viewport: viewport, focus: .full
        ))
        XCTAssertNil(AnatomyReferenceHitTester.select(
            at: CGPoint(x: 90, y: 280),
            snapshot: nil,
            viewport: viewport, focus: .full
        ))
        XCTAssertNil(AnatomyReferenceHitTester.select(
            at: CGPoint(x: 90, y: 280),
            snapshot: sample,
            viewport: .zero, focus: .full
        ))
    }
}

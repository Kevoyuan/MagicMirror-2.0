import CoreGraphics
import CoreVideo
import XCTest
@testable import MagicMirror

final class MatchedVideoCompositorTests: XCTestCase {
    private func buffer(
        width: Int = 64, height: Int = 48
    ) -> CVPixelBuffer {
        var created: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, width, height,
            kCVPixelFormatType_32BGRA, nil, &created
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        XCTAssertNotNil(created)
        return created!
    }

    func testValidSingleImageIsConsumedByExactTimestamp() {
        let store = BoundedVideoFrameStore()
        let first = buffer()
        store.reset(active: true)
        XCTAssertTrue(store.retain(
            timestampMilliseconds: 1000, pixelBuffer: first
        ))
        let retrieved = store.take(timestampMilliseconds: 1000)
        XCTAssertNotNil(retrieved)
        XCTAssertTrue((retrieved! as AnyObject) === (first as AnyObject))
        XCTAssertNil(store.take(timestampMilliseconds: 1000))
    }

    func testNeverReusesOldCaptureAfterSessionRestart() {
        let store = BoundedVideoFrameStore()
        store.reset(active: true)
        XCTAssertTrue(store.retain(
            timestampMilliseconds: 5000, pixelBuffer: buffer()
        ))
        store.reset(active: false)
        XCTAssertNil(store.take(timestampMilliseconds: 5000))
        XCTAssertFalse(store.retain(
            timestampMilliseconds: 5001, pixelBuffer: buffer()
        ))
        store.reset(active: true)
        XCTAssertNil(store.take(timestampMilliseconds: 5000))
        XCTAssertTrue(store.retain(
            timestampMilliseconds: 7100, pixelBuffer: buffer()
        ))
        XCTAssertNotNil(store.take(timestampMilliseconds: 7100))
    }

    func testEvictionAndOutOfOrderFramesAreRejected() {
        let store = BoundedVideoFrameStore(
            maxPendingCount: 3, maxAgeMilliseconds: 1000
        )
        store.reset(active: true)
        for index in 0..<8 {
            XCTAssertTrue(store.retain(
                timestampMilliseconds: 100 + index * 20,
                pixelBuffer: buffer()
            ))
        }
        XCTAssertFalse(store.retain(
            timestampMilliseconds: 120, pixelBuffer: buffer()
        ))
        XCTAssertNil(store.take(timestampMilliseconds: 140))
        XCTAssertNotNil(store.take(timestampMilliseconds: 200))
        XCTAssertNil(store.take(timestampMilliseconds: 180))
        XCTAssertNotNil(store.take(timestampMilliseconds: 240))
    }

    func testAgeLimitAndUnsupportedPixelFormatFailClosed() {
        let store = BoundedVideoFrameStore(
            maxPendingCount: 30, maxAgeMilliseconds: 50
        )
        store.reset(active: true)
        XCTAssertTrue(store.retain(
            timestampMilliseconds: 1000, pixelBuffer: buffer()
        ))
        XCTAssertTrue(store.retain(
            timestampMilliseconds: 1100, pixelBuffer: buffer()
        ))
        XCTAssertNil(store.take(timestampMilliseconds: 1000))
        XCTAssertNotNil(store.take(timestampMilliseconds: 1100))
        var yuv: CVPixelBuffer?
        XCTAssertEqual(
            CVPixelBufferCreate(
                kCFAllocatorDefault, 64, 48,
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, nil, &yuv
            ), kCVReturnSuccess
        )
        XCTAssertFalse(store.retain(
            timestampMilliseconds: 1200, pixelBuffer: yuv!
        ))
    }

    func testVideoAspectFillCropMirrorsExistingPoseCoordinates() {
        let source = CGSize(width: 720, height: 1280)
        let viewport = CGSize(width: 390, height: 844)
        guard let crop = VideoAspectFillCrop.bounds(
            source: source, viewport: viewport
        ) else {
            XCTFail("Expected a finite aspect fill crop")
            return
        }
        XCTAssertEqual(crop.y, 0, accuracy: 0.00001)
        XCTAssertEqual(crop.w, 1, accuracy: 0.00001)
        XCTAssertGreaterThan(crop.x, 0)
        XCTAssertLessThan(crop.z, 1)

        // A MediaPipe landmark has the same screen location whether it
        // is mapped by the native preview or sampled by the Metal video.
        let point = PosePoint(x: 0.37, y: 0.64, visibility: 0.9)
        let projected = PoseSkeleton.pointInPreview(
            point, imageSize: source, viewSize: viewport
        )
        XCTAssertNotNil(projected)
        let metalX = (Float(point.x) - crop.x) /
                     (crop.z - crop.x) * Float(viewport.width)
        let metalY = (Float(point.y) - crop.y) /
                     (crop.w - crop.y) * Float(viewport.height)
        XCTAssertEqual(Double(projected!.x), Double(metalX), accuracy: 0.02)
        XCTAssertEqual(Double(projected!.y), Double(metalY), accuracy: 0.02)
    }

    func testMalformedDimensionsCannotCreateCameraTextureCrop() {
        let source = CGSize(width: 720, height: 1280)
        XCTAssertNil(VideoAspectFillCrop.bounds(
            source: .zero, viewport: source
        ))
        XCTAssertNil(VideoAspectFillCrop.bounds(
            source: source,
            viewport: CGSize(width: .nan, height: 840)
        ))
        XCTAssertNil(VideoAspectFillCrop.bounds(
            source: source,
            viewport: CGSize(width: 0, height: 844)
        ))
    }
}

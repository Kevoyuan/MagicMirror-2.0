import CoreGraphics
import Foundation
import XCTest
@testable import MagicMirror

final class CameraIntrinsicMatrixReaderTests: XCTestCase {
    private let size = CGSize(width: 720, height: 1280)

    private func packed(_ values: [Float]) -> Data {
        var output = Data()
        for var number in values {
            withUnsafeBytes(of: &number) { output.append(contentsOf: $0) }
        }
        return output
    }

    func testParsesColumnMajorPinholeMatrix() {
        let matrix = packed([
            800, 0, 0,
            0, 790, 0,
            360, 640, 1
        ])
        let calibrated = CameraIntrinsicMatrixReader.parse(
            matrix, imageSize: size
        )
        XCTAssertNotNil(calibrated)
        XCTAssertEqual(calibrated!.fx, 800, accuracy: 0.0001)
        XCTAssertEqual(calibrated!.fy, 790, accuracy: 0.0001)
        XCTAssertEqual(calibrated!.cx, 360, accuracy: 0.0001)
        XCTAssertEqual(calibrated!.cy, 640, accuracy: 0.0001)
    }

    func testInvalidOrMisalignedIntrinsicInputIsNotFabricated() {
        XCTAssertNil(CameraIntrinsicMatrixReader.parse(
            Data([1, 2, 3]), imageSize: size
        ))
        XCTAssertNil(CameraIntrinsicMatrixReader.parse(
            packed([0, 0, 0, 0, 800, 0, 360, 640, 1]),
            imageSize: size
        ))
        XCTAssertNil(CameraIntrinsicMatrixReader.parse(
            packed([800, 0, 0, 0, 800, 0, 9000, 640, 1]),
            imageSize: size
        ))
    }

    func testFrameGateKeepsIntrinsicMatrixFromThatExactFrame() {
        let gate = PoseFrameAssociationGate()
        gate.reset(active: true)

        let first = BodyCameraIntrinsics(
            fx: 800, fy: 800, cx: 360, cy: 640,
            width: 720, height: 1280
        )
        let second = BodyCameraIntrinsics(
            fx: 850, fy: 845, cx: 360, cy: 640,
            width: 720, height: 1280
        )
        XCTAssertTrue(gate.register(
            timestampMilliseconds: 1000, imageSize: size,
            intrinsics: first
        ))
        XCTAssertTrue(gate.register(
            timestampMilliseconds: 1033, imageSize: size,
            intrinsics: second
        ))

        let matched = gate.consumeMetadata(timestampMilliseconds: 1000)
        XCTAssertEqual(matched?.imageSize.width, 720)
        XCTAssertEqual(matched?.intrinsics?.fx, 800)
        XCTAssertEqual(
            gate.consumeMetadata(timestampMilliseconds: 1033)?.intrinsics?.fx,
            850
        )
        XCTAssertNil(gate.consumeMetadata(timestampMilliseconds: 1000))
    }

    func testInvalidIntrinsicDimensionsDoNotRejectValidPoseFrame() {
        let gate = PoseFrameAssociationGate()
        gate.reset(active: true)
        let wrong = BodyCameraIntrinsics(
            fx: 800, fy: 800, cx: 360, cy: 640,
            width: 1920, height: 1080
        )
        XCTAssertTrue(gate.register(
            timestampMilliseconds: 1000, imageSize: size,
            intrinsics: wrong
        ))
        let metadata = gate.consumeMetadata(timestampMilliseconds: 1000)
        XCTAssertNotNil(metadata)
        XCTAssertNil(metadata?.intrinsics)
        XCTAssertEqual(metadata?.imageSize.height, 1280)
    }

    func testSessionStopInvalidatesCalibratedCameraFrame() {
        let gate = PoseFrameAssociationGate()
        gate.reset(active: true)
        XCTAssertTrue(gate.register(
            timestampMilliseconds: 1000, imageSize: size,
            intrinsics: BodyCameraIntrinsics(
                fx: 800, fy: 800, cx: 360, cy: 640,
                width: 720, height: 1280
            )
        ))
        gate.reset(active: false)
        XCTAssertNil(gate.consumeMetadata(timestampMilliseconds: 1000))
    }
}

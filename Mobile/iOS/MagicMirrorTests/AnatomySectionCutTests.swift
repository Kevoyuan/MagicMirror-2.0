import CoreGraphics
import simd
import XCTest
@testable import MagicMirror

/// Synthetic model-space torso geometry and known camera. No clinical
/// anatomy, independent calibration or source atlas is asserted.
final class AnatomySectionCutTests: XCTestCase {
    private let image = CGSize(width: 720, height: 1280)

    private func intrinsics() -> BodyCameraIntrinsics {
        BodyCameraIntrinsics(
            fx: 700, fy: 700, cx: 360, cy: 640,
            width: 720, height: 1280
        )
    }

    private func camera(
        _ frame: PoseSnapshot,
        reviewed: Bool = true
    ) -> ReviewedSourceCameraFrame {
        ReviewedSourceCameraFrame(
            timestampMilliseconds: frame.timestampMilliseconds,
            imageSize: frame.imageSize,
            intrinsics: intrinsics(),
            bodyToCamera: BodyToCameraTransform(
                rotation: simd_quatf(
                    angle: 0, axis: SIMD3<Float>(0, 1, 0)
                ),
                translation: SIMD3<Float>(0, 0, 3)
            ),
            independentReviewConfirmed: reviewed
        )
    }

    private func frame(
        timestamp: Int = 3000,
        noWorld: Bool = false
    ) -> PoseSnapshot {
        var world = Array(
            repeating: PoseWorldPoint(
                x: 0, y: 0, z: 0, visibility: 1
            ), count: 33
        )
        func set(_ id: Int, _ x: Float, _ y: Float, _ z: Float) {
            world[id] = PoseWorldPoint(
                x: x, y: y, z: z, visibility: 1
            )
        }
        set(11, -0.20, 0.40, 0.01)
        set(12, 0.20, 0.40, -0.01)
        set(23, -0.16, -0.10, 0.04)
        set(24, 0.16, -0.10, -0.04)

        let points = world.map { point -> PosePoint in
            let p = BodyCameraProjection.project(
                bodyWorld: SIMD3(point.x, point.y, point.z),
                camera: intrinsics(),
                bodyToCamera: BodyToCameraTransform(
                    rotation: simd_quatf(
                        angle: 0, axis: SIMD3<Float>(0, 1, 0)
                    ),
                    translation: SIMD3<Float>(0, 0, 3)
                )
            )!
            return PosePoint(
                x: CGFloat(p.normalizedX),
                y: CGFloat(p.normalizedY),
                visibility: 1
            )
        }
        return PoseSnapshot(
            timestampMilliseconds: timestamp,
            imageSize: image,
            points: points,
            worldPoints: noWorld ? [] : world,
            cameraIntrinsics: intrinsics()
        )
    }

    func testThreePlanesAreOrthogonalAndPassThroughTorsoCenter() {
        let frame = frame()
        let reviewed = camera(frame)
        let cuts = AnatomySectionPlane.allCases.compactMap { plane in
            AnatomySectionCut.make(
                section: plane,
                offsetInShoulderWidths: 0,
                frame: frame, camera: reviewed
            )
        }
        XCTAssertEqual(cuts.count, 3)
        guard cuts.count == 3 else { return }
        for cut in cuts {
            let n = SIMD3<Float>(
                cut.plane.x, cut.plane.y, cut.plane.z
            )
            XCTAssertEqual(simd_length(n), 1, accuracy: 0.001)
            XCTAssertTrue(cut.plane.w.isFinite)
        }
        let normals = cuts.map {
            SIMD3<Float>($0.plane.x, $0.plane.y, $0.plane.z)
        }
        XCTAssertEqual(
            simd_dot(normals[0], normals[1]), 0, accuracy: 0.001
        )
        XCTAssertEqual(
            simd_dot(normals[1], normals[2]), 0, accuracy: 0.001
        )
        XCTAssertEqual(
            simd_dot(normals[2], normals[0]), 0, accuracy: 0.001
        )
    }

    func testSectionOffsetMovesActual3DHalfSpace() {
        let frame = frame()
        let reviewed = camera(frame)
        let left = AnatomySectionCut.make(
            section: .sagittal,
            offsetInShoulderWidths: -0.4,
            frame: frame, camera: reviewed
        )!
        let right = AnatomySectionCut.make(
            section: .sagittal,
            offsetInShoulderWidths: 0.4,
            frame: frame, camera: reviewed
        )!
        XCTAssertEqual(
            abs(right.plane.w - left.plane.w),
            0.8 * 0.4, accuracy: 0.002
        )
    }

    func testUnreviewedCameraOrMissingWorldFailsClosed() {
        let good = frame()
        XCTAssertNil(AnatomySectionCut.make(
            section: .coronal, offsetInShoulderWidths: 0,
            frame: good, camera: camera(good, reviewed: false)
        ))
        XCTAssertNil(AnatomySectionCut.make(
            section: .axial, offsetInShoulderWidths: 2,
            frame: good, camera: camera(good)
        ))
        XCTAssertNil(AnatomySectionCut.make(
            section: .sagittal,
            offsetInShoulderWidths: .nan,
            frame: good, camera: camera(good)
        ))
        let missing = frame(noWorld: true)
        XCTAssertNil(AnatomySectionCut.make(
            section: .axial,
            offsetInShoulderWidths: 0,
            frame: missing, camera: camera(missing)
        ))
    }
}

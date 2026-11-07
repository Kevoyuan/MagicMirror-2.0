import CoreGraphics
import Foundation
import XCTest
import simd
@testable import MagicMirror

/// Entirely synthetic reference geometry. These tests DO NOT bundle or
/// assert approval of a real Z-Anatomy/BodyParts3D derivative.
final class AtlasWorldProjectionTests: XCTestCase {
    private let trackedIDs = [0, 7, 8, 11, 12, 13, 14, 15,
                              16, 23, 24, 25, 26, 27, 28]

    private func pose(withWorld: Bool = true) -> PoseSnapshot {
        var image = Array(
            repeating: PosePoint(x: 0.5, y: 0.5, visibility: 0.98),
            count: 33
        )
        var world = Array(
            repeating: PoseWorldPoint(
                x: 0, y: 0, z: 0, visibility: 0.98
            ), count: 33
        )
        for (n, id) in trackedIDs.enumerated() {
            let x = Float(n % 5) * 0.17 - 0.33
            let y = Float(n / 5) * 0.2 - 0.36
            let z = Float((n * 2) % 7) * 0.07 - 0.2
            image[id] = PosePoint(
                x: CGFloat((360 + 390 * x) / 720),
                y: CGFloat((640 + 390 * y) / 1280),
                visibility: 0.98
            )
            world[id] = PoseWorldPoint(
                x: x, y: y, z: z, visibility: 0.98
            )
        }
        return PoseSnapshot(
            timestampMilliseconds: 1234,
            imageSize: CGSize(width: 720, height: 1280),
            points: image,
            worldPoints: withWorld ? world : []
        )
    }

    private func syntheticAsset() throws -> VerifiedAnatomyAtlas {
        let manifestJSON = """
        {
          "schemaVersion": 1,
          "sourceRepository": "synthetic fixture, not redistributable anatomy",
          "sourceRevision": "0000000000000000000000000000000000000000",
          "sourcePath": "test-only",
          "modelFile": "synthetic",
          "modelSHA256": "test",
          "licenseIds": [],
          "attribution": [],
          "modificationNotes": ["test only"],
          "reviewedForDistribution": false,
          "reviewedJointBindings": false,
          "parts": [{
            "sourceHierarchyPath": "synthetic/test-volume",
            "displayName": "Synthetic test triangle",
            "group": "arms",
            "fromLandmark": 11,
            "toLandmark": 13,
            "restFrom": [0, 0, 0],
            "restTo": [1, 0, 0],
            "vertexOffset": 0,
            "vertexCount": 3
          }]
        }
        """
        let manifest = try JSONDecoder().decode(
            MobileAtlasManifest.self,
            from: Data(manifestJSON.utf8)
        )
        return VerifiedAnatomyAtlas(
            manifest: manifest,
            vertices: [
                AtlasRestVertex(
                    position: SIMD3<Float>(0, 0, 0),
                    normal: SIMD3<Float>(0, 0, 1)
                ),
                AtlasRestVertex(
                    position: SIMD3<Float>(0.5, 0.1, 0),
                    normal: SIMD3<Float>(0, 0, 1)
                ),
                AtlasRestVertex(
                    position: SIMD3<Float>(1, 0, 0),
                    normal: SIMD3<Float>(0, 0, 1)
                )
            ]
        )
    }

    func testSyntheticTrianglesProjectUsingWorldPoseFit() throws {
        let atlas = try syntheticAsset()
        let geometry = atlas.makeProjectedMesh(
            snapshot: pose(), viewport: CGSize(width: 390, height: 844),
            opacity: 0.7, focus: .arms
        )
        XCTAssertEqual(geometry.count, 3)
        XCTAssertTrue(geometry.allSatisfy {
            $0.position.x.isFinite && $0.position.y.isFinite &&
            $0.position.z.isFinite && $0.normal.x.isFinite &&
            $0.normal.y.isFinite && $0.normal.z.isFinite
        })
        XCTAssertGreaterThan(geometry[0].color.w, 0)
    }

    func testAtlasHidesWhenWorldPoseOrProjectionMissing() throws {
        let atlas = try syntheticAsset()
        let projected = atlas.makeProjectedMesh(
            snapshot: pose(withWorld: false),
            viewport: CGSize(width: 390, height: 844),
            opacity: 0.7, focus: .arms
        )
        XCTAssertTrue(projected.isEmpty)
    }

    func testFocusDoesNotPublishUnreviewedRegion() throws {
        let atlas = try syntheticAsset()
        XCTAssertTrue(atlas.makeProjectedMesh(
            snapshot: pose(), viewport: CGSize(width: 390, height: 844),
            opacity: 0.7, focus: .legs
        ).isEmpty)
    }
}

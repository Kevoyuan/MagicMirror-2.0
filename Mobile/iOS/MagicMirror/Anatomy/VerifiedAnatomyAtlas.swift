import CoreGraphics
import CryptoKit
import Foundation
import simd

/// The complete source atlas stays one coherent original FBX during
/// authoring. A *reviewed*, mobile-optimized package may store named
/// submeshes for GPU rendering; that does not invent a new anatomical source.
///
/// This package format does not establish correct camera extrinsics or
/// human anatomy by itself. No atlas binary is bundled by default.
struct MobileAtlasManifest: Decodable {
    let schemaVersion: Int
    let sourceRepository: String
    let sourceRevision: String
    let sourcePath: String
    let modelFile: String
    let modelSHA256: String
    let licenseIds: [String]
    let attribution: [String]
    let modificationNotes: [String]
    let reviewedForDistribution: Bool
    let reviewedJointBindings: Bool
    let parts: [MobileAtlasBinding]
}

struct MobileAtlasBinding: Decodable {
    let sourceHierarchyPath: String
    let displayName: String
    let group: String
    let fromLandmark: Int
    let toLandmark: Int
    let restFrom: [Float]
    let restTo: [Float]
    let vertexOffset: Int
    let vertexCount: Int

    var restSegment: (SIMD3<Float>, SIMD3<Float>)? {
        guard restFrom.count == 3, restTo.count == 3 else { return nil }
        let a = SIMD3<Float>(restFrom[0], restFrom[1], restFrom[2])
        let b = SIMD3<Float>(restTo[0], restTo[1], restTo[2])
        guard a.x.isFinite, a.y.isFinite, a.z.isFinite,
              b.x.isFinite, b.y.isFinite, b.z.isFinite,
              simd_length_squared(b - a) > 1e-10 else { return nil }
        return (a, b)
    }
}

struct AtlasRestVertex {
    let position: SIMD3<Float>
    let normal: SIMD3<Float>
}

enum MobileAtlasError: Error {
    case absent
    case unreviewed
    case invalidManifest
    case invalidHash
    case corruptMesh
}

/// A locally verified bundle: no URLSession, no runtime network, and no
/// unapproved third-party binary silently rendered as "real bones".
struct VerifiedAnatomyAtlas {
    let manifest: MobileAtlasManifest
    let vertices: [AtlasRestVertex]

    static func load(bundle: Bundle = .main) throws -> VerifiedAnatomyAtlas {
        guard let url = bundle.url(
            forResource: "skeleton_atlas.manifest", withExtension: "json"
        ) else { throw MobileAtlasError.absent }
        let manifest = try JSONDecoder().decode(
            MobileAtlasManifest.self, from: Data(contentsOf: url)
        )
        guard manifest.schemaVersion == 1,
              manifest.reviewedForDistribution,
              manifest.reviewedJointBindings else {
            throw MobileAtlasError.unreviewed
        }
        guard manifest.modelFile == "skeleton_atlas.mmgeom",
              manifest.sourceRevision.count == 40,
              !manifest.sourceRepository.isEmpty,
              !manifest.sourcePath.isEmpty,
              manifest.licenseIds.contains("CC BY-SA 4.0"),
              manifest.licenseIds.contains("CC BY-SA 2.1 Japan"),
              manifest.attribution.contains(where: { $0.contains("Z-Anatomy") }),
              manifest.attribution.contains(where: { $0.contains("BodyParts3D") }),
              !manifest.modificationNotes.isEmpty,
              manifest.modelSHA256.count == 64,
              !manifest.parts.isEmpty else {
            throw MobileAtlasError.invalidManifest
        }

        guard let meshURL = bundle.url(
            forResource: "skeleton_atlas", withExtension: "mmgeom"
        ) else { throw MobileAtlasError.absent }
        let modelData = try Data(contentsOf: meshURL, options: .mappedIfSafe)
        let sha = SHA256.hash(data: modelData).map {
            String(format: "%02x", $0)
        }.joined()
        guard sha == manifest.modelSHA256.lowercased() else {
            throw MobileAtlasError.invalidHash
        }
        let vertices = try decodeMesh(modelData)
        var cursor = 0
        var seen = Set<String>()
        for part in manifest.parts {
            guard part.vertexOffset == cursor, part.vertexCount >= 3,
                  part.vertexCount.isMultiple(of: 3),
                  part.vertexCount <= vertices.count - cursor,
                  part.fromLandmark != part.toLandmark,
                  (0..<33).contains(part.fromLandmark),
                  (0..<33).contains(part.toLandmark),
                  ["arms", "legs", "torso"].contains(part.group),
                  part.restSegment != nil,
                  !part.sourceHierarchyPath.isEmpty,
                  !part.displayName.isEmpty,
                  seen.insert(part.sourceHierarchyPath).inserted else {
                throw MobileAtlasError.invalidManifest
            }
            cursor += part.vertexCount
        }
        guard cursor == vertices.count else {
            throw MobileAtlasError.invalidManifest
        }
        return VerifiedAnatomyAtlas(manifest: manifest, vertices: vertices)
    }

    private static func decodeMesh(_ data: Data) throws -> [AtlasRestVertex] {
        // MMATLAS1 (8 ASCII bytes), UInt32 little-endian vertex count,
        // then six Float32 LE components per unindexed triangle vertex:
        // world-rest x/y/z, surface-normal x/y/z. No pixels or user data.
        let magic = Array("MMATLAS1".utf8)
        guard data.count >= 12,
              Array(data.prefix(8)) == magic else {
            throw MobileAtlasError.corruptMesh
        }
        return try data.withUnsafeBytes { raw in
            func readWord(_ offset: Int) -> UInt32 {
                UInt32(littleEndian: raw.loadUnaligned(
                    fromByteOffset: offset, as: UInt32.self
                ))
            }
            let count = Int(readWord(8))
            guard count > 0, count <= 180_000, count.isMultiple(of: 3),
                  data.count == 12 + count * 24 else {
                throw MobileAtlasError.corruptMesh
            }
            var result: [AtlasRestVertex] = []
            result.reserveCapacity(count)
            for i in 0..<count {
                let base = 12 + i * 24
                let v = SIMD3<Float>(
                    Float(bitPattern: readWord(base)),
                    Float(bitPattern: readWord(base + 4)),
                    Float(bitPattern: readWord(base + 8))
                )
                let n = SIMD3<Float>(
                    Float(bitPattern: readWord(base + 12)),
                    Float(bitPattern: readWord(base + 16)),
                    Float(bitPattern: readWord(base + 20))
                )
                guard v.x.isFinite, v.y.isFinite, v.z.isFinite,
                      n.x.isFinite, n.y.isFinite, n.z.isFinite,
                      simd_length_squared(n) > 1e-8 else {
                    throw MobileAtlasError.corruptMesh
                }
                result.append(AtlasRestVertex(
                    position: v, normal: simd_normalize(n)
                ))
            }
            return result
        }
    }

    /// Rigid whole-source submesh motion using HUMAN-REVIEWED rest anchors.
    /// This is an image-projected approximation, not calibrated 3D fitting
    /// and not valid if the subject rotates out of the expected pose plane.
    func makeProjectedMesh(
        snapshot: PoseSnapshot?, viewport: CGSize, opacity: Float,
        focus: AnatomyFocus
    ) -> [BoneMeshVertex] {
        guard let snapshot, snapshot.isUsable,
              viewport.width > 0, viewport.height > 0 else { return [] }
        var output: [BoneMeshVertex] = []
        output.reserveCapacity(vertices.count)
        let alpha = max(0, min(1, opacity))
        for part in manifest.parts {
            if focus == .arms && part.group != "arms" { continue }
            if focus == .legs && part.group != "legs" { continue }
            guard let (restFrom, restTo) = part.restSegment,
                  let targetFrom = VolumetricBoneMesh.sourcePoint(
                      index: part.fromLandmark,
                      snapshot: snapshot, viewport: viewport
                  ), let targetTo = VolumetricBoneMesh.sourcePoint(
                      index: part.toLandmark,
                      snapshot: snapshot, viewport: viewport
                  ) else { continue }

            let restAxis = restTo - restFrom
            let targetAxis = targetTo - targetFrom
            let restLength = simd_length(restAxis)
            let targetLength = simd_length(targetAxis)
            guard restLength > 1e-6, targetLength > 2,
                  targetLength.isFinite else { continue }
            let restDirection = restAxis / restLength
            let targetDirection = targetAxis / targetLength
            // Avoid an undefined antiparallel rotation without a reviewed
            // reference plane; do not invent mirrored joint geometry.
            guard simd_dot(restDirection, targetDirection) > -0.999 else {
                continue
            }
            let rotation = simd_quatf(
                from: restDirection, to: targetDirection
            )
            let scale = targetLength / restLength
            guard scale.isFinite, scale > 0 else { continue }

            let start = part.vertexOffset
            let end = start + part.vertexCount
            for v in vertices[start..<end] {
                let point = targetFrom +
                    rotation.act((v.position - restFrom) * scale)
                let normal = simd_normalize(rotation.act(v.normal))
                let w = Float(viewport.width)
                let h = Float(viewport.height)
                output.append(BoneMeshVertex(
                    position: SIMD4(
                        2 * point.x / w - 1,
                        1 - 2 * point.y / h,
                        max(-0.8, min(0.8, point.z / h)), 1
                    ),
                    normal: SIMD4(normal.x, -normal.y, normal.z, 0),
                    color: SIMD4(0.93, 0.89, 0.78, alpha * 0.58)
                ))
            }
        }
        return output
    }
}

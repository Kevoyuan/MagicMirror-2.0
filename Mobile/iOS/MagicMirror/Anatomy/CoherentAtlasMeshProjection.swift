import CoreGraphics
import Foundation
import simd

/// One projected triangle backed by an exact reviewed mesh/rig node path.
/// This is a geometry command, NOT proof that actual anatomy is calibrated.
struct CoherentAtlasTriangle {
    let boneId: String
    let sourceHierarchyPath: String
    let vertices: [ProjectedAtlasRestPoint]
    let cameraNormals: [SIMD3<Float>]
}

/// Fail-closed mesh-to-rig adapter. No draw commands are emitted unless the
/// *entire* atlas binding manifest matches the coherent hierarchy and every
/// selected triangle projects on the verified same source frame.
///
/// Deliberately does NOT substitute a weak-perspective atlas warp or guess
/// camera extrinsics. No default renderer uses this without an independently
/// reviewed asset and camera registration.
enum CoherentAtlasMeshProjection {
    static func project(
        atlas: VerifiedAnatomyAtlas,
        hierarchy: AnatomyAtlasManifest,
        projector: CoherentAtlasCameraProjection,
        viewport: CGSize,
        focus: AnatomyFocus
    ) -> [CoherentAtlasTriangle]? {
        guard (try? hierarchy.validateForUse()) != nil,
              atlas.manifest.reviewedForDistribution,
              atlas.manifest.reviewedJointBindings,
              atlas.manifest.sourceRevision == hierarchy.sourceRevision,
              viewport.width.isFinite, viewport.height.isFinite,
              viewport.width > 0, viewport.height > 0,
              !atlas.vertices.isEmpty, !atlas.manifest.parts.isEmpty,
              !projector.pose.bones.isEmpty
        else { return nil }

        let bindings = hierarchy.bones
        let namedPaths = Set(bindings.map(\.nodePath))
        guard namedPaths.count == bindings.count,
              projector.pose.bones.count == bindings.count,
              Set(projector.pose.bones.map(\.boneId))
                  == Set(bindings.map(\.id)) else { return nil }
        let byPath = Dictionary(
            uniqueKeysWithValues: bindings.map { ($0.nodePath, $0) }
        )

        // Validate every part, including out-of-focus parts, before
        // drawing even a single triangle. Prevent silent partial atlases.
        var cursor = 0
        var usedPaths = Set<String>()
        for part in atlas.manifest.parts {
            guard let bone = byPath[part.sourceHierarchyPath],
                  usedPaths.insert(part.sourceHierarchyPath).inserted,
                  bone.proximalLandmark == part.fromLandmark,
                  bone.distalLandmark == part.toLandmark,
                  let restFrom = part.restSegment?.0,
                  let restTo = part.restSegment?.1,
                  let boneFrom = bone.restStartPoint,
                  let boneTo = bone.restEndPoint,
                  simd_length(restFrom - boneFrom) <= 1e-4,
                  simd_length(restTo - boneTo) <= 1e-4,
                  part.vertexOffset == cursor,
                  part.vertexCount >= 3,
                  part.vertexCount.isMultiple(of: 3),
                  part.vertexCount <= atlas.vertices.count - cursor,
                  projector.pose.bone(bone.id) != nil
            else { return nil }
            cursor += part.vertexCount
        }
        guard usedPaths == namedPaths,
              cursor == atlas.vertices.count else { return nil }

        var output: [CoherentAtlasTriangle] = []
        output.reserveCapacity(atlas.vertices.count / 3)
        for part in atlas.manifest.parts {
            if focus == .arms && part.group != "arms" { continue }
            if focus == .legs && part.group != "legs" { continue }
            guard let binding = byPath[part.sourceHierarchyPath] else {
                return nil
            }
            let end = part.vertexOffset + part.vertexCount
            for index in stride(from: part.vertexOffset, to: end, by: 3) {
                var projected: [ProjectedAtlasRestPoint] = []
                var normals: [SIMD3<Float>] = []
                projected.reserveCapacity(3)
                normals.reserveCapacity(3)
                for j in index..<(index + 3) {
                    guard let point = projector.project(
                        boneId: binding.id,
                        restPoint: atlas.vertices[j].position,
                        viewport: viewport
                    ),
                    let normal = projector.cameraNormal(
                        boneId: binding.id,
                        restNormal: atlas.vertices[j].normal
                    ) else { return nil }
                    projected.append(point)
                    normals.append(normal)
                }
                output.append(CoherentAtlasTriangle(
                    boneId: binding.id,
                    sourceHierarchyPath: part.sourceHierarchyPath,
                    vertices: projected,
                    cameraNormals: normals
                ))
            }
        }
        return output
    }
}

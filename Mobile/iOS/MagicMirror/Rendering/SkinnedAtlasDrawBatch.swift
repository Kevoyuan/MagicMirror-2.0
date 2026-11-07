import CoreGraphics
import Foundation
import simd

/// Four-influence unindexed rest vertex. Keep layout identical to the
/// Metal SkinnedAtlasVertex (five SIMD4 = 80 bytes).
struct SkinnedAtlasVertex {
    let position: SIMD4<Float>
    let normal: SIMD4<Float>
    let color: SIMD4<Float>
    let joints: SIMD4<UInt32>
    let weights: SIMD4<Float>
}

/// Explicit author-reviewed LBS bindings, one per exported MMATLAS1
/// triangle vertex. A mesh name or proximity heuristic cannot create
/// these bindings. Bone indices follow the reviewed hierarchy order.
struct AtlasSkinInfluence {
    let joints: SIMD4<UInt32>
    let weights: SIMD4<Float>

    func isValid(boneCount: Int) -> Bool {
        guard boneCount > 0 else { return false }
        var sum: Float = 0
        for i in 0..<4 {
            let weight = weights[i]
            guard weight.isFinite, weight >= 0, weight <= 1,
                  Int(joints[i]) < boneCount else { return false }
            sum += weight
        }
        return abs(sum - 1) <= 0.001
    }
}

/// Frame-bound hardware skinning input. The CPU uploads rest vertices and
/// camera-space bone transforms; blending and perspective projection run
/// in the Metal vertex shader, with no CPU skinned triangle regeneration.
///
/// No approved skinning weights currently ship with MagicMirror; until
/// audited weights and separately calibrated camera extrinsics exist, the
/// existing procedural/rigid atlas renderer remains the active fallback.
struct SkinnedAtlasDrawBatch {
    let sourceTimestampMilliseconds: Int
    let sourceImageSize: CGSize
    let viewportSize: CGSize
    let sourceRevision: String
    /// Unique to an immutable reviewed runtime resource set; never reused
    /// when a new atlas / approved weight set is installed.
    let geometryIdentity: UUID
    let focus: AnatomyFocus
    let opacity: Float
    let vertices: [SkinnedAtlasVertex]
    let cameraMatrices: [simd_float4x4]
    let cameraParameters: SIMD4<Float> // fx, fy, cx, cy
    let viewportParameters: SIMD4<Float> // scale, xCrop, yCrop, depthRange
    let sectionPlane: SIMD4<Float>

    func matches(
        frame: PoseSnapshot,
        viewport: CGSize,
        focus: AnatomyFocus,
        opacity: Float
    ) -> Bool {
        sourceTimestampMilliseconds == frame.timestampMilliseconds &&
        sourceImageSize == frame.imageSize &&
        viewportSize == viewport &&
        self.focus == focus &&
        self.opacity == opacity &&
        frame.hasTorsoAnchor &&
        !vertices.isEmpty &&
        !cameraMatrices.isEmpty
    }

    static func build(
        atlas: VerifiedAnatomyAtlas,
        hierarchy: AnatomyAtlasManifest,
        projector: CoherentAtlasCameraProjection,
        influences: [AtlasSkinInfluence],
        viewport: CGSize,
        focus: AnatomyFocus,
        opacity: Float,
        sectionCut: AnatomySectionCut? = nil,
        geometryIdentity: UUID = UUID(),
        preparedVertices: [SkinnedAtlasVertex]? = nil
    ) -> SkinnedAtlasDrawBatch? {
        guard (try? hierarchy.validateForUse()) != nil,
              atlas.manifest.reviewedForDistribution,
              atlas.manifest.reviewedJointBindings,
              atlas.manifest.sourceRevision == hierarchy.sourceRevision,
              projector.pose.bones.count == hierarchy.bones.count,
              atlas.vertices.count == influences.count,
              atlas.vertices.count > 0,
              atlas.vertices.count <= 180_000,
              viewport.width.isFinite, viewport.height.isFinite,
              viewport.width > 0, viewport.height > 0,
              opacity.isFinite, opacity > 0, opacity <= 1,
              let intrinsics = projector.sourceIntrinsics,
              intrinsics.matches(image: projector.pose.sourceImageSize)
        else { return nil }

        let bones = hierarchy.bones
        guard bones.count <= 256,
              Set(bones.map(\.id)).count == bones.count,
              Set(bones.map(\.nodePath)).count == bones.count,
              Set(projector.pose.bones.map(\.boneId))
                  == Set(bones.map(\.id)),
              (preparedVertices != nil || influences.allSatisfy({
                  $0.isValid(boneCount: bones.count)
              }))
        else { return nil }

        let byPath = Dictionary(uniqueKeysWithValues: bones.map {
            ($0.nodePath, $0)
        })
        var cursor = 0
        var included: [SkinnedAtlasVertex] = preparedVertices ?? []
        if preparedVertices == nil {
            included.reserveCapacity(atlas.vertices.count)
        }
        // Static color lives in the cached GPU buffer. Live opacity is
        // sent as a tiny uniform instead of rebuilding all mesh vertices.
        let color = SIMD4<Float>(0.93, 0.89, 0.78, 1)
        var names = Set<String>()
        var expectedVertexCount = 0
        for part in atlas.manifest.parts {
            guard let bone = byPath[part.sourceHierarchyPath],
                  names.insert(part.sourceHierarchyPath).inserted,
                  part.fromLandmark == bone.proximalLandmark,
                  part.toLandmark == bone.distalLandmark,
                  let anchorA = part.restSegment?.0,
                  let anchorB = part.restSegment?.1,
                  let restA = bone.restStartPoint,
                  let restB = bone.restEndPoint,
                  simd_length(anchorA - restA) <= 1e-4,
                  simd_length(anchorB - restB) <= 1e-4,
                  part.vertexOffset == cursor,
                  part.vertexCount >= 3,
                  part.vertexCount.isMultiple(of: 3),
                  part.vertexCount <= atlas.vertices.count - cursor
            else { return nil }
            cursor += part.vertexCount
            if focus == .arms && part.group != "arms" { continue }
            if focus == .legs && part.group != "legs" { continue }
            expectedVertexCount += part.vertexCount
            if preparedVertices != nil { continue }
            for index in part.vertexOffset..<cursor {
                let v = atlas.vertices[index]
                let skin = influences[index]
                guard simd_length_squared(v.normal) > 1e-8 else {
                    return nil
                }
                included.append(SkinnedAtlasVertex(
                    position: SIMD4<Float>(
                        v.position.x, v.position.y, v.position.z, 1
                    ),
                    normal: SIMD4<Float>(
                        v.normal.x, v.normal.y, v.normal.z, 0
                    ),
                    color: color,
                    joints: skin.joints, weights: skin.weights
                ))
            }
        }
        guard cursor == atlas.vertices.count,
              names == Set(bones.map(\.nodePath)),
              included.count == expectedVertexCount,
              !included.isEmpty
        else { return nil }

        var matrices: [simd_float4x4] = []
        matrices.reserveCapacity(bones.count)
        for bone in bones {
            guard let m = projector.cameraMatrix(boneId: bone.id) else {
                return nil
            }
            matrices.append(m)
        }

        // The capture is portrait-rotated and unmirrored; use the same
        // aspect-fill transformation as the video compositor.
        let image = projector.pose.sourceImageSize
        let scale = Float(max(
            viewport.width / image.width,
            viewport.height / image.height
        ))
        let dx = (Float(viewport.width) - Float(image.width) * scale) * 0.5
        let dy = (Float(viewport.height) - Float(image.height) * scale) * 0.5
        return SkinnedAtlasDrawBatch(
            sourceTimestampMilliseconds:
                projector.pose.sourceTimestampMilliseconds,
            sourceImageSize: image,
            viewportSize: viewport,
            sourceRevision: atlas.manifest.sourceRevision,
            geometryIdentity: geometryIdentity,
            focus: focus,
            opacity: opacity,
            vertices: included,
            cameraMatrices: matrices,
            cameraParameters: SIMD4(
                intrinsics.fx, intrinsics.fy, intrinsics.cx, intrinsics.cy
            ),
            viewportParameters: SIMD4(scale, dx, dy, 0),
            sectionPlane: sectionCut?.plane ?? SIMD4<Float>(repeating: 0)
        )
    }
}

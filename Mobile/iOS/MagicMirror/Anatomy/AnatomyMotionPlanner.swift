import Foundation
import simd

/// The solver intentionally outputs **relative joint commands**, NOT
/// camera-space/world-space bone positions. It cannot register unmeasured
/// bones onto a person without a reviewed atlas/camera transform.
struct AnatomyJointRotation {
    let boneId: String
    let referenceToCurrent: simd_quatf
    let restLength: Float
    let confidence: Float
}

enum AnatomyMotionPlanner {
    /// One explicit reference pose is used to define how body-relative
    /// MediaPipe axes map onto the reviewed atlas rig. Never infer this from
    /// the original FBX alone. This does not solve camera extrinsics.
    static func rotationCommands(
        manifest: AnatomyAtlasManifest,
        reference: PoseSnapshot,
        current: PoseSnapshot
    ) -> [AnatomyJointRotation] {
        guard (try? manifest.validateForUse()) != nil,
              reference.isUsable, current.isUsable,
              reference.worldPoints.count == 33,
              current.worldPoints.count == 33 else { return [] }

        return manifest.bones.compactMap { bone in
            let fromIndex = bone.proximalLandmark
            let toIndex = bone.distalLandmark
            let oldA = reference.worldPoints[fromIndex]
            let oldB = reference.worldPoints[toIndex]
            let newA = current.worldPoints[fromIndex]
            let newB = current.worldPoints[toIndex]
            guard oldA.isUsable, oldB.isUsable,
                  newA.isUsable, newB.isUsable,
                  let restStart = bone.restStartPoint,
                  let restEnd = bone.restEndPoint else { return nil }

            let old = SIMD3(oldB.x - oldA.x, oldB.y - oldA.y, oldB.z - oldA.z)
            let now = SIMD3(newB.x - newA.x, newB.y - newA.y, newB.z - newA.z)
            let oldLength = simd_length(old)
            let currentLength = simd_length(now)
            let referenceLength = simd_length(restEnd - restStart)
            guard oldLength > 1e-5, currentLength > 1e-5,
                  referenceLength > 1e-5,
                  oldLength.isFinite, currentLength.isFinite else {
                return nil
            }

            let from = old / oldLength
            let to = now / currentLength
            let dotProduct = max(-1, min(1, simd_dot(from, to)))
            let crossProduct = simd_cross(from, to)
            let crossLength = simd_length(crossProduct)

            let delta: simd_quatf
            if crossLength < 1e-6 {
                if dotProduct > 0 {
                    delta = simd_quatf(angle: 0, axis: SIMD3(0, 1, 0))
                } else {
                    // Stable perpendicular axis for a 180° turn.
                    let guide = abs(from.x) < 0.9
                        ? SIMD3<Float>(1, 0, 0) : SIMD3<Float>(0, 1, 0)
                    let axis = simd_normalize(simd_cross(from, guide))
                    delta = simd_quatf(angle: .pi, axis: axis)
                }
            } else {
                delta = simd_quatf(
                    angle: acos(dotProduct),
                    axis: crossProduct / crossLength
                )
            }
            return AnatomyJointRotation(
                boneId: bone.id,
                referenceToCurrent: delta,
                restLength: referenceLength,
                confidence: min(
                    oldA.visibility, oldB.visibility,
                    newA.visibility, newB.visibility
                )
            )
        }
    }
}

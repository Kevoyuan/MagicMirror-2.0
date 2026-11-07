import Foundation
import simd

/// Rest-to-current transform for one HUMAN-REVIEWED atlas bone.
/// All coordinates are in atlas-root local units, NOT camera meters/pixels.
/// This is a rigid transform with preserved bone length, not a mesh skin.
struct AtlasRigBonePose {
    let boneId: String
    let parentId: String?
    let restPivot: SIMD3<Float>
    let posedPivot: SIMD3<Float>
    let restToPosedRotation: simd_quatf
    let restLength: Float
    let confidence: Float

    func transformRestPoint(_ source: SIMD3<Float>) -> SIMD3<Float>? {
        guard Self.finite(source) else { return nil }
        let result = posedPivot + simd_act(
            restToPosedRotation, source - restPivot
        )
        return Self.finite(result) ? result : nil
    }

    private static func finite(_ v: SIMD3<Float>) -> Bool {
        v.x.isFinite && v.y.isFinite && v.z.isFinite
    }
}

/// A complete, connected atlas-space frame. No individual part is exposed
/// as successful if a single reviewed parent-child attachment fails.
struct CoherentAtlasRigPose {
    let bones: [AtlasRigBonePose]

    func bone(_ id: String) -> AtlasRigBonePose? {
        bones.first { $0.boneId == id }
    }
}

/// Conservative forward-kinematics planner for approved bone bindings.
///
/// 1. Anatomical rest positions come ONLY from reviewed, coherent atlas
///    anchors, not inferred body joints or hand-authored fake bone centers.
/// 2. A frozen reference pose and separately reviewed body->atlas similarity
///    are REQUIRED. Neither can establish phone camera extrinsics.
/// 3. Each child pivot moves with its parent transform. Child rotations
///    align a measured limb direction but never independently teleport
///    the child's origin onto a noisy image landmark.
/// 4. Bone lengths stay fixed. Bad confidence, noisy length estimates,
///    ambiguous reversal, wrong hierarchy or floating joints fail closed.
///
/// This class returns atlas-space pose commands; it does NOT claim to
/// have loaded a licensed Z-Anatomy USDZ, driven a real skinned skeleton,
/// resolved full-body twist, or calibrated a physical RGB camera.
enum CoherentAtlasRigPlanner {
    struct Limits {
        let maximumRestAngleRadians: Float
        let maximumCurrentAngleRadians: Float
        let maximumLengthErrorFraction: Float
        let maximumAttachmentErrorFraction: Float

        static let conservative = Limits(
            maximumRestAngleRadians: 0.52, // 30 degrees, source assumption
            maximumCurrentAngleRadians: 2.79, // ~160 deg, no antiparallel
            maximumLengthErrorFraction: 0.35,
            maximumAttachmentErrorFraction: 0.20
        )

        var isValid: Bool {
            maximumRestAngleRadians.isFinite &&
            maximumRestAngleRadians >= 0 &&
            maximumRestAngleRadians < .pi &&
            maximumCurrentAngleRadians.isFinite &&
            maximumCurrentAngleRadians > 0 &&
            maximumCurrentAngleRadians < .pi &&
            maximumLengthErrorFraction.isFinite &&
            maximumLengthErrorFraction >= 0 &&
            maximumLengthErrorFraction <= 1 &&
            maximumAttachmentErrorFraction.isFinite &&
            maximumAttachmentErrorFraction >= 0 &&
            maximumAttachmentErrorFraction <= 1
        }
    }

    static func plan(
        manifest: AnatomyAtlasManifest,
        reference: PoseSnapshot,
        current: PoseSnapshot,
        registration: BodySimilarityRegistration,
        limits: Limits = .conservative
    ) -> CoherentAtlasRigPose? {
        guard limits.isValid,
              (try? manifest.validateForUse()) != nil,
              reference.isUsable, current.isUsable,
              reference.worldPoints.count == 33,
              current.worldPoints.count == 33,
              reference.imageSize == current.imageSize,
              current.timestampMilliseconds >= reference.timestampMilliseconds
        else { return nil }

        let bindings = Dictionary(
            uniqueKeysWithValues: manifest.bones.map { ($0.id, $0) }
        )
        var results: [String: AtlasRigBonePose] = [:]
        var visiting = Set<String>()

        func resolve(_ id: String) -> AtlasRigBonePose? {
            if let existing = results[id] { return existing }
            guard visiting.insert(id).inserted, let binding = bindings[id],
                  let restFrom = binding.restStartPoint,
                  let restTo = binding.restEndPoint else { return nil }
            defer { visiting.remove(id) }

            let fromIndex = binding.proximalLandmark
            let toIndex = binding.distalLandmark
            let oldA = reference.worldPoints[fromIndex]
            let oldB = reference.worldPoints[toIndex]
            let nowA = current.worldPoints[fromIndex]
            let nowB = current.worldPoints[toIndex]
            guard oldA.isUsable, oldB.isUsable,
                  nowA.isUsable, nowB.isUsable else { return nil }

            func point(_ p: PoseWorldPoint) -> SIMD3<Float> {
                SIMD3(p.x, p.y, p.z)
            }
            guard let oldFrom = registration.bodyToAtlas(point(oldA)),
                  let oldTo = registration.bodyToAtlas(point(oldB)),
                  let measuredFrom = registration.bodyToAtlas(point(nowA)),
                  let measuredTo = registration.bodyToAtlas(point(nowB))
            else { return nil }

            let restAxis = restTo - restFrom
            let originalLength = simd_length(restAxis)
            let referenceAxis = oldTo - oldFrom
            let referenceLength = simd_length(referenceAxis)
            let currentAxis = measuredTo - measuredFrom
            let measuredLength = simd_length(currentAxis)
            guard originalLength.isFinite && originalLength > 1e-6,
                  referenceLength.isFinite && referenceLength > 1e-6,
                  measuredLength.isFinite && measuredLength > 1e-6 else {
                return nil
            }

            // An erroneous joint identity or rest scale cannot silently
            // become a new limb. Both reference and live lengths must
            // match a human-reviewed atlas segment within the tolerances.
            let referenceError = abs(referenceLength - originalLength)
                / originalLength
            let currentError = abs(measuredLength - originalLength)
                / originalLength
            guard referenceError <= limits.maximumLengthErrorFraction,
                  currentError <= limits.maximumLengthErrorFraction else {
                return nil
            }

            let restDirection = restAxis / originalLength
            let referenceDirection = referenceAxis / referenceLength
            let currentDirection = currentAxis / measuredLength
            let restAngle = angle(restDirection, referenceDirection)
            let currentAngle = angle(restDirection, currentDirection)
            guard restAngle.isFinite && currentAngle.isFinite,
                  restAngle <= limits.maximumRestAngleRadians,
                  currentAngle <= limits.maximumCurrentAngleRadians else {
                return nil
            }

            // A shortest-arc rotation cannot determine twist about a bone.
            // It is only an atlas-root-local direction command.
            let delta = simd_quatf(
                from: restDirection, to: currentDirection
            )
            let quaternion = delta.vector
            guard quaternion.x.isFinite, quaternion.y.isFinite,
                  quaternion.z.isFinite, quaternion.w.isFinite,
                  abs(simd_length(quaternion) - 1) <= 0.005 else {
                return nil
            }

            let posedPivot: SIMD3<Float>
            if let parentId = binding.parentId {
                guard let parent = resolve(parentId),
                      let parentAttachment = parent.transformRestPoint(
                        restFrom
                      ) else { return nil }
                // The child origin is always attached by FK to the parent;
                // independent noisy landmarks only validate that location.
                let error = simd_length(parentAttachment - measuredFrom)
                    / max(originalLength, parent.restLength)
                guard error.isFinite,
                      error <= limits.maximumAttachmentErrorFraction else {
                    return nil
                }
                posedPivot = parentAttachment
            } else {
                // Root position comes from observed body coordinates in
                // the same FROZEN atlas frame, never from camera pixels.
                posedPivot = measuredFrom
            }

            let pose = AtlasRigBonePose(
                boneId: binding.id, parentId: binding.parentId,
                restPivot: restFrom, posedPivot: posedPivot,
                restToPosedRotation: delta,
                restLength: originalLength,
                confidence: min(
                    oldA.visibility, oldB.visibility,
                    nowA.visibility, nowB.visibility
                )
            )
            results[id] = pose
            return pose
        }

        // Resolve in manifest order but always follow ancestors first.
        for binding in manifest.bones {
            guard resolve(binding.id) != nil else { return nil }
        }
        let ordered = manifest.bones.compactMap { results[$0.id] }
        guard ordered.count == manifest.bones.count else { return nil }
        return CoherentAtlasRigPose(bones: ordered)
    }

    private static func angle(
        _ a: SIMD3<Float>, _ b: SIMD3<Float>
    ) -> Float {
        acos(max(-1, min(1, simd_dot(a, b))))
    }
}

import CoreGraphics
import Foundation
import simd

/// A series of reprojected MediaPipe model-space hypotheses may be
/// numerically coherent but is still NOT independently reviewed camera
/// extrinsics and must not unlock a reviewed anatomy atlas.
///
/// Reject same-frame replay, missing estimates, large jumps, yaw flips,
/// poor reprojection, missing joints and camera-resolution changes.
struct CameraCandidateTemporalGate {
    private let requiredConsecutive: Int
    private let maxGapMilliseconds: Int
    private let maximumTranslationMeters: Float
    private let maximumRotationRadians: Float

    private var prior: AutomaticCameraPoseCandidate?
    private var consecutive = 0

    init(requiredConsecutive: Int = 3,
         maxGapMilliseconds: Int = 2_000,
         maximumTranslationMeters: Float = 0.55,
         maximumRotationRadians: Float = 0.40) {
        precondition(requiredConsecutive >= 2)
        precondition(maxGapMilliseconds > 0)
        precondition(maximumTranslationMeters.isFinite &&
                     maximumTranslationMeters > 0)
        precondition(maximumRotationRadians.isFinite &&
                     maximumRotationRadians > 0)
        self.requiredConsecutive = requiredConsecutive
        self.maxGapMilliseconds = maxGapMilliseconds
        self.maximumTranslationMeters = maximumTranslationMeters
        self.maximumRotationRadians = maximumRotationRadians
    }

    mutating func reset() {
        prior = nil
        consecutive = 0
    }

    mutating func observe(
        _ candidate: AutomaticCameraPoseCandidate?
    ) -> AutomaticCameraPoseCandidate? {
        guard let candidate,
              candidate.transform.isValid,
              candidate.landmarkCount >= 9,
              candidate.p90ReprojectionErrorFractionOfWidth.isFinite,
              (0...0.03).contains(
                candidate.p90ReprojectionErrorFractionOfWidth
              ),
              candidate.imageSize.width.isFinite,
              candidate.imageSize.height.isFinite,
              candidate.imageSize.width > 0,
              candidate.imageSize.height > 0,
              candidate.timestampMilliseconds >= 0
        else {
            reset()
            return nil
        }

        if let prior {
            let delta = candidate.timestampMilliseconds -
                prior.timestampMilliseconds
            // MediaPipe "world" coordinates do not establish surveyed
            // extrinsics. These are continuity checks for diagnostics.
            let distance = simd_distance(
                candidate.transform.translation,
                prior.transform.translation
            )
            let cosine = abs(simd_dot(
                candidate.transform.rotation.vector,
                prior.transform.rotation.vector
            ))
            let angle = 2 * acos(min(1, max(0, cosine)))
            if delta <= 0 || delta > maxGapMilliseconds ||
                candidate.imageSize != prior.imageSize ||
                !distance.isFinite || distance > maximumTranslationMeters ||
                !angle.isFinite || angle > maximumRotationRadians {
                // Restart with a plausible new pose, never certify a
                // yaw-flipped or moved camera from the previous session.
                reset()
            }
        }

        if prior == nil {
            consecutive = 1
        } else {
            consecutive += 1
        }
        prior = candidate
        return consecutive >= requiredConsecutive ? candidate : nil
    }
}

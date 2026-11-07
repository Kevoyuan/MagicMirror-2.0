import CoreGraphics
import Foundation
import simd

/// A strict, explicitly UNREVIEWED camera/body alignment for showing
/// a previously LICENSED/REVIEWED generic reference atlas. No normal
/// RGB photograph reveals measured internal bones.
///
/// AutomaticCameraPoseEstimator runs separately at a throttled cadence;
/// on each new source frame this fast gate checks the candidate against
/// the latest observed 2D/3D points, requiring several consecutive
/// coherent frames before a short-lived provisional reference may draw.
struct AutomaticReferenceAlignmentGate {
    private var stableCount = 0
    private var lastTimestamp = -1
    private var lastSize: CGSize?
    private var lastCandidateTimestamp = -1

    mutating func reset() {
        stableCount = 0
        lastTimestamp = -1
        lastSize = nil
        lastCandidateTimestamp = -1
    }

    mutating func alignedFrame(
        for frame: PoseSnapshot,
        candidate: AutomaticCameraPoseCandidate?
    ) -> ReviewedSourceCameraFrame? {
        guard frame.hasTorsoAnchor, frame.worldPoints.count == 33,
              let camera = frame.cameraIntrinsics,
              camera.matches(image: frame.imageSize),
              let candidate,
              candidate.imageSize == frame.imageSize,
              candidate.transform.isValid,
              candidate.landmarkCount >= 12,
              candidate.p90ReprojectionErrorFractionOfWidth.isFinite,
              candidate.p90ReprojectionErrorFractionOfWidth <= 0.012,
              candidate.timestampMilliseconds <= frame.timestampMilliseconds,
              frame.timestampMilliseconds -
                candidate.timestampMilliseconds <= 900,
              frame.timestampMilliseconds > lastTimestamp,
              (lastTimestamp < 0 ||
                frame.timestampMilliseconds - lastTimestamp <= 160),
              (lastSize == nil || lastSize == frame.imageSize),
              (lastCandidateTimestamp < 0 ||
               candidate.timestampMilliseconds >= lastCandidateTimestamp),
              let report = BodyReprojectionGate.evaluate(
                snapshot: frame, camera: camera,
                transform: candidate.transform,
                requiredVisiblePoints: 12,
                p90LimitFractionOfImageWidth: 0.012
              ),
              report.accepted, report.visibleCount >= 12,
              report.maximumErrorFractionOfImageWidth <= 0.048
        else {
            reset()
            return nil
        }

        // Require both torso shoulders and hips to project locally well,
        // not merely a permissive global 90th percentile.
        for id in [11, 12, 23, 24] {
            let world = frame.worldPoints[id]
            let image = frame.points[id]
            guard world.isUsable, image.isUsable,
                  let mapped = BodyCameraProjection.project(
                    bodyWorld: SIMD3(world.x, world.y, world.z),
                    camera: camera,
                    bodyToCamera: candidate.transform
                  )
            else {
                reset()
                return nil
            }
            let dx = mapped.normalizedX - Float(image.x)
            let dy = mapped.normalizedY - Float(image.y)
            let scaledDy = dy * camera.height / camera.width
            guard hypot(dx, scaledDy) <= 0.016 else {
                reset()
                return nil
            }
        }

        if candidate.timestampMilliseconds != lastCandidateTimestamp &&
           lastCandidateTimestamp >= 0 &&
           candidate.timestampMilliseconds - lastCandidateTimestamp > 950 {
            stableCount = 0
        }
        stableCount = min(8, stableCount + 1)
        lastTimestamp = frame.timestampMilliseconds
        lastSize = frame.imageSize
        lastCandidateTimestamp = candidate.timestampMilliseconds
        guard stableCount >= 5 else { return nil }

        // Independent physical review is NOT claimed. The companion
        // shader, UI and metadata must keep the "estimated reference"
        // disclosure; this flag is never used to approve model licenses.
        return ReviewedSourceCameraFrame(
            timestampMilliseconds: frame.timestampMilliseconds,
            imageSize: frame.imageSize,
            intrinsics: camera,
            bodyToCamera: candidate.transform,
            independentReviewConfirmed: false,
            estimatedReferenceOnly: true
        )
    }
}

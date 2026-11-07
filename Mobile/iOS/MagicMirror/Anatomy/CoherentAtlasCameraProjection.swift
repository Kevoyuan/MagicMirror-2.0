import CoreGraphics
import Foundation
import simd

/// Pure projection result for a single atlas rest vertex on the SAME
/// capture frame used to plan the coherent rig pose.
/// This remains an educational reference illustration, not real bones.
struct ProjectedAtlasRestPoint {
    let displayPosition: CGPoint
    let sourceNormalizedPosition: CGPoint
    let cameraDepthMeters: Float
}

/// Fail-closed connection from reviewed 3D forward kinematics to the
/// calibrated mobile camera. A separate same-frame pose P90 gate must pass
/// before ANY anatomical rest vertex can be projected.
///
/// NEVER supply guessed camera extrinsics. The normal product cannot
/// enable this without independently reviewed camera/body calibration.
/// This is a source-level integration seam, not actual phone AR validation.
struct CoherentAtlasCameraProjection {
    let pose: CoherentAtlasRigPose
    let reprojection: BodyReprojectionReport

    private let registration: BodySimilarityRegistration
    private let intrinsics: BodyCameraIntrinsics
    private let extrinsics: BodyToCameraTransform

    static func prepare(
        pose: CoherentAtlasRigPose,
        matchingFrame: PoseSnapshot,
        registration: BodySimilarityRegistration,
        intrinsics: BodyCameraIntrinsics,
        extrinsics: BodyToCameraTransform,
        independentCameraReviewConfirmed: Bool,
        maximumP90FractionOfSourceWidth: Float = 0.03
    ) -> CoherentAtlasCameraProjection? {
        guard independentCameraReviewConfirmed,
              pose.sourceTimestampMilliseconds
                == matchingFrame.timestampMilliseconds,
              pose.sourceImageSize == matchingFrame.imageSize,
              !pose.bones.isEmpty,
              intrinsics.matches(image: matchingFrame.imageSize),
              maximumP90FractionOfSourceWidth.isFinite,
              maximumP90FractionOfSourceWidth > 0,
              maximumP90FractionOfSourceWidth <= 0.03,
              let report = BodyReprojectionGate.evaluate(
                snapshot: matchingFrame,
                camera: intrinsics,
                transform: extrinsics,
                requiredVisiblePoints: 6,
                p90LimitFractionOfImageWidth:
                    maximumP90FractionOfSourceWidth
              ),
              report.accepted
        else { return nil }

        return CoherentAtlasCameraProjection(
            pose: pose, reprojection: report,
            registration: registration,
            intrinsics: intrinsics, extrinsics: extrinsics
        )
    }

    /// Project one REVIEWED rest vertex via the complete chain:
    /// atlas rest -> articulated atlas pose -> estimated body world ->
    /// independently reviewed calibrated RGB camera -> source video pixel
    /// -> the SAME aspect-fill crop used for the displayed source frame.
    func project(
        boneId: String, restPoint: SIMD3<Float>,
        viewport: CGSize
    ) -> ProjectedAtlasRestPoint? {
        guard viewport.width.isFinite, viewport.height.isFinite,
              viewport.width > 0, viewport.height > 0,
              let bone = pose.bone(boneId),
              let atlasPoint = bone.transformRestPoint(restPoint),
              let bodyWorldPoint = registration.atlasToBody(atlasPoint),
              let cameraProjection = BodyCameraProjection.project(
                bodyWorld: bodyWorldPoint,
                camera: intrinsics,
                bodyToCamera: extrinsics
              ),
              let display = PoseSkeleton.pointInPreview(
                PosePoint(
                    x: CGFloat(cameraProjection.normalizedX),
                    y: CGFloat(cameraProjection.normalizedY),
                    visibility: 1
                ),
                imageSize: pose.sourceImageSize,
                viewSize: viewport
              ) else { return nil }

        return ProjectedAtlasRestPoint(
            displayPosition: display,
            sourceNormalizedPosition: CGPoint(
                x: CGFloat(cameraProjection.normalizedX),
                y: CGFloat(cameraProjection.normalizedY)
            ),
            cameraDepthMeters: cameraProjection.depthMeters
        )
    }
}

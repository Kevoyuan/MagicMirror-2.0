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

    /// Transform one actual source-mesh rest normal with exactly the
    /// same rigid bone motion, atlas-body orientation, and calibrated
    /// body-camera rotation as its corresponding source vertex.
    func cameraNormal(
        boneId: String, restNormal: SIMD3<Float>
    ) -> SIMD3<Float>? {
        guard extrinsics.isValid,
              let bone = pose.bone(boneId),
              restNormal.x.isFinite, restNormal.y.isFinite,
              restNormal.z.isFinite,
              simd_length_squared(restNormal) > 1e-8
        else { return nil }
        let atlas = simd_act(bone.restToPosedRotation, restNormal)
        guard let body = registration.atlasDirectionToBody(atlas) else {
            return nil
        }
        let camera = simd_act(extrinsics.rotation, body)
        guard camera.x.isFinite, camera.y.isFinite,
              camera.z.isFinite,
              simd_length_squared(camera) > 1e-8 else { return nil }
        return simd_normalize(camera)
    }

    /// Expose actual per-frame camera pixels only after prepare() has
    /// passed independently reviewed extrinsics and P90 reprojection.
    var sourceIntrinsics: BodyCameraIntrinsics? {
        intrinsics.matches(image: pose.sourceImageSize)
            ? intrinsics : nil
    }

    /// Affine atlas-rest -> oriented camera-space transform for GPU
    /// linear blend skinning. The rest atlas is in source coordinates,
    /// while the approved camera projection uses meters and +Z forward.
    /// Rigid bone motion, atlas-body similarity, and camera orientation
    /// are combined here; the vertex shader never guesses calibration.
    func cameraMatrix(boneId: String) -> simd_float4x4? {
        guard extrinsics.isValid,
              let bone = pose.bone(boneId) else { return nil }

        func point(_ rest: SIMD3<Float>) -> SIMD3<Float>? {
            guard let atlas = bone.transformRestPoint(rest),
                  let body = registration.atlasToBody(atlas)
            else { return nil }
            let camera = simd_act(extrinsics.rotation, body) +
                extrinsics.translation
            guard camera.x.isFinite, camera.y.isFinite,
                  camera.z.isFinite else { return nil }
            return camera
        }

        guard let origin = point(SIMD3<Float>(0, 0, 0)),
              let x = point(SIMD3<Float>(1, 0, 0)),
              let y = point(SIMD3<Float>(0, 1, 0)),
              let z = point(SIMD3<Float>(0, 0, 1))
        else { return nil }
        let matrix = simd_float4x4(columns: (
            SIMD4<Float>(x - origin, 0),
            SIMD4<Float>(y - origin, 0),
            SIMD4<Float>(z - origin, 0),
            SIMD4<Float>(origin, 1)
        ))
        return matrix.columns.0.x.isFinite &&
            matrix.columns.1.y.isFinite &&
            matrix.columns.2.z.isFinite &&
            matrix.columns.3.z.isFinite ? matrix : nil
    }
}

using MagicMirror.Motion;
using UnityEngine;

namespace MagicMirror.Anatomy
{
    /// <summary>
    /// Explicitly measured camera intrinsics and camera pose in MediaPipe's
    /// estimated body-world coordinate frame for ONE frozen reference pose.
    /// NO values here are inferred from window aspect or model shoulder width.
    ///
    /// This profile is intentionally INVALID by default, and cannot activate
    /// the camera-aligned anatomy until both source lens and coordinate-axis
    /// reviews are manually confirmed. It is NOT an automatic PnP solution.
    /// </summary>
    [CreateAssetMenu(fileName = "ReviewedCameraCalibration",
        menuName = "MagicMirror/Calibration/Reviewed Source Camera")]
    public sealed class ReviewedCameraCalibrationProfile : ScriptableObject
    {
        [Header("Independent source camera measurement")]
        public bool sourceIntrinsicsReviewed;
        public bool sourceExtrinsicsReviewed;
        [Tooltip("Original (unmirrored) JPEG pixel dimensions; never UI window size.")]
        public int sourceWidth;
        public int sourceHeight;
        [Tooltip("fx / sourceWidth, fy / sourceHeight")]
        public float normalizedFocalX;
        public float normalizedFocalY;
        [Tooltip("cx / sourceWidth, cy / sourceHeight; top-left source origin")]
        public float normalizedCenterX;
        public float normalizedCenterY;

        [Header("Camera basis in estimated BODY-WORLD frame")]
        [Tooltip("Source camera optical center, expressed in same reference-pose 3D body-world units.")]
        public Vector3 originBodyWorld;
        [Tooltip("Body-world unit vector pointing toward source image +X.")]
        public Vector3 cameraRightBodyWorld;
        [Tooltip("Body-world unit vector pointing upward (-source image Y).")]
        public Vector3 cameraUpBodyWorld;
        [Tooltip("Body-world unit vector pointing into the source camera's positive depth.")]
        public Vector3 cameraForwardBodyWorld;

        [Header("Render frustum and projected depth gates")]
        public float minimumPositiveDepth;
        public float nearClip;
        public float farClip;
        [Tooltip("Maximum model-estimate 3D => 2D p90 inconsistency / source width. This is NOT anatomical ground truth.")]
        [Range(0.005f, 0.1f)] public float maxPoseProjectionP90 = 0.03f;

        public bool TryBuild(out BodyWorldPinholeCamera camera,
                             out PinholeCameraFrustum frustum)
        {
            camera = default(BodyWorldPinholeCamera);
            frustum = default(PinholeCameraFrustum);
            if (!sourceIntrinsicsReviewed || !sourceExtrinsicsReviewed ||
                !BodyWorldPinholeCamera.TryCreate(
                    extrinsicsReviewed: true, mirroredSource: false,
                    width: sourceWidth, height: sourceHeight,
                    cameraOrigin: ToMotion(originBodyWorld),
                    cameraRight: ToMotion(cameraRightBodyWorld),
                    cameraUp: ToMotion(cameraUpBodyWorld),
                    cameraForward: ToMotion(cameraForwardBodyWorld),
                    normalizedFocalX: normalizedFocalX,
                    normalizedFocalY: normalizedFocalY,
                    normalizedCenterX: normalizedCenterX,
                    normalizedCenterY: normalizedCenterY,
                    minimumPositiveDepth: minimumPositiveDepth,
                    result: out camera))
                return false;
            return camera.TryGetSourceFrustum(nearClip, farClip, out frustum);
        }

        private static KinematicVector3 ToMotion(Vector3 point)
        {
            return new KinematicVector3(point.x, point.y, point.z);
        }
    }
}

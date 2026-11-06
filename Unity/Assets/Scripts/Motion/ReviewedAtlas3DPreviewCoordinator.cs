using MagicMirror.Anatomy;
using MagicMirror.Tracking;
using UnityEngine;

namespace MagicMirror.Motion
{
    /// <summary>
    /// Explicit, manual M4/M5 debug integration with ONE sidecar receiver and
    /// ONE original intact FBX Retargeter (no second camera or atlas instance).
    /// `BeginReviewedDiagnosticCapture` must be invoked deliberately in
    /// PLAY MODE after a real atlas's anchors/provenance have been reviewed.
    ///
    /// Captures 12 stable non-demo PoseFrames, freezes one reference transform,
    /// then enables a 3D atlas-root-local preview. NO physical camera
    /// calibration, real-person internal bone reconstruction or live AR
    /// overlay alignment is claimed. Disabled by default.
    /// </summary>
    public sealed class ReviewedAtlas3DPreviewCoordinator : MonoBehaviour
    {
        [SerializeField] private PoseStreamReceiver source;
        [SerializeField] private FullBodyAtlasRetargeter atlasRetargeter;
        [SerializeField] private FullBodyAtlasProfile profile;
        [Tooltip("Explicit operator confirmation. Does not auto-start capture.")]
        [SerializeField] private bool operatorApprovedDiagnosticOnly;

        [Header("OPTIONAL source-camera AR preview (disabled by default)")]
        [Tooltip("False = FBX coordinate diagnostic only. True requires independently reviewed source camera parameters.")]
        [SerializeField] private bool requestReviewedCameraOverlay;
        [Tooltip("No default guessed values: a physically measured source camera asset is required.")]
        [SerializeField] private ReviewedCameraCalibrationProfile cameraCalibrationProfile;
        [Tooltip("Separate manual approval of actual source camera intrinsics and body-world extrinsics.")]
        [SerializeField] private bool operatorApprovedCameraRegistration;

        private const int RequiredSamples = 12;
        private ReferencePoseCaptureWindow capture;
        private bool capturing;

        public bool IsCapturing { get { return capturing; } }
        public int FramesCaptured
        {
            get { return capture == null ? 0 : capture.AcceptedFrames; }
        }

        /// <summary>
        /// Scene-builder/preview host may assign the SAME receiver/profile
        /// used by the 2D Retargeter. Never opens a webcam itself.
        /// </summary>
        public void Configure(
            PoseStreamReceiver stream,
            FullBodyAtlasRetargeter retargeter,
            FullBodyAtlasProfile atlasProfile)
        {
            if (isActiveAndEnabled && source != null)
                source.FrameReceived -= OnPoseFrame;
            source = stream;
            atlasRetargeter = retargeter;
            profile = atlasProfile;
            capturing = false;
            capture = null;
            if (isActiveAndEnabled && source != null)
                source.FrameReceived += OnPoseFrame;
        }

        private void OnEnable()
        {
            if (source != null)
                source.FrameReceived += OnPoseFrame;
        }

        private void OnDisable()
        {
            if (source != null)
                source.FrameReceived -= OnPoseFrame;
            capturing = false;
            capture = null;
            if (atlasRetargeter != null)
                atlasRetargeter.DisableReviewed3DPreview();
        }

        [ContextMenu("Begin reviewed 3D diagnostic capture (Play Mode ONLY)")]
        public void BeginReviewedDiagnosticCapture()
        {
            if (!Application.isPlaying ||
                source == null || atlasRetargeter == null ||
                profile == null || profile.schematicDemo ||
                !operatorApprovedDiagnosticOnly ||
                !atlasRetargeter.UsesPoseStreamAndProfile(source, profile))
            {
                Debug.LogWarning(
                    "MagicMirror M4/M5: refused 3D capture. Explicit review, " +
                    "Play Mode, same pose source and real whole atlas are required.");
                return;
            }

            string issue;
            if (!profile.Validate(out issue) ||
                !profile.ValidateHierarchy(out issue))
            {
                Debug.LogWarning(
                    "MagicMirror M4/M5: real atlas review failed: " + issue);
                return;
            }

            atlasRetargeter.DisableReviewed3DPreview();
            capture = new ReferencePoseCaptureWindow(
                requiredFrames: RequiredSamples,
                minimumConfidence: 0.6f,
                maximumDriftInShoulderWidths: 0.06f,
                maximumFrameGapMs: 250);
            capturing = true;
            Debug.Log("MagicMirror M4/M5: collect 12 steady, real pose frames. " +
                      "Any interrupted or invalid sequence must be started again.");
        }

        [ContextMenu("Stop reviewed 3D diagnostic preview")]
        public void StopReviewedDiagnosticPreview()
        {
            capturing = false;
            capture = null;
            if (atlasRetargeter != null)
                atlasRetargeter.DisableReviewed3DPreview();
        }

        private void OnPoseFrame(PoseFrame frame)
        {
            if (!capturing || capture == null)
                return;
            if (frame == null || frame.streamSessionId <= 0)
            {
                capturing = false;
                Debug.LogWarning("MagicMirror: no trusted TCP session. " +
                    "Refusing reference pose capture.");
                return;
            }
            if (!capture.TryAdd(frame))
            {
                capturing = false;
                Debug.LogWarning(
                    "MagicMirror M4/M5: reference capture interrupted/unstable. " +
                    "Restart explicitly after checking person, model and camera.");
                return;
            }

            if (capture.AcceptedFrames < capture.RequiredFrames)
                return;

            // Initialize even if the review gate fails before TryFreeze:
            // C# short-circuit evaluation must never leave out values stale.
            BodySimilarityCalibration calibration =
                default(BodySimilarityCalibration);
            PoseCaptureQuality quality = default(PoseCaptureQuality);
            bool reviewed = profile != null && !profile.schematicDemo &&
                            profile.referencePoseReviewed &&
                            profile.midHipAnchorReviewed &&
                            profile.assetLicensesReviewed;
            bool success = reviewed && capture.TryFreeze(
                atlasAnchorsReviewed: true,
                atlasLeftShoulder: FromUnity(profile.atlasLeftShoulderLocal),
                atlasRightShoulder: FromUnity(profile.atlasRightShoulderLocal),
                atlasMidHip: FromUnity(profile.atlasMidHipLocal),
                minimumScale: 0.001f,
                maximumScale: 1000f,
                maxPelvisResidualInShoulderWidths: 0.15f,
                calibration: out calibration,
                quality: out quality);

            capturing = false;
            if (!success ||
                !atlasRetargeter.TryEnableReviewed3DPreview(
                    calibration, quality, operatorApprovedDiagnosticOnly))
            {
                Debug.LogWarning(
                    "MagicMirror M4/M5: stable capture failed or " +
                    "full-atlas preview gate rejected. Nothing activated.");
                return;
            }

            if (requestReviewedCameraOverlay)
            {
                BodyWorldPinholeCamera reviewedCamera =
                    default(BodyWorldPinholeCamera);
                PinholeCameraFrustum frustum =
                    default(PinholeCameraFrustum);
                if (!operatorApprovedCameraRegistration ||
                    cameraCalibrationProfile == null ||
                    !cameraCalibrationProfile.TryBuild(
                        out reviewedCamera, out frustum) ||
                    !atlasRetargeter.TryEnableReviewedCameraOverlay(
                        reviewedCamera, frustum,
                        cameraCalibrationProfile.maxPoseProjectionP90,
                        operatorApprovedCameraRegistration))
                {
                    atlasRetargeter.DisableReviewed3DPreview();
                    Debug.LogWarning(
                        "MagicMirror M5: rejected uncalibrated camera overlay. " +
                        "No RGB-aligned anatomical model will be shown.");
                    return;
                }

                Debug.Log("MagicMirror M5: reviewed camera projection " +
                    "preview ARMED; requires per-frame pose reprojection " +
                    "validation. Real anatomy/camera alignment remains unverified.");
                return;
            }

            Debug.Log(
                "MagicMirror M4/M5: 3D atlas diagnostic preview ARMED. " +
                "It is NOT registered to the live camera, and all " +
                "unmapped anatomy stays in the original reference pose.");
        }

        private static KinematicVector3 FromUnity(Vector3 v)
        {
            return new KinematicVector3(v.x, v.y, v.z);
        }
    }
}

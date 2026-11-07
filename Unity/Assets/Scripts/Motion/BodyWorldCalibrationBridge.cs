using MagicMirror.Tracking;

namespace MagicMirror.Motion
{
    /// <summary>
    /// One-shot, explicitly reviewed REFERENCE-POSE capture from MediaPipe
    /// estimated hip-relative world landmarks into atlas ROOT LOCAL units.
    ///
    /// This bridge deliberately does not drive any Unity Transform, turn a
    /// mirrored screen into a mirrored 3D body, or automatically recalibrate
    /// while a person moves. A separate onboarding/UI validation will be
    /// required before activating any real Z-Anatomy motion binding.
    /// </summary>
    public static class BodyWorldCalibrationBridge
    {
        public static bool TryCaptureReferencePose(
            PoseFrame frame,
            bool atlasReferenceAnchorsReviewed,
            KinematicVector3 atlasLeftShoulder,
            KinematicVector3 atlasRightShoulder,
            KinematicVector3 atlasMidHip,
            float minimumVisibility,
            float minUniformScale,
            float maxUniformScale,
            float maxPelvisResidualInShoulderWidths,
            out BodySimilarityCalibration calibration)
        {
            calibration = default(BodySimilarityCalibration);
            if (frame == null || !frame.IsValid ||
                !atlasReferenceAnchorsReviewed ||
                frame.demo || frame.mirrored ||
                frame.worldLandmarks == null ||
                frame.worldLandmarks.Length != 33 ||
                float.IsNaN(minimumVisibility) ||
                float.IsInfinity(minimumVisibility) ||
                minimumVisibility < 0f ||
                minimumVisibility > 1f)
                return false;

            // The source JPEG remains unmirrored; a later Unity display
            // mirror is a separate 2D compositor operation. If the camera
            // pipeline changes its 3D coordinate convention, recertify
            // calibration instead of silently flipping the skeleton.
            KinematicVector3 poseL, poseR, hipL, hipR;
            if (!TryPoint(frame, 11, minimumVisibility, out poseL) ||
                !TryPoint(frame, 12, minimumVisibility, out poseR) ||
                !TryPoint(frame, 23, minimumVisibility, out hipL) ||
                !TryPoint(frame, 24, minimumVisibility, out hipR))
                return false;

            KinematicVector3 poseMidHip = (hipL + hipR) * 0.5f;
            if (!KinematicVector3.IsFinite(poseMidHip))
                return false;
            return BodySimilarityCalibration.TryCreate(
                poseL, poseR, poseMidHip,
                atlasLeftShoulder, atlasRightShoulder, atlasMidHip,
                minUniformScale, maxUniformScale,
                maxPelvisResidualInShoulderWidths,
                out calibration);
        }

        private static bool TryPoint(
            PoseFrame frame, int index, float threshold,
            out KinematicVector3 result)
        {
            result = KinematicVector3.Zero;
            PoseLandmark visible;
            if (!frame.TryGetVisible(index, threshold, out visible))
                return false;

            PoseLandmark world = frame.worldLandmarks[index];
            if (world == null)
                return false;
            result = new KinematicVector3(world.x, world.y, world.z);
            return KinematicVector3.IsFinite(result);
        }
    }
}

using System;
using MagicMirror.Tracking;

namespace MagicMirror.Motion
{
    /// <summary>
    /// Map the four two-link chains to MediaPipe Pose Landmarker IDs.
    /// These input points are MODEL-ESTIMATED hip-relative 3D landmarks;
    /// they are neither true bone joints nor Unity camera coordinates.
    /// </summary>
    public enum TrackedTwoLinkLimb
    {
        LeftArm, RightArm, LeftLeg, RightLeg
    }

    /// <summary>
    /// Conservative bridge between ONE valid PoseFrame's 3D landmarks
    /// and the separately tested pure C# constrained IK kernel.
    /// NO real FBX transforms are driven until source coordinate axes,
    /// actual rest lengths, calibration, anchors and hinge planes are reviewed.
    /// </summary>
    public static class TwoBoneWorldPoseBridge
    {
        public static bool TrySolveEstimatedWorld(
            PoseFrame frame,
            TrackedTwoLinkLimb limb,
            float confidenceThreshold,
            float firstAtlasLength,
            float secondAtlasLength,
            float minFlexionDegrees,
            float maxFlexionDegrees,
            out TwoBoneSolution result)
        {
            result = default(TwoBoneSolution);
            if (frame == null || !frame.IsValid ||
                frame.worldLandmarks == null || frame.worldLandmarks.Length != 33 ||
                float.IsNaN(confidenceThreshold) ||
                float.IsInfinity(confidenceThreshold) ||
                confidenceThreshold < 0f || confidenceThreshold > 1f)
                return false;

            int proximalIndex, poleIndex, distalIndex;
            switch (limb)
            {
                case TrackedTwoLinkLimb.LeftArm:
                    proximalIndex = 11; poleIndex = 13; distalIndex = 15;
                    break;
                case TrackedTwoLinkLimb.RightArm:
                    proximalIndex = 12; poleIndex = 14; distalIndex = 16;
                    break;
                case TrackedTwoLinkLimb.LeftLeg:
                    proximalIndex = 23; poleIndex = 25; distalIndex = 27;
                    break;
                case TrackedTwoLinkLimb.RightLeg:
                    proximalIndex = 24; poleIndex = 26; distalIndex = 28;
                    break;
                default:
                    return false;
            }

            KinematicVector3 shoulderOrHip, estimatedElbowOrKnee, wristOrAnkle;
            if (!TryWorld(frame, proximalIndex, confidenceThreshold, out shoulderOrHip) ||
                !TryWorld(frame, poleIndex, confidenceThreshold, out estimatedElbowOrKnee) ||
                !TryWorld(frame, distalIndex, confidenceThreshold, out wristOrAnkle))
                return false;

            // The model's middle joint provides only a bend-plane HINT.
            // The hinge solver uses source-atlas reference segment lengths,
            // refusing invalid or collinear observations rather than inventing
            // joint centers. Output coordinates are STILL MediaPipe world space.
            return TwoBoneKinematics.TrySolve(
                shoulderOrHip, wristOrAnkle, estimatedElbowOrKnee,
                firstAtlasLength, secondAtlasLength,
                minFlexionDegrees, maxFlexionDegrees, out result);
        }

        private static bool TryWorld(
            PoseFrame frame, int index, float minConfidence,
            out KinematicVector3 result)
        {
            result = KinematicVector3.Zero;
            PoseLandmark visible;
            if (!frame.TryGetVisible(index, minConfidence, out visible))
                return false;

            PoseLandmark point = frame.worldLandmarks[index];
            if (point == null)
                return false;
            KinematicVector3 coordinate = new KinematicVector3(
                point.x, point.y, point.z);
            if (!KinematicVector3.IsFinite(coordinate))
                return false;
            result = coordinate;
            return true;
        }
    }
}

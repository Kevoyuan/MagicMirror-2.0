using System;
using MagicMirror.Tracking;

namespace MagicMirror.Motion
{
    /// <summary>
    /// Manually reviewed, original FBX ROOT-LOCAL hinge anchors for ONE
    /// two-link limb. Both renderer regions must be separately reviewed and
    /// must share this exact anatomical joint center.
    /// </summary>
    public struct ReviewedAtlasTwoLinkChain
    {
        public KinematicVector3 proximalAtlasLocal;
        public KinematicVector3 hingeAtlasLocal;
        public KinematicVector3 distalAtlasLocal;
        public bool upperRegionReviewed;
        public bool lowerRegionReviewed;
    }

    /// <summary>
    /// One rigid anatomical motion region, derived from source/rest anchors.
    /// A Unity adapter may rotate the original atlas renderer around
    /// restStartAtlasLocal into targetStartAtlasLocal; its mesh is not modified.
    /// </summary>
    public struct AtlasRigidRegionCommand
    {
        public KinematicVector3 restStartAtlasLocal;
        public KinematicVector3 restEndAtlasLocal;
        public KinematicVector3 targetStartAtlasLocal;
        public KinematicVector3 targetEndAtlasLocal;
    }

    public struct AtlasTwoLinkMotionCommand
    {
        public AtlasRigidRegionCommand upper;
        public AtlasRigidRegionCommand lower;
        public long sourceFrameId;
        public long sourceTimestampMs;
        public int streamSessionId;
        public TrackedTwoLinkLimb limb;
        public float flexionDegrees;
        public bool unreachableTargetClamped;
        public bool isValid;
    }

    /// <summary>
    /// Frame-specific, opt-in, FAIL-CLOSED M4 IK + M5 calibrated
    /// bone motion command planner. It does not drive a camera, a mesh,
    /// the actual Z-Anatomy FBX or Unity transforms on its own.
    ///
    /// Requires human-reviewed original FBX rest joint centers and a frozen
    /// body-world => atlas root local calibration. Rest lengths are converted
    /// from atlas local units into the MODEL-ESTIMATED body-world scale before
    /// solving. All output commands stay in atlas ROOT LOCAL coordinates.
    /// </summary>
    public static class AtlasTwoLinkMotionPlanner
    {
        private const float MinLength = 1e-5f;

        public static bool TryPlan(
            PoseFrame frame,
            TrackedTwoLinkLimb limb,
            BodySimilarityCalibration frozenCalibration,
            ReviewedAtlasTwoLinkChain rest,
            float minimumConfidence,
            float minimumFlexionDegrees,
            float maximumFlexionDegrees,
            out AtlasTwoLinkMotionCommand command)
        {
            command = default(AtlasTwoLinkMotionCommand);
            if (frame == null || !frame.IsValid || frame.demo || frame.mirrored ||
                !frozenCalibration.IsValid || !frozenCalibration.PreservesHandedness ||
                !rest.upperRegionReviewed || !rest.lowerRegionReviewed ||
                !KinematicVector3.IsFinite(rest.proximalAtlasLocal) ||
                !KinematicVector3.IsFinite(rest.hingeAtlasLocal) ||
                !KinematicVector3.IsFinite(rest.distalAtlasLocal) ||
                float.IsNaN(minimumConfidence) ||
                float.IsInfinity(minimumConfidence) ||
                minimumConfidence < 0f || minimumConfidence > 1f)
                return false;

            float upperAtlasLength = (rest.hingeAtlasLocal -
                                      rest.proximalAtlasLocal).Magnitude;
            float lowerAtlasLength = (rest.distalAtlasLocal -
                                      rest.hingeAtlasLocal).Magnitude;
            float scale = frozenCalibration.Scale;
            if (!FinitePositive(upperAtlasLength) ||
                !FinitePositive(lowerAtlasLength) ||
                !FinitePositive(scale))
                return false;

            float upperPoseLength = upperAtlasLength / scale;
            float lowerPoseLength = lowerAtlasLength / scale;
            if (!FinitePositive(upperPoseLength) ||
                !FinitePositive(lowerPoseLength))
                return false;

            TwoBoneSolution solution;
            if (!TwoBoneWorldPoseBridge.TrySolveEstimatedWorld(
                    frame, limb, minimumConfidence,
                    upperPoseLength, lowerPoseLength,
                    minimumFlexionDegrees, maximumFlexionDegrees,
                    out solution))
                return false;

            KinematicVector3 targetStart, targetHinge, targetEnd;
            if (!frozenCalibration.TryPoseToAtlas(solution.proximal,
                                                  out targetStart) ||
                !frozenCalibration.TryPoseToAtlas(solution.elbowOrKnee,
                                                  out targetHinge) ||
                !frozenCalibration.TryPoseToAtlas(solution.distal,
                                                  out targetEnd))
                return false;

            // Numerical geometry guard, not anatomical truth. Segment lengths
            // must match the independently reviewed full-FBX reference.
            float upperActual = (targetHinge - targetStart).Magnitude;
            float lowerActual = (targetEnd - targetHinge).Magnitude;
            if (!NearReferenceLength(upperActual, upperAtlasLength) ||
                !NearReferenceLength(lowerActual, lowerAtlasLength))
                return false;

            command = new AtlasTwoLinkMotionCommand
            {
                upper = new AtlasRigidRegionCommand
                {
                    restStartAtlasLocal = rest.proximalAtlasLocal,
                    restEndAtlasLocal = rest.hingeAtlasLocal,
                    targetStartAtlasLocal = targetStart,
                    targetEndAtlasLocal = targetHinge
                },
                lower = new AtlasRigidRegionCommand
                {
                    restStartAtlasLocal = rest.hingeAtlasLocal,
                    restEndAtlasLocal = rest.distalAtlasLocal,
                    targetStartAtlasLocal = targetHinge,
                    targetEndAtlasLocal = targetEnd
                },
                sourceFrameId = frame.frameId,
                sourceTimestampMs = frame.timestampMs,
                streamSessionId = frame.streamSessionId,
                limb = limb,
                flexionDegrees = solution.flexionDegrees,
                unreachableTargetClamped = solution.targetDistanceClamped,
                isValid = true
            };
            return true;
        }

        private static bool NearReferenceLength(float actual, float expected)
        {
            return FinitePositive(actual) &&
                   Math.Abs(actual - expected) <= expected * 0.005f + 1e-5f;
        }

        private static bool FinitePositive(float value)
        {
            return !float.IsNaN(value) && !float.IsInfinity(value) &&
                   value > MinLength;
        }
    }
}

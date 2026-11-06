// Evaluate geometrical agreement of predicted anatomy-overlay anchor positions
// and MediaPipe's SAME-FRAME normalized 2D landmarks. This is a model-to-model
// diagnostics score, NOT anatomical ground truth or clinical correctness.
// No Unity dependencies. CI compiles the exact production source.
using System;
using System.Collections.Generic;

namespace MagicMirror.Motion
{
    /// <summary>
    /// One reviewed, predicted atlas-local joint position. Callers must
    /// supply a prediction for EXACTLY the incoming source frame, after IK.
    /// Untouched reference-pose anchors are NOT valid motion-frame predictions.
    /// </summary>
    public struct AtlasReprojectionAnchor
    {
        public int landmarkIndex;
        public KinematicVector3 predictedAtlasLocal;
        public bool anatomicallyReviewed;
        public long sourceFrameId;
        public long sourceTimestampMs;
    }

    public struct AtlasReprojectionReport
    {
        public int InputAnchors { get; internal set; }
        public int VisibleAnchors { get; internal set; }
        public int SkippedLowConfidence { get; internal set; }
        public float MeanErrorAsImageWidth { get; internal set; }
        public float P90ErrorAsImageWidth { get; internal set; }
        public float TargetP90AsImageWidth { get; internal set; }
        public bool MeetsNumericP90Target { get; internal set; }
        public long SourceFrameId { get; internal set; }
        public long SourceTimestampMs { get; internal set; }

        // ALWAYS false. Actual validity requires independently labelled
        // real camera / anatomical data, model and camera calibration.
        public bool GroundTruthValidated { get { return false; } }
    }

    public static class AtlasReprojectionDiagnostics
    {
        /// <summary>
        /// Predict atlas joint->pose world->camera source pixels and compare
        /// against 2D PoseFrame landmarks from the same original JPEG frame.
        /// P90 error uses image WIDTH as the normalization unit even for Y.
        ///
        /// All anchors must be anatomically reviewed, same-frame predictions,
        /// with unique landmark IDs. Insufficient observed points or an invalid
        /// projection fails CLOSED, rather than silently omitting hard cases.
        /// </summary>
        public static bool TryEvaluate(
            MagicMirror.Tracking.PoseFrame frame,
            BodySimilarityCalibration registration,
            BodyWorldPinholeCamera camera,
            IList<AtlasReprojectionAnchor> predictedAnchors,
            float minimumConfidence,
            int minimumVisibleAnchors,
            float targetP90NormalizedByWidth,
            out AtlasReprojectionReport report)
        {
            report = default(AtlasReprojectionReport);
            if (frame == null || !frame.IsValid || frame.demo || frame.mirrored ||
                !registration.IsValid || !camera.IsConfigured ||
                frame.width != camera.ImageWidth ||
                frame.height != camera.ImageHeight ||
                predictedAnchors == null || predictedAnchors.Count < 1 ||
                predictedAnchors.Count > 33 ||
                minimumVisibleAnchors < 1 ||
                minimumVisibleAnchors > predictedAnchors.Count ||
                !Finite(minimumConfidence) ||
                minimumConfidence < 0f || minimumConfidence > 1f ||
                !Finite(targetP90NormalizedByWidth) ||
                targetP90NormalizedByWidth <= 0f ||
                targetP90NormalizedByWidth > 1f)
                return false;

            var seenIndices = new HashSet<int>();
            var residuals = new List<float>(predictedAnchors.Count);
            int dropped = 0;
            foreach (AtlasReprojectionAnchor item in predictedAnchors)
            {
                if (item.landmarkIndex < 0 || item.landmarkIndex >= 33 ||
                    !item.anatomicallyReviewed ||
                    !KinematicVector3.IsFinite(item.predictedAtlasLocal) ||
                    !seenIndices.Add(item.landmarkIndex) ||
                    item.sourceFrameId != frame.frameId ||
                    item.sourceTimestampMs != frame.timestampMs)
                    return false;

                MagicMirror.Tracking.PoseLandmark observed;
                if (!frame.TryGetVisible(item.landmarkIndex,
                                         minimumConfidence, out observed))
                {
                    dropped++;
                    continue;
                }
                if (!Finite(observed.x) || !Finite(observed.y) ||
                    observed.x < -0.15f || observed.x > 1.15f ||
                    observed.y < -0.15f || observed.y > 1.15f)
                    return false;

                KinematicVector3 projectedPoseWorld;
                if (!registration.TryAtlasToPose(
                        item.predictedAtlasLocal, out projectedPoseWorld))
                    return false;

                float sourceX, sourceY;
                if (!camera.TryProjectSource(
                        projectedPoseWorld, out sourceX, out sourceY))
                    return false;

                // Pixel-space Euclidean error divided by SOURCE IMAGE WIDTH.
                // Unlike normalized UV-space distance, Y is not distorted
                // on a non-square input (e.g. 1280x720).
                double errorPixelsX =
                    ((double)sourceX - observed.x) * frame.width;
                double errorPixelsY =
                    ((double)sourceY - observed.y) * frame.height;
                double errorByWidth = Math.Sqrt(
                    errorPixelsX * errorPixelsX +
                    errorPixelsY * errorPixelsY) / frame.width;
                if (double.IsNaN(errorByWidth) ||
                    double.IsInfinity(errorByWidth) ||
                    errorByWidth > float.MaxValue)
                    return false;
                residuals.Add((float)errorByWidth);
            }

            if (residuals.Count < minimumVisibleAnchors)
                return false;

            float total = 0f;
            foreach (float value in residuals)
                total += value;
            if (!Finite(total))
                return false;
            residuals.Sort();
            // Deterministic nearest-rank P90: ceil(0.90 * N) - 1.
            int percentileIndex = Math.Max(0,
                (int)Math.Ceiling(0.9 * residuals.Count) - 1);
            float p90 = residuals[percentileIndex];
            report = new AtlasReprojectionReport
            {
                InputAnchors = predictedAnchors.Count,
                VisibleAnchors = residuals.Count,
                SkippedLowConfidence = dropped,
                MeanErrorAsImageWidth = total / residuals.Count,
                P90ErrorAsImageWidth = p90,
                TargetP90AsImageWidth = targetP90NormalizedByWidth,
                MeetsNumericP90Target = p90 <= targetP90NormalizedByWidth,
                SourceFrameId = frame.frameId,
                SourceTimestampMs = frame.timestampMs
            };
            return true;
        }

        private static bool Finite(float value)
        {
            return !float.IsNaN(value) && !float.IsInfinity(value);
        }
    }
}

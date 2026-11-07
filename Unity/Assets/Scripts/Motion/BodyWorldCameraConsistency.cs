// Same-source-frame sanity check of reviewed camera extrinsics.
// This tests whether MediaPipe *itself* places major estimated joints
// consistently in 2D/3D under the proposed camera model. It does NOT
// establish anatomical bone accuracy, real depth, or ground truth.
using System;
using MagicMirror.Tracking;

namespace MagicMirror.Motion
{
    public struct CameraPoseConsistencyReport
    {
        public long SourceFrameId { get; internal set; }
        public int StreamSessionId { get; internal set; }
        public float P90NormalizedBySourceWidth { get; internal set; }
        public bool IndependentlyValidated { get { return false; } }
    }

    public static class BodyWorldCameraConsistency
    {
        private static readonly int[] AnchorIds = { 11, 12, 23, 24 };

        public static bool TryValidate(
            PoseFrame frame, BodyWorldPinholeCamera camera,
            float minimumConfidence, float maximumP90NormalizedByWidth,
            out CameraPoseConsistencyReport report)
        {
            report = default(CameraPoseConsistencyReport);
            if (frame == null || !frame.IsValid ||
                frame.demo || frame.mirrored || !camera.IsConfigured ||
                frame.width != camera.ImageWidth ||
                frame.height != camera.ImageHeight ||
                frame.worldLandmarks == null ||
                frame.worldLandmarks.Length != 33 ||
                !Finite(minimumConfidence) || minimumConfidence < 0f ||
                minimumConfidence > 1f ||
                !Finite(maximumP90NormalizedByWidth) ||
                maximumP90NormalizedByWidth <= 0f ||
                maximumP90NormalizedByWidth > 1f)
                return false;

            float[] errors = new float[AnchorIds.Length];
            for (int i = 0; i < AnchorIds.Length; i++)
            {
                int id = AnchorIds[i];
                PoseLandmark observed;
                if (!frame.TryGetVisible(id, minimumConfidence, out observed) ||
                    !Finite(observed.x) || !Finite(observed.y) ||
                    observed.x < -0.15f || observed.x > 1.15f ||
                    observed.y < -0.15f || observed.y > 1.15f)
                    return false;
                PoseLandmark world = frame.worldLandmarks[id];
                if (world == null)
                    return false;
                float projectedX, projectedY;
                if (!camera.TryProjectSource(
                    new KinematicVector3(world.x, world.y, world.z),
                    out projectedX, out projectedY))
                    return false;
                double dx = ((double)projectedX - observed.x) * frame.width;
                double dy = ((double)projectedY - observed.y) * frame.height;
                double normalized = Math.Sqrt(dx * dx + dy * dy) / frame.width;
                if (double.IsNaN(normalized) || double.IsInfinity(normalized) ||
                    normalized > float.MaxValue)
                    return false;
                errors[i] = (float)normalized;
            }
            Array.Sort(errors);
            // N=4: nearest-rank 90th percentile is the maximum sample.
            float p90 = errors[3];
            if (p90 > maximumP90NormalizedByWidth)
                return false;

            report = new CameraPoseConsistencyReport
            {
                SourceFrameId = frame.frameId,
                StreamSessionId = frame.streamSessionId,
                P90NormalizedBySourceWidth = p90
            };
            return true;
        }

        private static bool Finite(float value)
        {
            return !float.IsNaN(value) && !float.IsInfinity(value);
        }
    }
}

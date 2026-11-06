// Explicit, bounded, single-session reference-pose capture and robust median.
// Pure C#; compiled as original Unity source in .NET CI. Not a camera tracker.
// No source images, JPEG bytes or pose history are persisted to disk.
using System;
using System.Collections.Generic;
using MagicMirror.Tracking;

namespace MagicMirror.Motion
{
    public struct PoseCaptureQuality
    {
        public int AcceptedFrames { get; internal set; }
        public long FirstFrameId { get; internal set; }
        public long LastFrameId { get; internal set; }
        public long FirstTimestampMs { get; internal set; }
        public long LastTimestampMs { get; internal set; }
        public float MaximumJointDriftInShoulderWidths { get; internal set; }
        public bool IsSyntheticOrHardwareValidated { get { return false; } }
    }

    /// <summary>
    /// Hold a reference pose for N ordered, same-resolution PoseFrames before
    /// computing a single frozen body-to-atlas similarity calibration. A
    /// bad frame/dropout/reconnect poisons the capture until Reset() is called.
    ///
    /// Stability is measured in estimated MediaPipe BODY-WORLD space; the
    /// outcome is not automatically a valid camera-to-screen calibration.
    /// </summary>
    public sealed class ReferencePoseCaptureWindow
    {
        private struct Sample
        {
            public KinematicVector3 left;
            public KinematicVector3 right;
            public KinematicVector3 hipL;
            public KinematicVector3 hipR;
        }

        private readonly List<Sample> samples;
        private readonly int required;
        private readonly float confidence;
        private readonly float maxDriftWidths;
        private readonly long maxGapMs;
        private int imageWidth, imageHeight;
        private long lastFrameId, lastTimestampMs;
        private long firstFrameId, firstTimestampMs;
        private bool hasFrame, poisoned, frozen;

        public int AcceptedFrames { get { return samples.Count; } }
        public int RequiredFrames { get { return required; } }
        public bool RequiresReset { get { return poisoned; } }
        public bool IsFrozen { get { return frozen; } }

        public ReferencePoseCaptureWindow(
            int requiredFrames = 12, float minimumConfidence = 0.6f,
            float maximumDriftInShoulderWidths = 0.06f,
            long maximumFrameGapMs = 250)
        {
            if (requiredFrames < 3 || requiredFrames > 120 ||
                !Finite(minimumConfidence) ||
                minimumConfidence < 0f || minimumConfidence > 1f ||
                !Finite(maximumDriftInShoulderWidths) ||
                maximumDriftInShoulderWidths <= 0f ||
                maximumDriftInShoulderWidths > 0.5f ||
                maximumFrameGapMs <= 0 || maximumFrameGapMs > 3000)
                throw new ArgumentOutOfRangeException("Invalid reference capture settings.");
            required = requiredFrames;
            confidence = minimumConfidence;
            maxDriftWidths = maximumDriftInShoulderWidths;
            maxGapMs = maximumFrameGapMs;
            samples = new List<Sample>(requiredFrames);
            Reset();
        }

        public void Reset()
        {
            samples.Clear();
            imageWidth = imageHeight = 0;
            lastFrameId = lastTimestampMs = 0;
            firstFrameId = firstTimestampMs = 0;
            hasFrame = poisoned = frozen = false;
        }

        /// <summary>
        /// Returns false on invalid input, dropouts, nonmonotonic packets,
        /// resolution changes, gaps and overflow. Such failures explicitly
        /// require Reset() to avoid mixing independent camera sessions.
        /// </summary>
        public bool TryAdd(PoseFrame frame)
        {
            if (poisoned || frozen || samples.Count >= required)
                return false;
            if (frame == null || !frame.IsValid || frame.demo ||
                frame.mirrored || frame.worldLandmarks == null ||
                frame.worldLandmarks.Length != 33 ||
                (hasFrame && (frame.frameId <= lastFrameId ||
                              frame.timestampMs <= lastTimestampMs ||
                              frame.timestampMs - lastTimestampMs > maxGapMs ||
                              frame.width != imageWidth ||
                              frame.height != imageHeight)))
                return Poison();

            KinematicVector3 left, right, hipL, hipR;
            if (!TryWorld(frame, 11, out left) ||
                !TryWorld(frame, 12, out right) ||
                !TryWorld(frame, 23, out hipL) ||
                !TryWorld(frame, 24, out hipR))
                return Poison();

            if (!hasFrame)
            {
                imageWidth = frame.width;
                imageHeight = frame.height;
                firstFrameId = frame.frameId;
                firstTimestampMs = frame.timestampMs;
            }
            lastFrameId = frame.frameId;
            lastTimestampMs = frame.timestampMs;
            hasFrame = true;
            samples.Add(new Sample { left = left, right = right,
                                     hipL = hipL, hipR = hipR });
            return true;
        }

        /// <summary>
        /// Compute component-wise median of each of four observed world
        /// joints. Every accepted frame must be within the drift budget
        /// relative to the median shoulder width; median alone must NEVER
        /// be used to hide one large movement or an occlusion.
        /// </summary>
        public bool TryFreeze(
            bool atlasAnchorsReviewed,
            KinematicVector3 atlasLeftShoulder,
            KinematicVector3 atlasRightShoulder,
            KinematicVector3 atlasMidHip,
            float minimumScale, float maximumScale,
            float maxPelvisResidualInShoulderWidths,
            out BodySimilarityCalibration calibration,
            out PoseCaptureQuality quality)
        {
            calibration = default(BodySimilarityCalibration);
            quality = default(PoseCaptureQuality);
            if (poisoned || frozen || samples.Count != required ||
                !atlasAnchorsReviewed)
                return false;

            KinematicVector3 left = Median(0), right = Median(1);
            KinematicVector3 hipL = Median(2), hipR = Median(3);
            float shoulderWidth = (right - left).Magnitude;
            if (!Finite(shoulderWidth) || shoulderWidth < 1e-6f)
                return Poison();

            float maxObservedDrift = 0f;
            for (int i = 0; i < samples.Count; i++)
            {
                Sample s = samples[i];
                maxObservedDrift = Math.Max(maxObservedDrift, (s.left - left).Magnitude);
                maxObservedDrift = Math.Max(maxObservedDrift, (s.right - right).Magnitude);
                maxObservedDrift = Math.Max(maxObservedDrift, (s.hipL - hipL).Magnitude);
                maxObservedDrift = Math.Max(maxObservedDrift, (s.hipR - hipR).Magnitude);
            }
            float driftNormalized = maxObservedDrift / shoulderWidth;
            if (!Finite(driftNormalized) || driftNormalized > maxDriftWidths)
                return Poison();

            if (!BodySimilarityCalibration.TryCreate(
                    left, right, (hipL + hipR) * 0.5f,
                    atlasLeftShoulder, atlasRightShoulder, atlasMidHip,
                    minimumScale, maximumScale,
                    maxPelvisResidualInShoulderWidths, out calibration))
                return Poison();

            quality = new PoseCaptureQuality
            {
                AcceptedFrames = samples.Count,
                FirstFrameId = firstFrameId,
                LastFrameId = lastFrameId,
                FirstTimestampMs = firstTimestampMs,
                LastTimestampMs = lastTimestampMs,
                MaximumJointDriftInShoulderWidths = driftNormalized
            };
            frozen = true;
            return true;
        }

        private bool TryWorld(PoseFrame frame, int id, out KinematicVector3 result)
        {
            result = KinematicVector3.Zero;
            PoseLandmark visible;
            if (!frame.TryGetVisible(id, confidence, out visible))
                return false;
            PoseLandmark world = frame.worldLandmarks[id];
            if (world == null)
                return false;
            result = new KinematicVector3(world.x, world.y, world.z);
            return KinematicVector3.IsFinite(result);
        }

        private KinematicVector3 Median(int joint)
        {
            float[] x = new float[samples.Count];
            float[] y = new float[samples.Count];
            float[] z = new float[samples.Count];
            for (int i = 0; i < samples.Count; i++)
            {
                Sample s = samples[i];
                KinematicVector3 p = joint == 0 ? s.left :
                                     joint == 1 ? s.right :
                                     joint == 2 ? s.hipL : s.hipR;
                x[i] = p.x;
                y[i] = p.y;
                z[i] = p.z;
            }
            Array.Sort(x); Array.Sort(y); Array.Sort(z);
            return new KinematicVector3(
                MedianSorted(x), MedianSorted(y), MedianSorted(z));
        }

        private static float MedianSorted(float[] values)
        {
            int center = values.Length / 2;
            if (values.Length % 2 == 1) return values[center];
            return 0.5f * (values[center - 1] + values[center]);
        }

        private bool Poison()
        {
            poisoned = true;
            return false;
        }

        private static bool Finite(float f)
        {
            return !float.IsNaN(f) && !float.IsInfinity(f);
        }
    }
}

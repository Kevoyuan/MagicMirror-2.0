// A deliberately conservative rigid similarity calibration between a
// MediaPipe-estimated BODY world frame and the complete reference anatomy
// FBX ROOT LOCAL frame. Engine-independent: compiled by Unity and .NET CI.
//
// This does not measure actual individual bone centers, recover camera
// extrinsics, or turn an anatomical atlas into a medically accurate scan.
using System;

namespace MagicMirror.Motion
{
    /// <summary>
    /// Reference-pose 3D rotation + uniform scale + translation only.
    ///
    /// Correspondences:
    ///   estimated person left/right shoulder + midpoint of hips
    ///   -> reviewed atlas left/right shoulder + reviewed atlas mid-hip
    ///
    /// Source and destination frames are each built using a right-handed
    /// triad. No implicit screen mirroring or axis reflection is performed.
    /// The calibration is intended to be captured during explicit onboarding
    /// and then frozen, NOT recomputed independently every animation frame.
    ///
    /// The hip anchor controls the orientation of the shoulder/body plane;
    /// a separate pelvis residual checks compatibility with the uniform
    /// shoulder-derived scale. All coordinates must be finite.
    /// </summary>
    public struct BodySimilarityCalibration
    {
        private const float Epsilon = 1e-6f;
        private KinematicVector3 poseOrigin;
        private KinematicVector3 atlasOrigin;
        private KinematicVector3 poseX;
        private KinematicVector3 poseY;
        private KinematicVector3 poseZ;
        private KinematicVector3 atlasX;
        private KinematicVector3 atlasY;
        private KinematicVector3 atlasZ;

        public float Scale { get; private set; }
        public float PelvisResidualInShoulderWidths { get; private set; }
        public bool IsValid { get; private set; }
        public bool PreservesHandedness { get { return IsValid; } }

        public static bool TryCreate(
            KinematicVector3 poseLeftShoulder,
            KinematicVector3 poseRightShoulder,
            KinematicVector3 poseMidHip,
            KinematicVector3 atlasLeftShoulder,
            KinematicVector3 atlasRightShoulder,
            KinematicVector3 atlasMidHip,
            float minScale, float maxScale,
            float maxPelvisResidualInShoulderWidths,
            out BodySimilarityCalibration result)
        {
            result = default(BodySimilarityCalibration);
            if (!Finite(minScale) || !Finite(maxScale) ||
                minScale <= Epsilon || maxScale < minScale ||
                !Finite(maxPelvisResidualInShoulderWidths) ||
                maxPelvisResidualInShoulderWidths < 0f ||
                maxPelvisResidualInShoulderWidths > 3f)
                return false;

            KinematicVector3 fromX, fromY, fromZ, fromMid;
            KinematicVector3 toX, toY, toZ, toMid;
            float fromShoulderWidth, toShoulderWidth;
            if (!TryBodyFrame(
                    poseLeftShoulder, poseRightShoulder, poseMidHip,
                    out fromMid, out fromX, out fromY, out fromZ,
                    out fromShoulderWidth) ||
                !TryBodyFrame(
                    atlasLeftShoulder, atlasRightShoulder, atlasMidHip,
                    out toMid, out toX, out toY, out toZ,
                    out toShoulderWidth))
                return false;

            float scale = toShoulderWidth / fromShoulderWidth;
            if (!Finite(scale) || scale < minScale || scale > maxScale)
                return false;

            // The shoulders are fitted exactly by the reference similarity.
            // Pelvis error detects disproportionate/noisy observations and
            // excludes disproportionate/noisy reference postures. Three
            // coplanar anchors CANNOT prove correct camera-facing orientation
            // or detect every mirrored anatomical correspondence.
            KinematicVector3 poseTorso = poseMidHip - fromMid;
            KinematicVector3 atlasTorso = atlasMidHip - toMid;
            KinematicVector3 predictedTorso =
                RotateBetweenFrames(poseTorso, fromX, fromY, fromZ,
                                    toX, toY, toZ) * scale;
            float normalizedPelvisResidual =
                (predictedTorso - atlasTorso).Magnitude / toShoulderWidth;
            if (!Finite(normalizedPelvisResidual) ||
                normalizedPelvisResidual > maxPelvisResidualInShoulderWidths)
                return false;

            result.poseOrigin = fromMid;
            result.atlasOrigin = toMid;
            result.poseX = fromX;
            result.poseY = fromY;
            result.poseZ = fromZ;
            result.atlasX = toX;
            result.atlasY = toY;
            result.atlasZ = toZ;
            result.Scale = scale;
            result.PelvisResidualInShoulderWidths = normalizedPelvisResidual;
            result.IsValid = true;
            return true;
        }

        /// <summary>Estimated pose-world position to original atlas ROOT LOCAL.</summary>
        public bool TryPoseToAtlas(KinematicVector3 source,
                                   out KinematicVector3 output)
        {
            output = KinematicVector3.Zero;
            if (!IsValid || !KinematicVector3.IsFinite(source))
                return false;
            KinematicVector3 relative = source - poseOrigin;
            output = atlasOrigin + RotateBetweenFrames(
                relative, poseX, poseY, poseZ,
                atlasX, atlasY, atlasZ) * Scale;
            return KinematicVector3.IsFinite(output);
        }

        /// <summary>Reference atlas ROOT LOCAL back to estimated pose-world.</summary>
        public bool TryAtlasToPose(KinematicVector3 source,
                                   out KinematicVector3 output)
        {
            output = KinematicVector3.Zero;
            if (!IsValid || !KinematicVector3.IsFinite(source))
                return false;
            KinematicVector3 relative = source - atlasOrigin;
            output = poseOrigin + RotateBetweenFrames(
                relative, atlasX, atlasY, atlasZ,
                poseX, poseY, poseZ) * (1f / Scale);
            return KinematicVector3.IsFinite(output);
        }

        /// <summary>
        /// Rotate + uniformly scale a BODY-WORLD direction into atlas space,
        /// without translating it. Use with pose derivatives, not angles.
        /// </summary>
        public bool TryPoseDirectionToAtlas(KinematicVector3 direction,
                                             out KinematicVector3 output)
        {
            output = KinematicVector3.Zero;
            if (!IsValid || !KinematicVector3.IsFinite(direction))
                return false;
            output = RotateBetweenFrames(
                direction, poseX, poseY, poseZ, atlasX, atlasY, atlasZ) * Scale;
            return KinematicVector3.IsFinite(output);
        }

        private static bool TryBodyFrame(
            KinematicVector3 left, KinematicVector3 right,
            KinematicVector3 midHip,
            out KinematicVector3 shoulderMid,
            out KinematicVector3 x, out KinematicVector3 y,
            out KinematicVector3 z, out float width)
        {
            shoulderMid = x = y = z = KinematicVector3.Zero;
            width = 0f;
            if (!KinematicVector3.IsFinite(left) ||
                !KinematicVector3.IsFinite(right) ||
                !KinematicVector3.IsFinite(midHip))
                return false;

            KinematicVector3 shoulders = right - left;
            width = shoulders.Magnitude;
            if (!Finite(width) || width < Epsilon)
                return false;
            x = shoulders * (1f / width);
            shoulderMid = (left + right) * 0.5f;
            KinematicVector3 body = midHip - shoulderMid;
            KinematicVector3 perpendicular = body -
                x * KinematicVector3.Dot(body, x);
            float bodyHeight = perpendicular.Magnitude;
            // An almost-collinear hip anchor cannot establish body up/down
            // or the depth axis. Require enough lever arm relative to shoulders.
            if (!Finite(bodyHeight) || bodyHeight < width * 0.1f ||
                bodyHeight < Epsilon)
                return false;
            y = perpendicular * (1f / bodyHeight);
            z = Cross(x, y);
            if (!KinematicVector3.IsFinite(z))
                return false;
            float zLength = z.Magnitude;
            if (!Finite(zLength) || zLength < Epsilon)
                return false;
            z = z * (1f / zLength);
            return KinematicVector3.IsFinite(shoulderMid);
        }

        private static KinematicVector3 RotateBetweenFrames(
            KinematicVector3 value,
            KinematicVector3 sourceX, KinematicVector3 sourceY,
            KinematicVector3 sourceZ,
            KinematicVector3 destinationX, KinematicVector3 destinationY,
            KinematicVector3 destinationZ)
        {
            return destinationX * KinematicVector3.Dot(value, sourceX) +
                   destinationY * KinematicVector3.Dot(value, sourceY) +
                   destinationZ * KinematicVector3.Dot(value, sourceZ);
        }

        private static KinematicVector3 Cross(
            KinematicVector3 a, KinematicVector3 b)
        {
            return new KinematicVector3(
                a.y * b.z - a.z * b.y,
                a.z * b.x - a.x * b.z,
                a.x * b.y - a.y * b.x);
        }

        private static bool Finite(float x)
        {
            return !float.IsNaN(x) && !float.IsInfinity(x);
        }
    }
}

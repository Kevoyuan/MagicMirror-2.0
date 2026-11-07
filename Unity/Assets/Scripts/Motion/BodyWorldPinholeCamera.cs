// Explicit pinhole intrinsics and REVIEWED camera extrinsics operating in
// MediaPipe-estimated body-world coordinates. Pure C# (Unity + dotnet CI).
// This does NOT infer camera extrinsics, real-world depth, or medical anatomy.
using System;

namespace MagicMirror.Motion
{
    /// <summary>
    /// Camera basis: right = +image X, up = -image Y, forward = +depth.
    /// Cross(right, up) must equal forward (proper rigid orientation).
    /// Focal lengths and principal point are normalized to source image
    /// dimensions. The image has top-left origin and is NOT pre-mirrored.
    /// </summary>
    public struct BodyWorldPinholeCamera
    {
        private const float Tolerance = 0.002f;
        private KinematicVector3 origin;
        private KinematicVector3 right;
        private KinematicVector3 up;
        private KinematicVector3 forward;
        private float focalX;
        private float focalY;
        private float centerX;
        private float centerY;
        private float nearPlane;

        public int ImageWidth { get; private set; }
        public int ImageHeight { get; private set; }
        public bool IsConfigured { get; private set; }

        public static bool TryCreate(
            bool extrinsicsReviewed, bool mirroredSource,
            int width, int height,
            KinematicVector3 cameraOrigin,
            KinematicVector3 cameraRight,
            KinematicVector3 cameraUp,
            KinematicVector3 cameraForward,
            float normalizedFocalX, float normalizedFocalY,
            float normalizedCenterX, float normalizedCenterY,
            float minimumPositiveDepth,
            out BodyWorldPinholeCamera result)
        {
            result = default(BodyWorldPinholeCamera);
            if (!extrinsicsReviewed || mirroredSource ||
                width <= 0 || height <= 0 || width > 8192 || height > 8192 ||
                !KinematicVector3.IsFinite(cameraOrigin) ||
                !KinematicVector3.IsFinite(cameraRight) ||
                !KinematicVector3.IsFinite(cameraUp) ||
                !KinematicVector3.IsFinite(cameraForward) ||
                !Finite(normalizedFocalX) || !Finite(normalizedFocalY) ||
                !Finite(normalizedCenterX) || !Finite(normalizedCenterY) ||
                !Finite(minimumPositiveDepth) ||
                normalizedFocalX < 0.05f || normalizedFocalX > 20f ||
                normalizedFocalY < 0.05f || normalizedFocalY > 20f ||
                normalizedCenterX < 0f || normalizedCenterX > 1f ||
                normalizedCenterY < 0f || normalizedCenterY > 1f ||
                minimumPositiveDepth < 0.0001f || minimumPositiveDepth > 100f)
                return false;

            if (Math.Abs(cameraRight.SqrMagnitude - 1f) > Tolerance ||
                Math.Abs(cameraUp.SqrMagnitude - 1f) > Tolerance ||
                Math.Abs(cameraForward.SqrMagnitude - 1f) > Tolerance ||
                Math.Abs(KinematicVector3.Dot(cameraRight, cameraUp)) > Tolerance ||
                Math.Abs(KinematicVector3.Dot(cameraRight, cameraForward)) > Tolerance ||
                Math.Abs(KinematicVector3.Dot(cameraUp, cameraForward)) > Tolerance)
                return false;

            KinematicVector3 cross = new KinematicVector3(
                cameraRight.y * cameraUp.z - cameraRight.z * cameraUp.y,
                cameraRight.z * cameraUp.x - cameraRight.x * cameraUp.z,
                cameraRight.x * cameraUp.y - cameraRight.y * cameraUp.x);
            if ((cross - cameraForward).Magnitude > Tolerance)
                return false; // NEVER silently reflect X for display mirroring.

            result.origin = cameraOrigin;
            result.right = cameraRight;
            result.up = cameraUp;
            result.forward = cameraForward;
            result.focalX = normalizedFocalX;
            result.focalY = normalizedFocalY;
            result.centerX = normalizedCenterX;
            result.centerY = normalizedCenterY;
            result.nearPlane = minimumPositiveDepth;
            result.ImageWidth = width;
            result.ImageHeight = height;
            result.IsConfigured = true;
            return true;
        }

        /// <summary>
        /// Project body-world point to NORMALIZED UNMIRRORED source pixels.
        /// Returns projected coords even if outside the viewport (to avoid
        /// hiding large errors); refuses invalid or behind-camera points.
        /// </summary>
        public bool TryProjectSource(
            KinematicVector3 world, out float x, out float y)
        {
            x = y = 0f;
            if (!IsConfigured || !KinematicVector3.IsFinite(world))
                return false;
            KinematicVector3 delta = world - origin;
            float z = KinematicVector3.Dot(delta, forward);
            if (!Finite(z) || z <= nearPlane)
                return false;
            x = centerX + focalX * KinematicVector3.Dot(delta, right) / z;
            y = centerY - focalY * KinematicVector3.Dot(delta, up) / z;
            return Finite(x) && Finite(y) &&
                   Math.Abs(x) <= 100f && Math.Abs(y) <= 100f;
        }

        /// <summary>
        /// Reflect only the DISPLAY image's X coordinate when requested.
        /// NEVER alter original MediaPipe world landmarks or projection math.
        /// </summary>
        public static bool TrySourceToDisplay(
            float sourceX, float sourceY, bool mirrorForDisplay,
            out float displayedX, out float displayedY)
        {
            displayedX = displayedY = 0f;
            if (!Finite(sourceX) || !Finite(sourceY))
                return false;
            displayedX = mirrorForDisplay ? 1f - sourceX : sourceX;
            displayedY = sourceY;
            return Finite(displayedX);
        }

        private static bool Finite(float value)
        {
            return !float.IsNaN(value) && !float.IsInfinity(value);
        }
    }
}

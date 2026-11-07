// Engine-independent transform from ORIGINAL FULL-FBX root LOCAL
// coordinates to an EXPLICITLY REVIEWED body-world camera frame.
// Compiled verbatim by Unity and .NET CI. Never infers camera parameters.
using System;

namespace MagicMirror.Motion
{
    /// <summary>
    /// A proper rigid rotation + uniform scale + translation mapping the
    /// reference atlas's ROOT-LOCAL 3D coordinates into source CAMERA-LOCAL
    /// coordinates. +X right, +Y up, +Z forward; NO hidden reflection.
    /// </summary>
    public struct AtlasCameraSpaceRegistration
    {
        public KinematicVector3 AtlasRootOriginCameraLocal { get; private set; }
        public KinematicVector3 AtlasLocalXAxisCamera { get; private set; }
        public KinematicVector3 AtlasLocalYAxisCamera { get; private set; }
        public KinematicVector3 AtlasLocalZAxisCamera { get; private set; }
        public float CameraUnitsPerAtlasUnit { get; private set; }
        public bool IsValid { get; private set; }

        public static bool TryCreate(
            BodySimilarityCalibration atlasReference,
            BodyWorldPinholeCamera reviewedCamera,
            out AtlasCameraSpaceRegistration result)
        {
            result = default(AtlasCameraSpaceRegistration);
            if (!atlasReference.IsValid || !reviewedCamera.IsConfigured)
                return false;

            KinematicVector3 origin, x, y, z;
            if (!Map(KinematicVector3.Zero, atlasReference, reviewedCamera, out origin) ||
                !Map(new KinematicVector3(1f, 0f, 0f),
                     atlasReference, reviewedCamera, out x) ||
                !Map(new KinematicVector3(0f, 1f, 0f),
                     atlasReference, reviewedCamera, out y) ||
                !Map(new KinematicVector3(0f, 0f, 1f),
                     atlasReference, reviewedCamera, out z))
                return false;

            KinematicVector3 axisX = x - origin;
            KinematicVector3 axisY = y - origin;
            KinematicVector3 axisZ = z - origin;
            float scale = axisX.Magnitude;
            if (!Positive(scale) || !CloseLength(axisY.Magnitude, scale) ||
                !CloseLength(axisZ.Magnitude, scale))
                return false;
            axisX = axisX * (1f / scale);
            axisY = axisY * (1f / scale);
            axisZ = axisZ * (1f / scale);

            if (Math.Abs(KinematicVector3.Dot(axisX, axisY)) > 0.002f ||
                Math.Abs(KinematicVector3.Dot(axisX, axisZ)) > 0.002f ||
                Math.Abs(KinematicVector3.Dot(axisY, axisZ)) > 0.002f ||
                (Cross(axisX, axisY) - axisZ).Magnitude > 0.002f)
                return false;

            result.AtlasRootOriginCameraLocal = origin;
            result.AtlasLocalXAxisCamera = axisX;
            result.AtlasLocalYAxisCamera = axisY;
            result.AtlasLocalZAxisCamera = axisZ;
            result.CameraUnitsPerAtlasUnit = scale;
            result.IsValid = true;
            return true;
        }

        /// <summary>
        /// Camera-space point for atlas root-local anatomical coordinate.
        /// The Unity scene camera can compose its world transform on top.
        /// </summary>
        public bool TryAtlasLocalToCamera(
            KinematicVector3 atlasRootLocal, out KinematicVector3 cameraLocal)
        {
            cameraLocal = KinematicVector3.Zero;
            if (!IsValid || !KinematicVector3.IsFinite(atlasRootLocal))
                return false;
            cameraLocal = AtlasRootOriginCameraLocal +
                AtlasLocalXAxisCamera * (atlasRootLocal.x * CameraUnitsPerAtlasUnit) +
                AtlasLocalYAxisCamera * (atlasRootLocal.y * CameraUnitsPerAtlasUnit) +
                AtlasLocalZAxisCamera * (atlasRootLocal.z * CameraUnitsPerAtlasUnit);
            return KinematicVector3.IsFinite(cameraLocal);
        }

        private static bool Map(
            KinematicVector3 atlasPoint,
            BodySimilarityCalibration calibration,
            BodyWorldPinholeCamera camera,
            out KinematicVector3 cameraPoint)
        {
            cameraPoint = KinematicVector3.Zero;
            KinematicVector3 poseWorld;
            return calibration.TryAtlasToPose(atlasPoint, out poseWorld) &&
                   camera.TryToCameraSpace(poseWorld, out cameraPoint);
        }

        private static bool Positive(float f)
        {
            return !float.IsNaN(f) && !float.IsInfinity(f) && f > 1e-6f;
        }

        private static bool CloseLength(float actual, float expected)
        {
            return Positive(actual) &&
                   Math.Abs(actual - expected) <= expected * 0.002f + 1e-6f;
        }

        private static KinematicVector3 Cross(
            KinematicVector3 a, KinematicVector3 b)
        {
            return new KinematicVector3(
                a.y * b.z - a.z * b.y,
                a.z * b.x - a.x * b.z,
                a.x * b.y - a.y * b.x);
        }
    }
}

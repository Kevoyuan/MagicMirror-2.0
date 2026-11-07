using System;
using MagicMirror.Motion;
using UnityEditor;
using UnityEngine;

namespace MagicMirror.Editor
{
    /// <summary>
    /// Future real Unity Editor compile/execute smoke for off-axis source
    /// camera projection. All inputs are CONSTRUCTED, not physical camera
    /// evidence. No user data, FBX, webcam or Unity scene rendering.
    /// </summary>
    public static class M5ReviewedSourceCameraSelfCheck
    {
        [MenuItem("MagicMirror/Validation/Reviewed Source Camera Projection Check")]
        public static void Run()
        {
            BodySimilarityCalibration registration;
            Ensure(BodySimilarityCalibration.TryCreate(
                V(-1, 0, 0), V(1, 0, 0), V(0, -1, 0),
                V(5, 8, 2), V(5, 12, 2), V(7, 10, 2),
                0.1f, 10f, 0.01f, out registration),
                "3D reference fit");

            BodyWorldPinholeCamera lens;
            Ensure(BodyWorldPinholeCamera.TryCreate(
                true, false, 1280, 720,
                V(0, 0, -5),
                V(1, 0, 0), V(0, 1, 0), V(0, 0, 1),
                0.7f, 0.8f, 0.45f, 0.56f, 0.01f, out lens),
                "source intrinsics and reviewed body-world extrinsics");

            AtlasCameraSpaceRegistration atlas;
            Ensure(AtlasCameraSpaceRegistration.TryCreate(
                registration, lens, out atlas), "atlas-to-camera registration");
            KinematicVector3 point;
            Ensure(atlas.TryAtlasLocalToCamera(
                V(5, 8, 2), out point), "source FBX shoulder to camera");
            Ensure(Mathf.Abs(point.x + 1f) < 0.001f &&
                   Mathf.Abs(point.y) < 0.001f &&
                   Mathf.Abs(point.z - 5f) < 0.001f,
                   "expected source-space shoulder depth and X");

            PinholeCameraFrustum f;
            Ensure(lens.TryGetSourceFrustum(0.1f, 100f, out f),
                   "off-axis source camera frustum");
            Ensure(f.right > f.left && f.top > f.bottom &&
                   f.nearClip > 0f && f.farClip > f.nearClip,
                   "physically non-degenerate projection");
            Matrix4x4 projection = Matrix4x4.Frustum(
                f.left, f.right, f.bottom, f.top, f.nearClip, f.farClip);
            Ensure(!float.IsNaN(projection.m00) &&
                   !float.IsInfinity(projection.m11) &&
                   projection.m00 > 0f && projection.m11 > 0f,
                   "Unity frustum construction finite");

            Ensure(!BodyWorldPinholeCamera.TryCreate(
                false, false, 1280, 720,
                V(0, 0, -5), V(1, 0, 0), V(0, 1, 0), V(0, 0, 1),
                0.7f, 0.8f, 0.45f, 0.56f, 0.01f, out lens),
                "unreviewed camera rejected");

            Debug.Log("MAGICMIRROR_M5_CAMERA_EDITOR_PASS: " +
                      "synthetic off-axis math only; actual FBX/camera/AR NOT validated.");
        }

        private static KinematicVector3 V(float x, float y, float z)
        {
            return new KinematicVector3(x, y, z);
        }

        private static void Ensure(bool condition, string label)
        {
            if (!condition)
                throw new InvalidOperationException("M5 camera editor: " + label);
        }
    }
}

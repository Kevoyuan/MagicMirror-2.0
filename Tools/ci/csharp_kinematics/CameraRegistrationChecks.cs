// Actual pure C# camera intrinsics + full-FBX registration test, no Unity.
// Synthetic body/world/reference anchors are NOT individual anatomy proof.
using System;
using MagicMirror.Motion;

internal static class CameraRegistrationChecks
{
    private static int count;
    private static KinematicVector3 V(float x, float y, float z)
    {
        return new KinematicVector3(x, y, z);
    }
    private static void Check(bool condition, string reason)
    {
        if (!condition) throw new InvalidOperationException("Camera calibration: " + reason);
        count++;
    }
    private static void Near(float expected, float actual, string reason, float eps = 0.002f)
    {
        Check(Math.Abs(expected - actual) < eps,
              reason + " expected " + expected + " actual " + actual);
    }
    private static BodySimilarityCalibration AtlasCalibration()
    {
        BodySimilarityCalibration c;
        Check(BodySimilarityCalibration.TryCreate(
            V(-1, 0, 0), V(1, 0, 0), V(0, -1, 0),
            V(5, 8, 2), V(5, 12, 2), V(7, 10, 2),
            0.1f, 10f, 0.01f, out c), "reviewed synthetic atlas fit");
        return c;
    }
    private static BodyWorldPinholeCamera Camera()
    {
        BodyWorldPinholeCamera cam;
        Check(BodyWorldPinholeCamera.TryCreate(
            true, false, 1280, 720,
            V(0, 0, -5), V(1, 0, 0), V(0, 1, 0), V(0, 0, 1),
            0.7f, 0.8f, 0.45f, 0.56f, 0.05f, out cam),
            "explicit off-center intrinsics and proper 3D extrinsics");
        return cam;
    }

    public static int Run()
    {
        BodySimilarityCalibration atlas = AtlasCalibration();
        BodyWorldPinholeCamera camera = Camera();
        AtlasCameraSpaceRegistration registration;
        Check(AtlasCameraSpaceRegistration.TryCreate(
            atlas, camera, out registration), "build atlas to real calibrated camera");
        Check(registration.IsValid, "registration is valid");
        Near(0.5f, registration.CameraUnitsPerAtlasUnit,
             "atlas units converted back to body-world metric scale");

        KinematicVector3 camOrigin;
        Check(registration.TryAtlasLocalToCamera(
            V(0, 0, 0), out camOrigin), "atlas origin to camera");
        Near(registration.AtlasRootOriginCameraLocal.x, camOrigin.x,
             "translation origin x");
        Near(registration.AtlasRootOriginCameraLocal.y, camOrigin.y,
             "translation origin y");
        Near(registration.AtlasRootOriginCameraLocal.z, camOrigin.z,
             "translation origin z");

        KinematicVector3 atlasShoulderCamera;
        Check(registration.TryAtlasLocalToCamera(
            V(5, 8, 2), out atlasShoulderCamera),
            "left reviewed atlas shoulder");
        Near(-1, atlasShoulderCamera.x, "reviewed left shoulder camera X");
        Near(0, atlasShoulderCamera.y, "reviewed left shoulder camera Y");
        Near(5, atlasShoulderCamera.z, "reviewed left shoulder camera Z");

        KinematicVector3 shoulderPoseWorld;
        Check(atlas.TryAtlasToPose(
            V(5, 8, 2), out shoulderPoseWorld),
            "inverse body registration");
        KinematicVector3 directShoulderCamera;
        Check(camera.TryToCameraSpace(
            shoulderPoseWorld, out directShoulderCamera),
            "camera-space point from pose-world");
        Near(directShoulderCamera.x, atlasShoulderCamera.x, "two paths camera X");
        Near(directShoulderCamera.y, atlasShoulderCamera.y, "two paths camera Y");
        Near(directShoulderCamera.z, atlasShoulderCamera.z, "two paths camera Z");

        float sx, sy;
        Check(camera.TryProjectSource(shoulderPoseWorld, out sx, out sy),
              "source perspective projection");
        Near(0.31f, sx, "off-center source image X, unmirrored");
        Near(0.56f, sy, "off-center source image Y");

        PinholeCameraFrustum frustum;
        Check(camera.TryGetSourceFrustum(0.1f, 100f, out frustum),
              "source intrinsics produce Unity frustum");
        Near(-0.45f * 0.1f / 0.7f, frustum.left, "frustum left");
        Near((1f - 0.45f) * 0.1f / 0.7f, frustum.right, "frustum right");
        Near(-(1f - 0.56f) * 0.1f / 0.8f, frustum.bottom, "frustum bottom");
        Near(0.56f * 0.1f / 0.8f, frustum.top, "frustum top");

        // Viewport projection of an off-axis frustum must match original
        // top-left camera-space normalized pixels, even at 1280x720.
        float projectionPlaneX = atlasShoulderCamera.x *
                                 frustum.nearClip / atlasShoulderCamera.z;
        float projectionPlaneY = atlasShoulderCamera.y *
                                 frustum.nearClip / atlasShoulderCamera.z;
        float ux = (projectionPlaneX - frustum.left) /
                   (frustum.right - frustum.left);
        float vy = 1f - (projectionPlaneY - frustum.bottom) /
                          (frustum.top - frustum.bottom);
        Near(sx, ux, "Unity off-axis projection source X");
        Near(sy, vy, "Unity off-axis projection source Y");

        // Front/back and camera basis must NOT be silently reflected.
        BodyWorldPinholeCamera badCamera = default(BodyWorldPinholeCamera);
        Check(!AtlasCameraSpaceRegistration.TryCreate(
            atlas, badCamera, out registration),
            "missing camera calibration never authorizes atlas registration");
        Check(!AtlasCameraSpaceRegistration.TryCreate(
            default(BodySimilarityCalibration), camera, out registration),
            "missing anatomical reference calibration rejected");
        Check(!camera.TryToCameraSpace(
            V(float.NaN, 0, 0), out camOrigin),
            "NaN camera-space coordinates rejected");
        Check(!camera.TryGetSourceFrustum(
            -1, 100, out frustum),
            "near-plane must be positive");
        Check(!camera.TryGetSourceFrustum(
            100, 0.1f, out frustum),
            "far-plane must exceed near");
        Check(!camera.TryGetSourceFrustum(
            0.1f, float.NaN, out frustum),
            "nonfinite far plane rejected");

        Check(AtlasCameraSpaceRegistration.TryCreate(
            atlas, camera, out registration),
            "restore valid camera registration");
        Check(!registration.TryAtlasLocalToCamera(
            V(float.PositiveInfinity, 0, 0), out camOrigin),
            "nonfinite FBX root-local coordinate rejected");
        Check(!default(AtlasCameraSpaceRegistration).TryAtlasLocalToCamera(
            V(1, 2, 3), out camOrigin),
            "uninitialized registration does not move original anatomy");

        // Validate the map on multiple atlas points in full 3D, not just a
        // planar set of anatomical reference anchors.
        for(int i=0; i<30; ++i)
        {
            KinematicVector3 point = V((i-15)*0.2f, (i-7)*0.1f, i*0.05f);
            KinematicVector3 pose;
            KinematicVector3 direct;
            KinematicVector3 fromAtlas;
            Check(atlas.TryAtlasToPose(point, out pose), "inverse map 3D point");
            Check(camera.TryToCameraSpace(pose, out direct), "camera direct map");
            Check(registration.TryAtlasLocalToCamera(point, out fromAtlas),
                  "new atlas camera registration map");
            Near(direct.x, fromAtlas.x, "atlas camera X roundtrip");
            Near(direct.y, fromAtlas.y, "atlas camera Y roundtrip");
            Near(direct.z, fromAtlas.z, "atlas camera Z roundtrip");
        }

        Console.WriteLine("MAGICMIRROR_M5_CAMERA_REGISTRATION_PASS: " +
                          count + " actual C# assertions; synthetic camera model only.");
        return count;
    }
}

// Same-frame image landmark vs estimated world landmark consistency.
// Executes REAL Unity production BodyWorldCameraConsistency.cs under dotnet.
// Synthetic data is not actual camera extrinsics or anatomical correctness.
using System;
using MagicMirror.Motion;
using MagicMirror.Tracking;

internal static class CameraPoseGateChecks
{
    private static int assertions;
    private static void Check(bool ok, string label)
    {
        if (!ok) throw new InvalidOperationException("Camera pose gate: " + label);
        assertions++;
    }
    private static PoseLandmark L(float x, float y, float z = 0f)
    {
        return new PoseLandmark {
            x = x, y = y, z = z, visibility = 1f, presence = 1f
        };
    }
    private static BodyWorldPinholeCamera Cam()
    {
        BodyWorldPinholeCamera c;
        Check(BodyWorldPinholeCamera.TryCreate(true, false,
            1280, 720,
            new KinematicVector3(0f, 0f, -5f),
            new KinematicVector3(1f, 0f, 0f),
            new KinematicVector3(0f, 1f, 0f),
            new KinematicVector3(0f, 0f, 1f),
            0.7f, 0.8f, 0.45f, 0.56f, 0.01f, out c),
            "reviewed off-center camera parameters");
        return c;
    }
    private static PoseFrame Frame()
    {
        var frame = new PoseFrame {
            version = 1, frameId = 21, timestampMs = 3000,
            streamSessionId = 77,
            width = 1280, height = 720,
            demo = false, mirrored = false,
            landmarks = new PoseLandmark[33],
            worldLandmarks = new PoseLandmark[33]
        };
        for(int i=0;i<33;i++) {
            frame.landmarks[i] = L(0.5f, 0.5f);
            frame.worldLandmarks[i] = L(0f,0f);
        }
        // Projection exact: x = .45 + .7*X/5; y = .56 - .8*Y/5
        frame.worldLandmarks[11] = L(-1f, 0f);
        frame.landmarks[11] = L(0.31f, 0.56f);
        frame.worldLandmarks[12] = L(1f, 0f);
        frame.landmarks[12] = L(0.59f, 0.56f);
        frame.worldLandmarks[23] = L(-0.2f, -1f);
        frame.landmarks[23] = L(0.422f, 0.72f);
        frame.worldLandmarks[24] = L(0.2f, -1f);
        frame.landmarks[24] = L(0.478f, 0.72f);
        return frame;
    }
    public static int Run()
    {
        BodyWorldPinholeCamera camera = Cam();
        PoseFrame frame = Frame();
        CameraPoseConsistencyReport report;
        Check(BodyWorldCameraConsistency.TryValidate(
            frame, camera, 0.5f, 0.03f, out report),
            "exact 3D/2D major-joint projection accepted");
        Check(report.StreamSessionId == 77 && report.SourceFrameId == 21,
            "reprojection retains original TCP generation and packet");
        Check(report.P90NormalizedBySourceWidth < 1e-5f,
            "zero residual on synthetic 1280 x 720 projected points");
        Check(!report.IndependentlyValidated,
            "internal 3D-vs-2D check is not anatomical ground truth");

        frame.landmarks[23].y += 0.1f; // 72 pixels / 1280 = 0.05625
        Check(!BodyWorldCameraConsistency.TryValidate(
            frame, camera, 0.5f, 0.03f, out report),
            "bad aspect-corrected Y projection fails closed");
        frame = Frame();
        frame.landmarks[11].x += 0.04f; // 4% source width
        Check(!BodyWorldCameraConsistency.TryValidate(
            frame, camera, 0.5f, 0.03f, out report),
            "2D/3D projection mismatch blocks overlay");
        frame = Frame();
        frame.landmarks[12].visibility = 0.1f;
        Check(!BodyWorldCameraConsistency.TryValidate(
            frame, camera, 0.5f, 0.03f, out report),
            "missing shoulder confidence blocks overlay");
        frame = Frame();
        frame.worldLandmarks[24].z = -20f;
        Check(!BodyWorldCameraConsistency.TryValidate(
            frame, camera, 0.5f, 0.03f, out report),
            "hip behind camera rejected");
        frame = Frame();
        frame.worldLandmarks[23].x = float.NaN;
        Check(!BodyWorldCameraConsistency.TryValidate(
            frame, camera, 0.5f, 0.03f, out report),
            "nonfinite body-world point rejected");
        frame = Frame();
        frame.mirrored = true;
        Check(!BodyWorldCameraConsistency.TryValidate(
            frame, camera, 0.5f, 0.03f, out report),
            "source frame mirror convention mismatch rejected");
        frame = Frame();
        frame.demo = true;
        Check(!BodyWorldCameraConsistency.TryValidate(
            frame, camera, 0.5f, 0.03f, out report),
            "schematic demo cannot authenticate camera overlay");
        frame = Frame();
        frame.width = 640;
        Check(!BodyWorldCameraConsistency.TryValidate(
            frame, camera, 0.5f, 0.03f, out report),
            "camera source size mismatch rejected");
        frame = Frame();
        Check(!BodyWorldCameraConsistency.TryValidate(
            frame, default(BodyWorldPinholeCamera), 0.5f, 0.03f, out report),
            "unreviewed camera cannot run projection gate");
        Check(!BodyWorldCameraConsistency.TryValidate(
            frame, camera, 0.5f, float.NaN, out report),
            "invalid P90 limit cannot authorize AR");
        Console.WriteLine("MAGICMIRROR_M5_CAMERA_POSE_GATE_PASS: " +
                          assertions + " compiled source checks, no real camera.");
        return assertions;
    }
}

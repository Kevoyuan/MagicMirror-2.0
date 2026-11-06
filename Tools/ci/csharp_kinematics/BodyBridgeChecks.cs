// Exercises ACTUAL PoseStreamProtocol.cs + both Unity C# world bridges
// against synthetic test frames; the only stub is an empty Unity namespace.
// This is NOT a Unity Editor or real-camera test.
using System;
using MagicMirror.Motion;
using MagicMirror.Tracking;

internal static class BodyBridgeChecks
{
    private static int checks;

    private static KinematicVector3 P(float x, float y, float z)
    {
        return new KinematicVector3(x, y, z);
    }

    private static void Assert(bool ok, string label)
    {
        if (!ok) throw new InvalidOperationException("PoseFrame/atlas bridge: " + label);
        checks++;
    }

    private static PoseLandmark Landmark(float x, float y, float z,
                                          float confidence)
    {
        return new PoseLandmark
        {
            x = x, y = y, z = z,
            visibility = confidence, presence = confidence
        };
    }

    private static PoseFrame Frame()
    {
        var frame = new PoseFrame
        {
            version = 1,
            frameId = 1,
            timestampMs = 1000,
            width = 1280,
            height = 720,
            mirrored = false,
            demo = false,
            landmarks = new PoseLandmark[33],
            worldLandmarks = new PoseLandmark[33]
        };
        for (int i = 0; i < 33; i++)
        {
            frame.landmarks[i] = Landmark(0.5f, 0.5f, 0f, 1f);
            frame.worldLandmarks[i] = Landmark(0f, 0f, 0f, 1f);
        }

        // Hip-centered synthetic pose-world samples; NOT actual anatomy.
        SetWorld(frame, 11, -1f, 0f, 0f);
        SetWorld(frame, 12, 1f, 0f, 0f);
        SetWorld(frame, 23, -0.2f, -1f, 0f);
        SetWorld(frame, 24, 0.2f, -1f, 0f);
        // A left arm bent toward positive Y for the M4 diagnostic check.
        SetWorld(frame, 13, -0.5f, 0.8f, 0f);
        SetWorld(frame, 15, 0f, 0f, 0f);
        return frame;
    }

    private static void SetWorld(
        PoseFrame frame, int index, float x, float y, float z)
    {
        frame.worldLandmarks[index] = Landmark(x, y, z, 1f);
    }

    private static bool Calibrate(PoseFrame frame, bool reviewed,
                                  out BodySimilarityCalibration result,
                                  float residualGate = 0.1f)
    {
        return BodyWorldCalibrationBridge.TryCaptureReferencePose(
            frame, reviewed,
            P(5f, 8f, 2f), P(5f, 12f, 2f), P(7f, 10f, 2f),
            0.5f, 0.1f, 10f, residualGate, out result);
    }

    public static int Run()
    {
        var frame = Frame();
        BodySimilarityCalibration calibration;
        Assert(frame.IsValid, "real Unity PoseFrame source valid");
        Assert(Calibrate(frame, true, out calibration),
               "explicit reviewed reference-pose capture accepted");
        Assert(calibration.IsValid, "calibration contains a valid rigid fit");
        Assert(Math.Abs(calibration.Scale - 2f) < 0.0001f,
               "uniform body-to-atlas scale from measured shoulder width");

        KinematicVector3 mapped;
        Assert(calibration.TryPoseToAtlas(P(-1f, 0f, 0f), out mapped),
               "mapping reviewed shoulder");
        Assert(Math.Abs(mapped.y - 8f) < 0.0001f,
               "reviewed reference anatomy shoulder location");

        Assert(!Calibrate(frame, false, out calibration),
               "refuse unreviewed anatomical joint anchors");
        frame.mirrored = true;
        Assert(!Calibrate(frame, true, out calibration),
               "source mirrored flag refuses unsupported 3D convention");
        frame.mirrored = false;
        frame.demo = true;
        Assert(!Calibrate(frame, true, out calibration),
               "do not calibrate real anatomy from synthetic demo frames");
        frame.demo = false;

        frame.landmarks[11].visibility = 0.1f;
        Assert(!Calibrate(frame, true, out calibration),
               "low-confidence shoulder detection rejected");
        frame.landmarks[11].visibility = 1f;
        frame.landmarks[23].presence = 0.1f;
        Assert(!Calibrate(frame, true, out calibration),
               "low-confidence hip presence rejected");
        frame.landmarks[23].presence = 1f;

        frame.worldLandmarks[11].x = float.NaN;
        Assert(!Calibrate(frame, true, out calibration),
               "NaN pose world data rejected");
        frame.worldLandmarks[11].x = -1f;
        frame.worldLandmarks[23] = null;
        Assert(!Calibrate(frame, true, out calibration),
               "missing pelvis world coordinate rejected");
        SetWorld(frame, 23, -0.2f, -1f, 0f);

        var savedWorld = frame.worldLandmarks;
        frame.worldLandmarks = null;
        Assert(!Calibrate(frame, true, out calibration),
               "missing world landmarks rejected");
        frame.worldLandmarks = savedWorld;
        frame.version = 4;
        Assert(!Calibrate(frame, true, out calibration),
               "incompatible wire protocol rejected");
        frame.version = 1;
        frame.landmarks = new PoseLandmark[0];
        Assert(!Calibrate(frame, true, out calibration),
               "no visible normalized landmarks rejected");
        frame = Frame();
        Assert(Calibrate(frame, true, out calibration), "reacquisition reference accepted");

        // Link the REAL M4 world-coordinate IK output to the reviewed M5
        // calibration mathematics. Do NOT drive actual FBX transforms.
        TwoBoneSolution sourceLimb;
        Assert(TwoBoneWorldPoseBridge.TrySolveEstimatedWorld(
            frame, TrackedTwoLinkLimb.LeftArm, 0.5f,
            1f, 1f, 0f, 150f, out sourceLimb),
            "real M4 world bridge solves 3D synthetic left elbow");

        KinematicVector3 jointAtlas, firstAtlas, distalAtlas;
        Assert(calibration.TryPoseToAtlas(sourceLimb.proximal, out firstAtlas),
               "IK first anchor to atlas");
        Assert(calibration.TryPoseToAtlas(sourceLimb.elbowOrKnee, out jointAtlas),
               "IK elbow to atlas");
        Assert(calibration.TryPoseToAtlas(sourceLimb.distal, out distalAtlas),
               "IK distal target to atlas");
        Assert(Math.Abs((jointAtlas - firstAtlas).Magnitude - 2f) < 0.002f,
               "scaled first atlas reference length preserved");
        Assert(Math.Abs((jointAtlas - distalAtlas).Magnitude - 2f) < 0.002f,
               "scaled second atlas reference length preserved");
        Assert(sourceLimb.flexionDegrees >= 0 &&
               sourceLimb.flexionDegrees <= 150f,
               "IK hinge bound remains valid after registration");

        frame.landmarks[13].visibility = 0.0f;
        Assert(!TwoBoneWorldPoseBridge.TrySolveEstimatedWorld(
            frame, TrackedTwoLinkLimb.LeftArm, 0.5f,
            1f, 1f, 0f, 150f, out sourceLimb),
            "source elbow dropout refuses estimated limb IK");

        Console.WriteLine("MAGICMIRROR_M5_REAL_POSEFRAME_BRIDGE_PASS: " +
                          checks + " assertions (actual C# protocol, no Unity).");
        return checks;
    }
}

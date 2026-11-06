// Executable test of the EXACT production Unity atlas command planner.
// Uses 33-pose PoseFrame-v1 synthetic records and the real compiled M4/M5
// math. No Unity runtime or actual FBX import is implied.
using System;
using MagicMirror.Motion;
using MagicMirror.Tracking;

internal static class AtlasPlannerChecks
{
    private static int assertions;

    private static KinematicVector3 P(float x, float y, float z)
    {
        return new KinematicVector3(x, y, z);
    }
    private static void Check(bool condition, string label)
    {
        if (!condition)
            throw new InvalidOperationException("M4-M5 atlas plan: " + label);
        assertions++;
    }
    private static void Near(float a, float b, string label)
    {
        Check(Math.Abs(a - b) <= 0.002f,
              label + " expected " + b + ", got " + a);
    }
    private static PoseLandmark Point(float x, float y, float z, float confidence = 1f)
    {
        return new PoseLandmark
        {
            x = x, y = y, z = z,
            visibility = confidence, presence = confidence
        };
    }
    private static void Set(PoseFrame frame, int index,
                            float x, float y, float z)
    {
        frame.worldLandmarks[index] = Point(x, y, z);
    }
    private static PoseFrame Frame()
    {
        var f = new PoseFrame
        {
            version = 1, frameId = 234, timestampMs = 5000,
            width = 1280, height = 720, mirrored = false, demo = false,
            landmarks = new PoseLandmark[33],
            worldLandmarks = new PoseLandmark[33]
        };
        for (int i = 0; i < 33; i++)
        {
            f.landmarks[i] = Point(0.5f, 0.5f, 0f);
            f.worldLandmarks[i] = Point(0f, 0f, 0f);
        }
        Set(f, 11, -1f, 0f, 0f);    // left shoulder
        Set(f, 13, -0.5f, 0.8f, 0f); // elbow pole
        Set(f, 15, 0f, 0f, 0f);     // wrist
        Set(f, 12, 1f, 0f, 0f);    // right shoulder
        Set(f, 14, 0.5f, -0.8f, 0f);
        Set(f, 16, 0f, 0f, 0f);
        Set(f, 23, -0.2f, -1f, 0f);
        Set(f, 25, -0.2f, -2f, 0.8f);
        Set(f, 27, -0.2f, -3f, 0f);
        Set(f, 24, 0.2f, -1f, 0f);
        Set(f, 26, 0.2f, -2f, -0.8f);
        Set(f, 28, 0.2f, -3f, 0f);
        return f;
    }
    private static BodySimilarityCalibration Calibration()
    {
        BodySimilarityCalibration t;
        Check(BodySimilarityCalibration.TryCreate(
            P(-1f, 0f, 0f), P(1f, 0f, 0f), P(0f, -1f, 0f),
            P(5f, 8f, 2f), P(5f, 12f, 2f), P(7f, 10f, 2f),
            0.1f, 10f, 0.01f, out t),
            "frozen right-handed synthetic reference registration");
        return t;
    }
    private static ReviewedAtlasTwoLinkChain Chain(KinematicVector3 start)
    {
        return new ReviewedAtlasTwoLinkChain
        {
            proximalAtlasLocal = start,
            hingeAtlasLocal = start + P(0f, 2f, 0f),
            distalAtlasLocal = start + P(0f, 4f, 0f),
            upperRegionReviewed = true,
            lowerRegionReviewed = true
        };
    }
    private static bool Plan(PoseFrame frame, TrackedTwoLinkLimb limb,
                             BodySimilarityCalibration t,
                             ReviewedAtlasTwoLinkChain anchors,
                             out AtlasTwoLinkMotionCommand command)
    {
        return AtlasTwoLinkMotionPlanner.TryPlan(
            frame, limb, t, anchors, 0.5f, 0f, 150f, out command);
    }
    private static void VerifyChain(AtlasTwoLinkMotionCommand cmd,
                                    TrackedTwoLinkLimb limb, PoseFrame frame)
    {
        Check(cmd.isValid, "plan marked valid");
        Check(cmd.limb == limb, "correct limb side and type");
        Check(cmd.sourceFrameId == frame.frameId &&
              cmd.sourceTimestampMs == frame.timestampMs,
              "plan retains original source frame identity");
        Near((cmd.upper.targetEndAtlasLocal -
              cmd.upper.targetStartAtlasLocal).Magnitude, 2f,
              "upper length preserved from full atlas rest");
        Near((cmd.lower.targetEndAtlasLocal -
              cmd.lower.targetStartAtlasLocal).Magnitude, 2f,
              "lower length preserved from full atlas rest");
        Near((cmd.upper.targetEndAtlasLocal -
              cmd.lower.targetStartAtlasLocal).Magnitude, 0f,
              "anatomically connected elbow/knee");
        Near((cmd.upper.restEndAtlasLocal -
              cmd.lower.restStartAtlasLocal).Magnitude, 0f,
              "full atlas rest references share same joint");
        Check(cmd.flexionDegrees >= 0f && cmd.flexionDegrees <= 150f,
              "hinge within allowed flexion");
    }

    public static int Run()
    {
        PoseFrame frame = Frame();
        var calibration = Calibration();
        var left = Chain(P(5f, 8f, 2f));
        var right = Chain(P(5f, 12f, 2f));
        var leftLeg = Chain(P(7f, 9f, 2f));
        var rightLeg = Chain(P(7f, 11f, 2f));
        AtlasTwoLinkMotionCommand cmd;

        Check(Plan(frame, TrackedTwoLinkLimb.LeftArm,
                   calibration, left, out cmd),
              "left arm reviewed atlas plan");
        VerifyChain(cmd, TrackedTwoLinkLimb.LeftArm, frame);
        Check(cmd.streamSessionId == frame.streamSessionId,
              "planner preserves original transport generation");
        Check(!cmd.unreachableTargetClamped,
              "reachable wrist does not need clamping");
        Check(Plan(frame, TrackedTwoLinkLimb.RightArm,
                   calibration, right, out cmd),
              "right arm reviewed atlas plan");
        VerifyChain(cmd, TrackedTwoLinkLimb.RightArm, frame);
        Check(Plan(frame, TrackedTwoLinkLimb.LeftLeg,
                   calibration, leftLeg, out cmd),
              "left leg reviewed atlas plan");
        VerifyChain(cmd, TrackedTwoLinkLimb.LeftLeg, frame);
        Check(Plan(frame, TrackedTwoLinkLimb.RightLeg,
                   calibration, rightLeg, out cmd),
              "right leg reviewed atlas plan");
        VerifyChain(cmd, TrackedTwoLinkLimb.RightLeg, frame);

        // Move right wrist unrealizably far; the reference model still keeps
        // rigid links and exposes the clamping diagnostic.
        Set(frame, 16, -20f, 0f, 0f);
        Check(Plan(frame, TrackedTwoLinkLimb.RightArm,
                   calibration, right, out cmd),
              "out of reach wrist corrected by hinge limits");
        VerifyChain(cmd, TrackedTwoLinkLimb.RightArm, frame);
        Check(cmd.unreachableTargetClamped, "unreachable wrist visibly flagged");

        frame = Frame();
        left.upperRegionReviewed = false;
        Check(!Plan(frame, TrackedTwoLinkLimb.LeftArm,
                    calibration, left, out cmd),
              "anatomy upper group without review is refused");
        left.upperRegionReviewed = true;
        left.lowerRegionReviewed = false;
        Check(!Plan(frame, TrackedTwoLinkLimb.LeftArm,
                    calibration, left, out cmd),
              "anatomy lower group without review is refused");
        left.lowerRegionReviewed = true;

        left.distalAtlasLocal = left.hingeAtlasLocal;
        Check(!Plan(frame, TrackedTwoLinkLimb.LeftArm,
                    calibration, left, out cmd),
              "zero length distal reference bone is refused");
        left = Chain(P(5f, 8f, 2f));

        frame.demo = true;
        Check(!Plan(frame, TrackedTwoLinkLimb.LeftArm,
                    calibration, left, out cmd),
              "synthetic demo cannot drive real bone bindings");
        frame.demo = false;
        frame.mirrored = true;
        Check(!Plan(frame, TrackedTwoLinkLimb.LeftArm,
                    calibration, left, out cmd),
              "mirrored source is refused");
        frame.mirrored = false;

        frame.landmarks[13].visibility = 0f;
        Check(!Plan(frame, TrackedTwoLinkLimb.LeftArm,
                    calibration, left, out cmd),
              "elbow dropout fails the entire limb pair");
        frame.landmarks[13].visibility = 1f;

        frame.worldLandmarks[13].x = float.NaN;
        Check(!Plan(frame, TrackedTwoLinkLimb.LeftArm,
                    calibration, left, out cmd),
              "nonfinite pole refuses unobservable bend");
        frame.worldLandmarks[13].x = -0.5f;

        Set(frame, 13, -0.5f, 0f, 0f);
        Check(!Plan(frame, TrackedTwoLinkLimb.LeftArm,
                    calibration, left, out cmd),
              "collinear source bend pole rejected");

        frame = Frame();
        Check(!AtlasTwoLinkMotionPlanner.TryPlan(
            frame, TrackedTwoLinkLimb.LeftArm,
            default(BodySimilarityCalibration), left,
            0.5f, 0f, 150f, out cmd),
            "missing frozen atlas calibration rejected");
        Check(!AtlasTwoLinkMotionPlanner.TryPlan(
            frame, TrackedTwoLinkLimb.LeftArm,
            calibration, left, 1.1f, 0f, 150f, out cmd),
            "invalid confidence threshold rejected");
        Check(!AtlasTwoLinkMotionPlanner.TryPlan(
            frame, TrackedTwoLinkLimb.LeftArm,
            calibration, left, 0.5f, -10f, 150f, out cmd),
            "invalid joint limits rejected");
        Console.WriteLine("MAGICMIRROR_M4_M5_ATLAS_PLANNER_PASS: " +
                          assertions + " actual C# assertions; no imported FBX or Unity runtime.");
        return assertions;
    }
}

// Test the exact production C# camera projection and same-frame diagnostic
// sources used by Unity. The imported full FBX and a real camera are NOT here.
using System;
using System.Collections.Generic;
using MagicMirror.Motion;
using MagicMirror.Tracking;

internal static class ReprojectionChecks
{
    private static int assertions;
    private static KinematicVector3 P(float x, float y, float z)
    {
        return new KinematicVector3(x, y, z);
    }
    private static void Assert(bool condition, string name)
    {
        if (!condition)
            throw new InvalidOperationException("M5 reprojection: " + name);
        assertions++;
    }
    private static void Near(float actual, float expected, string name,
                             float epsilon = 0.0002f)
    {
        Assert(Math.Abs(actual - expected) <= epsilon,
               name + " expected " + expected + " got " + actual);
    }

    private static BodyWorldPinholeCamera Camera(
        bool reviewed = true, bool mirrored = false,
        KinematicVector3? forwardOverride = null, int width = 1280)
    {
        BodyWorldPinholeCamera c;
        Assert(BodyWorldPinholeCamera.TryCreate(
            reviewed, mirrored, width, 720,
            P(0f, 0f, -5f),
            P(1f, 0f, 0f),
            P(0f, 1f, 0f),
            forwardOverride ?? P(0f, 0f, 1f),
            0.5f, 0.5f, 0.5f, 0.5f, 0.01f, out c),
            "reviewed right-handed camera");
        return c;
    }
    private static BodySimilarityCalibration Calibration()
    {
        BodySimilarityCalibration t;
        Assert(BodySimilarityCalibration.TryCreate(
            P(-1f, 0f, 0f), P(1f, 0f, 0f), P(0f, -1f, 0f),
            P(5f, 8f, 2f), P(5f, 12f, 2f), P(7f, 10f, 2f),
            0.1f, 10f, 0.01f, out t),
            "reviewed body-to-atlas transform");
        return t;
    }
    private static PoseFrame Frame()
    {
        var frame = new PoseFrame
        {
            version = 1, width = 1280, height = 720,
            frameId = 12, timestampMs = 2500,
            mirrored = false, demo = false,
            landmarks = new PoseLandmark[33],
            worldLandmarks = new PoseLandmark[33]
        };
        for (int i = 0; i < 33; i++)
        {
            frame.landmarks[i] = new PoseLandmark
            {
                x = 0.5f, y = 0.5f, z = 0f,
                visibility = 0f, presence = 0f
            };
            frame.worldLandmarks[i] = new PoseLandmark();
        }
        return frame;
    }
    private static void Observed(PoseFrame frame, int id,
                                 float x, float y, float visibility = 1f)
    {
        frame.landmarks[id].x = x;
        frame.landmarks[id].y = y;
        frame.landmarks[id].visibility = visibility;
        frame.landmarks[id].presence = visibility;
    }
    private static AtlasReprojectionAnchor Anchor(
        BodySimilarityCalibration t, PoseFrame frame,
        int index, KinematicVector3 bodyWorld, bool reviewed = true)
    {
        KinematicVector3 atlasLocal;
        Assert(t.TryPoseToAtlas(bodyWorld, out atlasLocal),
               "calibrated pose-world to atlas root local");
        return new AtlasReprojectionAnchor
        {
            landmarkIndex = index,
            predictedAtlasLocal = atlasLocal,
            anatomicallyReviewed = reviewed,
            sourceFrameId = frame.frameId,
            sourceTimestampMs = frame.timestampMs
        };
    }
    private static bool Evaluate(
        PoseFrame frame, BodySimilarityCalibration t,
        BodyWorldPinholeCamera camera,
        IList<AtlasReprojectionAnchor> anchors,
        int minimumVisible, out AtlasReprojectionReport result,
        float target = 0.03f)
    {
        return AtlasReprojectionDiagnostics.TryEvaluate(
            frame, t, camera, anchors, 0.5f, minimumVisible,
            target, out result);
    }

    public static int Run()
    {
        var camera = Camera();
        var t = Calibration();
        float x, y;
        Assert(camera.TryProjectSource(P(0f, 0f, 0f), out x, out y),
               "camera source center");
        Near(x, 0.5f, "center X");
        Near(y, 0.5f, "center Y");
        Assert(camera.TryProjectSource(P(1f, 0f, 0f), out x, out y),
               "camera positive X");
        Near(x, 0.6f, "source image X right");
        Assert(camera.TryProjectSource(P(0f, 1f, 0f), out x, out y),
               "camera positive Y");
        Near(y, 0.4f, "source image Y goes up");
        Assert(camera.TryProjectSource(P(0f, 0f, 5f), out x, out y),
               "more distant point projects");
        Near(x, 0.5f, "more distant point center");

        Assert(!camera.TryProjectSource(P(0f, 0f, -5f), out x, out y),
               "depth at optical center rejected");
        Assert(!camera.TryProjectSource(P(0f, 0f, -6f), out x, out y),
               "behind-camera point rejected");
        Assert(!camera.TryProjectSource(P(float.NaN, 0, 0), out x, out y),
               "nonfinite camera input rejected");

        float dx, dy;
        Assert(BodyWorldPinholeCamera.TrySourceToDisplay(
            0.2f, 0.7f, true, out dx, out dy), "display mirroring allowed");
        Near(dx, 0.8f, "display flip X only");
        Near(dy, 0.7f, "display Y remains");
        Assert(BodyWorldPinholeCamera.TrySourceToDisplay(
            dx, dy, true, out x, out y), "double display mirror");
        Near(x, 0.2f, "two flips are identity");
        Assert(!BodyWorldPinholeCamera.TrySourceToDisplay(
            float.NaN, 0f, true, out dx, out dy),
            "reject NaN display source");

        BodyWorldPinholeCamera rejected;
        Assert(!BodyWorldPinholeCamera.TryCreate(
            false, false, 1280, 720,
            P(0, 0, -5), P(1, 0, 0), P(0, 1, 0), P(0, 0, 1),
            0.5f, 0.5f, 0.5f, 0.5f, 0.01f, out rejected),
            "unreviewed extrinsics must be rejected");
        Assert(!BodyWorldPinholeCamera.TryCreate(
            true, true, 1280, 720,
            P(0, 0, -5), P(1, 0, 0), P(0, 1, 0), P(0, 0, 1),
            0.5f, 0.5f, 0.5f, 0.5f, 0.01f, out rejected),
            "pre-mirrored source must be rejected");
        Assert(!BodyWorldPinholeCamera.TryCreate(
            true, false, 1280, 720,
            P(0, 0, -5), P(1, 0, 0), P(0, 1, 0), P(0, 0, -1),
            0.5f, 0.5f, 0.5f, 0.5f, 0.01f, out rejected),
            "left-handed camera reflection must be rejected");
        Assert(!BodyWorldPinholeCamera.TryCreate(
            true, false, 1280, 720,
            P(0, 0, -5), P(1, 0, 0), P(0.1f, 1, 0), P(0, 0, 1),
            0.5f, 0.5f, 0.5f, 0.5f, 0.01f, out rejected),
            "nonorthogonal camera axes must be rejected");

        PoseFrame frame = Frame();
        // Camera is at (0,0,-5), focal normalized 0.5 for both axes.
        Observed(frame, 11, 0.4f, 0.5f);
        Observed(frame, 12, 0.6f, 0.5f);
        Observed(frame, 23, 0.48f, 0.6f);
        Observed(frame, 24, 0.52f, 0.6f);
        var anchors = new List<AtlasReprojectionAnchor>
        {
            Anchor(t, frame, 11, P(-1f, 0f, 0f)),
            Anchor(t, frame, 12, P(1f, 0f, 0f)),
            Anchor(t, frame, 23, P(-0.2f, -1f, 0f)),
            Anchor(t, frame, 24, P(0.2f, -1f, 0f))
        };

        AtlasReprojectionReport report;
        Assert(Evaluate(frame, t, camera, anchors, 4, out report),
               "real PoseFrame same-source registration score");
        Near(report.P90ErrorAsImageWidth, 0f, "perfect geometric baseline");
        Assert(report.MeetsNumericP90Target, "numeric threshold pass");
        Assert(!report.GroundTruthValidated,
               "never claim independently validated anatomy");
        Assert(report.VisibleAnchors == 4 &&
               report.InputAnchors == 4, "all reviewed points measured");
        Assert(report.SourceFrameId == frame.frameId &&
               report.SourceTimestampMs == frame.timestampMs,
               "metrics carry source frame identity");

        // Y difference 0.1 of image HEIGHT -> 72 source pixels, 72/1280.
        Observed(frame, 24, 0.52f, 0.7f);
        Assert(Evaluate(frame, t, camera, anchors, 4, out report),
               "source pixel aspect correction");
        Near(report.P90ErrorAsImageWidth, 0.05625f,
             "true pixel euclidean normalized by WIDTH");
        Assert(!report.MeetsNumericP90Target,
               "numeric target distinguishes a real source pixel error");
        Observed(frame, 24, 0.52f, 0.6f);

        frame.landmarks[24].visibility = 0f;
        Assert(!Evaluate(frame, t, camera, anchors, 4, out report),
               "strict minimum visible point threshold");
        Assert(Evaluate(frame, t, camera, anchors, 3, out report),
               "report partial but sufficient observed points");
        Assert(report.VisibleAnchors == 3 && report.SkippedLowConfidence == 1,
               "missing confidence never silently counted as measured");
        frame.landmarks[24].visibility = 1f;

        // One stale prediction invalidates entire report. Do not blend
        // coordinates that come from different JPEG/PoseFrame pairs.
        var stale = anchors[2];
        stale.sourceFrameId--;
        anchors[2] = stale;
        Assert(!Evaluate(frame, t, camera, anchors, 4, out report),
               "stale IK prediction refused");
        stale.sourceFrameId = frame.frameId;
        stale.sourceTimestampMs--;
        anchors[2] = stale;
        Assert(!Evaluate(frame, t, camera, anchors, 4, out report),
               "mismatched timestamp refused");
        stale.sourceTimestampMs = frame.timestampMs;
        anchors[2] = stale;

        var notReviewed = anchors[3];
        notReviewed.anatomicallyReviewed = false;
        anchors[3] = notReviewed;
        Assert(!Evaluate(frame, t, camera, anchors, 4, out report),
               "unreviewed anchor refused");
        notReviewed.anatomicallyReviewed = true;
        anchors[3] = notReviewed;

        var duplicate = anchors[3];
        duplicate.landmarkIndex = 23;
        anchors[3] = duplicate;
        Assert(!Evaluate(frame, t, camera, anchors, 4, out report),
               "duplicate point correspondence refused");
        anchors[3] = Anchor(t, frame, 24, P(0.2f, -1f, 0f));

        frame.width = 640;
        Assert(!Evaluate(frame, t, camera, anchors, 4, out report),
               "capture camera dimension mismatch refused");
        frame.width = 1280;
        frame.mirrored = true;
        Assert(!Evaluate(frame, t, camera, anchors, 4, out report),
               "mirrored source refused");
        frame.mirrored = false;
        frame.demo = true;
        Assert(!Evaluate(frame, t, camera, anchors, 4, out report),
               "demo frames are not real score evidence");
        frame.demo = false;

        var wrongPosition = anchors[2];
        wrongPosition.predictedAtlasLocal = P(0f, 0f, -1000f);
        anchors[2] = wrongPosition;
        Assert(!Evaluate(frame, t, camera, anchors, 4, out report),
               "point behind camera refused, not silently dropped");

        Console.WriteLine("MAGICMIRROR_M5_REPROJECTION_CSHARP_PASS: " +
                          assertions + " assertions (synthetic inputs; no camera/FBX).");
        return assertions;
    }
}

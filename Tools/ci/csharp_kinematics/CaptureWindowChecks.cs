// Compiles and executes real production ReferencePoseCaptureWindow.cs and
// actual PoseFrame v1 contract with synthetic samples. Not a webcam test.
using System;
using MagicMirror.Motion;
using MagicMirror.Tracking;

internal static class CaptureWindowChecks
{
    private static int assertions;
    private static KinematicVector3 P(float x, float y, float z)
    {
        return new KinematicVector3(x, y, z);
    }
    private static void Assert(bool condition, string label)
    {
        if (!condition)
            throw new InvalidOperationException("M5 capture window: " + label);
        assertions++;
    }
    private static void Near(float a, float b, string label)
    {
        Assert(Math.Abs(a - b) < 0.001f, label + " " + a + " versus " + b);
    }
    private static PoseLandmark L(float x, float y, float z, float conf = 1f)
    {
        return new PoseLandmark
        {
            x = x, y = y, z = z,
            visibility = conf, presence = conf
        };
    }
    private static PoseFrame Frame(long id, long timestamp, float jitter = 0f)
    {
        var f = new PoseFrame
        {
            version = 1, frameId = id, timestampMs = timestamp,
            width = 1280, height = 720, mirrored = false, demo = false,
            landmarks = new PoseLandmark[33],
            worldLandmarks = new PoseLandmark[33]
        };
        for (int i = 0; i < 33; i++)
        {
            f.landmarks[i] = L(0.5f, 0.5f, 0f);
            f.worldLandmarks[i] = L(0f, 0f, 0f);
        }
        f.worldLandmarks[11] = L(-1f + jitter, 0f, 0f);
        f.worldLandmarks[12] = L(1f + jitter, 0f, 0f);
        f.worldLandmarks[23] = L(-0.2f + jitter, -1f, 0f);
        f.worldLandmarks[24] = L(0.2f + jitter, -1f, 0f);
        return f;
    }
    private static bool Freeze(ReferencePoseCaptureWindow w,
                               bool reviewed,
                               out BodySimilarityCalibration calibration,
                               out PoseCaptureQuality quality)
    {
        return w.TryFreeze(reviewed,
            P(5f, 8f, 2f), P(5f, 12f, 2f), P(7f, 10f, 2f),
            0.1f, 10f, 0.1f, out calibration, out quality);
    }

    public static int Run()
    {
        var w = new ReferencePoseCaptureWindow(
            requiredFrames: 7, minimumConfidence: 0.6f,
            maximumDriftInShoulderWidths: 0.06f, maximumFrameGapMs: 200);
        Assert(w.RequiredFrames == 7 && w.AcceptedFrames == 0,
               "initial bounded window size");
        for (int i = 0; i < 7; i++)
        {
            float jitter = (i % 2 == 0) ? 0.002f : -0.002f;
            Assert(w.TryAdd(Frame(i, 1000 + i * 33, jitter)),
                   "accept stable and ordered reference samples");
        }
        Assert(w.AcceptedFrames == 7 && !w.RequiresReset,
               "all reference samples collected");
        BodySimilarityCalibration calibrated;
        PoseCaptureQuality quality;
        Assert(!Freeze(w, false, out calibrated, out quality),
               "unreviewed reference anchors cannot produce a calibration");
        Assert(!w.IsFrozen && !w.RequiresReset,
               "unreviewed metadata can be reviewed before freezing");
        Assert(Freeze(w, true, out calibrated, out quality),
               "stable seven-frame reference pose freezes");
        Assert(w.IsFrozen && calibrated.IsValid,
               "calibration frozen and usable");
        Near(calibrated.Scale, 2f, "reference shoulder scale");
        Assert(quality.AcceptedFrames == 7 &&
               quality.FirstFrameId == 0 && quality.LastFrameId == 6 &&
               quality.FirstTimestampMs == 1000 &&
               quality.LastTimestampMs == 1198,
               "source capture window frame identities preserved");
        Assert(quality.MaximumJointDriftInShoulderWidths < 0.004f,
               "stable jitter remains below threshold");
        Assert(!quality.IsSyntheticOrHardwareValidated,
               "synthetic CI sample never declared hardware validation");
        Assert(!w.TryAdd(Frame(7, 1231)),
               "cannot modify a frozen registration implicitly");
        Assert(!Freeze(w, true, out calibrated, out quality),
               "cannot recalibrate a frozen window implicitly");

        w.Reset();
        Assert(!w.IsFrozen && !w.RequiresReset &&
               w.AcceptedFrames == 0, "explicit reset reopens a fresh session");
        for (int i = 0; i < 7; i++)
        {
            float jitter = (i == 6) ? 0.10f : 0f;
            Assert(w.TryAdd(Frame(100 + i, 5000 + i * 33, jitter)),
                   "collect slight single-frame outlier");
        }
        Assert(Freeze(w, true, out calibrated, out quality),
               "robust median tolerates bounded single-frame outlier");
        Near(calibrated.Scale, 2f, "median scale unaffected by outlier");
        Assert(quality.MaximumJointDriftInShoulderWidths > 0.04f,
               "max drift includes outlier rather than silently trimming it");

        w.Reset();
        for (int i = 0; i < 7; i++)
        {
            float jitter = (i == 4) ? 0.40f : 0f;
            Assert(w.TryAdd(Frame(i, 1000 + i * 33, jitter)),
                   "collect a large irregular motion for final stability test");
        }
        Assert(!Freeze(w, true, out calibrated, out quality),
               "reject window containing one large joint movement");
        Assert(w.RequiresReset, "unstable capture requires explicit reset");
        Assert(!w.TryAdd(Frame(100, 6000)),
               "poisoned capture must not append a new session");

        w.Reset();
        Assert(w.TryAdd(Frame(0, 1000)), "start capture");
        Assert(!w.TryAdd(Frame(0, 1033)),
               "duplicate frame ID rejects sample");
        Assert(w.RequiresReset, "duplicate frame ID poisons capture");

        w.Reset();
        Assert(w.TryAdd(Frame(0, 1000)), "start capture again");
        Assert(!w.TryAdd(Frame(1, 1000)),
               "duplicate timestamp rejects sample");

        w.Reset();
        Assert(w.TryAdd(Frame(0, 1000)), "start capture before time gap");
        Assert(!w.TryAdd(Frame(1, 1400)),
               "unbounded source timestamp gap rejects capture");

        w.Reset();
        Assert(w.TryAdd(Frame(0, 1000)), "start before resolution shift");
        var dimensionShift = Frame(1, 1033);
        dimensionShift.width = 640;
        Assert(!w.TryAdd(dimensionShift),
               "source resolution changed mid calibration");

        w.Reset();
        var lowConfidence = Frame(0, 1000);
        lowConfidence.landmarks[23].visibility = 0.1f;
        Assert(!w.TryAdd(lowConfidence), "low confidence hip poisons capture");
        Assert(w.RequiresReset, "low confidence requires reset");

        w.Reset();
        var missingWorld = Frame(0, 1000);
        missingWorld.worldLandmarks = null;
        Assert(!w.TryAdd(missingWorld), "world landmark dropout poisons capture");

        w.Reset();
        var nonFinite = Frame(0, 1000);
        nonFinite.worldLandmarks[11].x = float.NaN;
        Assert(!w.TryAdd(nonFinite), "nonfinite world pose poisons capture");

        w.Reset();
        var mirrored = Frame(0, 1000);
        mirrored.mirrored = true;
        Assert(!w.TryAdd(mirrored),
               "mirrored source must not silently reflect body-world axes");

        w.Reset();
        var demo = Frame(0, 1000);
        demo.demo = true;
        Assert(!w.TryAdd(demo), "demo source never calibrates a real atlas");

        w.Reset();
        var sessionA = Frame(0, 1000);
        sessionA.streamSessionId = 11;
        Assert(w.TryAdd(sessionA), "accept first source TCP generation");
        var sessionB = Frame(1, 1033);
        sessionB.streamSessionId = 12;
        Assert(!w.TryAdd(sessionB), "reject changed TCP session identity");
        Assert(w.RequiresReset, "cross-session calibration poisons capture");

        w.Reset();
        for (int i = 0; i < 7; i++)
        {
            var sameSession = Frame(i, 1000 + i * 33);
            sameSession.streamSessionId = 25;
            Assert(w.TryAdd(sameSession), "same TCP session accepted");
        }
        Assert(Freeze(w, true, out calibrated, out quality),
               "same source session can be frozen");
        Assert(quality.StreamSessionId == 25,
               "quality preserves trusted source TCP generation");

        w.Reset();
        Assert(!Freeze(w, true, out calibrated, out quality),
               "cannot calibrate from zero or insufficient samples");

        bool settingsRejected = false;
        try { new ReferencePoseCaptureWindow(requiredFrames: 0); }
        catch (ArgumentOutOfRangeException) { settingsRejected = true; }
        Assert(settingsRejected, "invalid window size rejected");
        settingsRejected = false;
        try { new ReferencePoseCaptureWindow(maximumDriftInShoulderWidths: float.NaN); }
        catch (ArgumentOutOfRangeException) { settingsRejected = true; }
        Assert(settingsRejected, "invalid stability tolerance rejected");

        Console.WriteLine("MAGICMIRROR_M5_REFERENCE_WINDOW_PASS: " +
                          assertions + " executed pure C# assertions, no Unity/camera.");
        return assertions;
    }
}

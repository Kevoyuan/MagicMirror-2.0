// Executable tests for the EXACT pure C# BodySimilarityCalibration.cs that
// the Unity project imports. No duplicate math implementation.
using System;
using MagicMirror.Motion;

internal static class CalibrationChecks
{
    private static int assertions;

    private static KinematicVector3 P(float x, float y, float z)
    {
        return new KinematicVector3(x, y, z);
    }

    private static void Check(bool ok, string label)
    {
        if (!ok) throw new InvalidOperationException("M5 calibration: " + label);
        assertions++;
    }

    private static void Close(float actual, float expected, string label, float tol = 0.002f)
    {
        Check(Math.Abs(actual - expected) <= tol,
              label + ": wanted " + expected + " got " + actual);
    }

    private static void Close(KinematicVector3 actual,
                              KinematicVector3 expected, string label)
    {
        Close(actual.x, expected.x, label + " x");
        Close(actual.y, expected.y, label + " y");
        Close(actual.z, expected.z, label + " z");
    }

    private static BodySimilarityCalibration Calibrate(
        KinematicVector3 pL, KinematicVector3 pR, KinematicVector3 pH,
        KinematicVector3 aL, KinematicVector3 aR, KinematicVector3 aH,
        float residual = 0.01f, float minScale = 0.01f, float maxScale = 100f)
    {
        BodySimilarityCalibration transform;
        Check(BodySimilarityCalibration.TryCreate(
            pL, pR, pH, aL, aR, aH,
            minScale, maxScale, residual, out transform),
            "three reference points accepted");
        Check(transform.IsValid, "calibrated state present");
        Check(transform.PreservesHandedness, "no implicit reflection");
        return transform;
    }

    private static void Reject(
        KinematicVector3 pL, KinematicVector3 pR, KinematicVector3 pH,
        KinematicVector3 aL, KinematicVector3 aR, KinematicVector3 aH,
        float minScale, float maxScale, float maxResidual,
        string label)
    {
        BodySimilarityCalibration ignored;
        Check(!BodySimilarityCalibration.TryCreate(
                  pL, pR, pH, aL, aR, aH,
                  minScale, maxScale, maxResidual, out ignored), label);
    }

    public static int Run()
    {
        var poseLeft = P(-1, 0, 0);
        var poseRight = P(1, 0, 0);
        var poseHip = P(0, -1, 0);
        var atlasLeft = P(5, 8, 2);
        var atlasRight = P(5, 12, 2);
        var atlasHip = P(7, 10, 2);
        var t = Calibrate(
            poseLeft, poseRight, poseHip,
            atlasLeft, atlasRight, atlasHip);

        Close(t.Scale, 2f, "shoulder-width scale");
        Close(t.PelvisResidualInShoulderWidths, 0f, "pelvis fit");
        KinematicVector3 mapped;
        Check(t.TryPoseToAtlas(poseLeft, out mapped), "left shoulder maps");
        Close(mapped, atlasLeft, "left shoulder match");
        Check(t.TryPoseToAtlas(poseRight, out mapped), "right shoulder maps");
        Close(mapped, atlasRight, "right shoulder match");
        Check(t.TryPoseToAtlas(poseHip, out mapped), "mid hip maps");
        Close(mapped, atlasHip, "hip match");

        Check(t.TryPoseToAtlas(P(0.25f, -0.5f, 0.75f), out mapped),
              "out-of-plane point maps");
        Close(mapped, P(6f, 10.5f, 3.5f),
              "right-handed rotation/scale/translation in 3D");
        KinematicVector3 back;
        Check(t.TryAtlasToPose(mapped, out back), "inverse maps");
        Close(back, P(0.25f, -0.5f, 0.75f), "inverse exact");

        KinematicVector3 rotatedDirection;
        Check(t.TryPoseDirectionToAtlas(P(0f, -1f, 0f), out rotatedDirection),
              "direction maps");
        Close(rotatedDirection, P(2f, 0f, 0f),
              "rotation and scale of downward torso direction");

        var random = new Random(32425);
        for (int i = 0; i < 100; i++)
        {
            KinematicVector3 sample = P(
                (float)(random.NextDouble() * 2 - 1),
                (float)(random.NextDouble() * 2 - 1),
                (float)(random.NextDouble() * 2 - 1));
            Check(t.TryPoseToAtlas(sample, out mapped), "random forward");
            Check(t.TryAtlasToPose(mapped, out back), "random reverse");
            Close(back, sample, "round-trip random " + i);
        }

        var identity = Calibrate(
            poseLeft, poseRight, poseHip,
            poseLeft, poseRight, poseHip);
        Close(identity.Scale, 1f, "identity scale");
        Check(identity.TryPoseToAtlas(P(3, 4, 5), out mapped),
              "identity mapping accepted");
        Close(mapped, P(3, 4, 5), "identity mapping unchanged");

        // Translation affects positions, NOT directions.
        var translated = Calibrate(
            poseLeft, poseRight, poseHip,
            P(10, -1, 3), P(12, -1, 3), P(11, -2, 3));
        Check(translated.TryPoseDirectionToAtlas(P(2, -1, 4), out mapped),
              "translated direction accepted");
        Close(mapped, P(2, -1, 4), "translation omitted in direction");

        // A mismatch in torso-to-shoulder proportions must not quietly
        // masquerade as valid uniform registration.
        Reject(poseLeft, poseRight, poseHip,
               atlasLeft, atlasRight, P(10, 10, 2),
               0.01f, 100f, 0.5f, "pelvis residual gate");
        var tolerated = Calibrate(
            poseLeft, poseRight, poseHip,
            atlasLeft, atlasRight, P(10, 10, 2),
            1f);
        Check(tolerated.PelvisResidualInShoulderWidths > 0.5f,
              "residual is reported honestly");

        Reject(poseLeft, poseRight, poseHip,
               atlasLeft, atlasRight, atlasHip,
               3f, 10f, 0.01f, "too small scale rejected");
        Reject(poseLeft, poseRight, poseHip,
               atlasLeft, atlasRight, atlasHip,
               0.01f, 1f, 0.01f, "too large scale rejected");
        Reject(poseLeft, poseRight, poseHip,
               atlasLeft, atlasRight, atlasHip,
               0f, 3f, 0.01f, "invalid min scale rejected");
        Reject(poseLeft, poseRight, poseHip,
               atlasLeft, atlasRight, atlasHip,
               2f, 1f, 0.01f, "inverted scale window");
        Reject(poseLeft, poseRight, poseHip,
               atlasLeft, atlasRight, atlasHip,
               0.01f, 100f, float.NaN, "NaN residual limit");
        Reject(poseLeft, poseRight, poseHip,
               atlasLeft, atlasRight, atlasHip,
               0.01f, 100f, -1f, "negative residual limit");
        Reject(poseLeft, poseLeft, poseHip,
               atlasLeft, atlasRight, atlasHip,
               0.01f, 100f, 0.01f, "coincident shoulders");
        Reject(poseLeft, poseRight, P(0, 0, 0),
               atlasLeft, atlasRight, atlasHip,
               0.01f, 100f, 0.01f, "hip at shoulder midpoint");
        Reject(poseLeft, poseRight, P(0.2f, 0, 0),
               atlasLeft, atlasRight, atlasHip,
               0.01f, 100f, 0.01f, "hip collinear with shoulder axis");
        Reject(P(float.PositiveInfinity, 0, 0), poseRight, poseHip,
               atlasLeft, atlasRight, atlasHip,
               0.01f, 100f, 0.01f, "non-finite pose reference");
        Reject(poseLeft, poseRight, poseHip,
               atlasLeft, P(float.NaN, 12, 2), atlasHip,
               0.01f, 100f, 0.01f, "non-finite atlas reference");

        BodySimilarityCalibration empty = default(BodySimilarityCalibration);
        Check(!empty.TryPoseToAtlas(P(1, 2, 3), out mapped),
              "uninitialized calibration cannot move geometry");
        Check(!t.TryPoseToAtlas(P(float.NaN, 2, 3), out mapped),
              "NaN input rejected");
        Check(!t.TryAtlasToPose(P(float.PositiveInfinity, 2, 3), out mapped),
              "infinite inverse input rejected");
        Check(!t.TryPoseDirectionToAtlas(P(1, float.NaN, 2), out mapped),
              "NaN direction rejected");

        Console.WriteLine("MAGICMIRROR_M5_CALIBRATION_CSHARP_PASS: " +
                          assertions + " actual pure-C# assertions, no Unity/FBX.");
        return assertions;
    }
}

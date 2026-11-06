// This executable compiles and TESTS the exact C# source imported by Unity.
// Zero external test libraries; no Unity installation, network, FBX, or camera.
using System;
using MagicMirror.Motion;

internal static class Program
{
    private const float Eps = 0.002f;
    private static int checks = 0;

    private static void Assert(bool condition, string label)
    {
        if (!condition) throw new InvalidOperationException("IK check failed: " + label);
        checks++;
    }

    private static void Near(float actual, float expected, string label, float tol = Eps)
    {
        Assert(Math.Abs(actual - expected) < tol,
            label + " expected " + expected + ", got " + actual);
    }

    private static KinematicVector3 P(float x, float y, float z)
    {
        return new KinematicVector3(x, y, z);
    }

    private static float Distance(KinematicVector3 a, KinematicVector3 b)
    {
        return (a - b).Magnitude;
    }

    private static TwoBoneSolution Solve(
        KinematicVector3 proximal, KinematicVector3 distal, KinematicVector3 pole,
        float upper = 1f, float lower = 1f,
        float minFlex = 0f, float maxFlex = 150f)
    {
        TwoBoneSolution solution;
        bool ok = TwoBoneKinematics.TrySolve(
            proximal, distal, pole, upper, lower, minFlex, maxFlex, out solution);
        Assert(ok, "two-link solver accepted a well-defined input");
        Near(Distance(solution.proximal, solution.elbowOrKnee),
             upper, "unchanged upper rigid reference length");
        Near(Distance(solution.elbowOrKnee, solution.distal),
             lower, "unchanged lower rigid reference length");
        Assert(solution.flexionDegrees >= minFlex - Eps &&
               solution.flexionDegrees <= maxFlex + Eps,
               "flexion within hinge limits");
        return solution;
    }

    private static void Rejected(
        KinematicVector3 proximal, KinematicVector3 distal, KinematicVector3 pole,
        float upper, float lower, float minFlex, float maxFlex,
        string reason)
    {
        TwoBoneSolution ignored;
        Assert(!TwoBoneKinematics.TrySolve(
            proximal, distal, pole, upper, lower, minFlex, maxFlex, out ignored), reason);
    }

    private static void Main()
    {
        // Fully extended limb: first and second rigid lengths exactly 1.
        TwoBoneSolution straight = Solve(P(0, 0, 0), P(2, 0, 0), P(0, 1, 0));
        Near(straight.flexionDegrees, 0f, "straight = zero flexion");
        Near(straight.elbowOrKnee.x, 1f, "straight joint center");
        Assert(!straight.targetDistanceClamped, "no clamp inside reachable range");

        // Law of cosines: distance 1 for two unit links = 120-degree bend.
        TwoBoneSolution bend = Solve(P(0, 0, 0), P(1, 0, 0), P(0, 1, 0));
        Near(bend.flexionDegrees, 120f, "120-degree elbow bend");
        Near(bend.elbowOrKnee.x, 0.5f, "bend plane length projection");
        Near(bend.elbowOrKnee.y, (float)Math.Sqrt(0.75), "elbow plane height");
        Assert(!bend.targetDistanceClamped, "unclamped reachable bend");

        TwoBoneSolution mirror = Solve(P(0, 0, 0), P(1, 0, 0), P(0, -1, 0));
        Near(mirror.elbowOrKnee.y, -bend.elbowOrKnee.y, "pole side reversal");

        // Preserve the entire 3D plane: pole can point along positive Z.
        TwoBoneSolution tilted = Solve(P(0, 0, 0), P(1, 0, 0), P(0, 0, 1));
        Near(tilted.elbowOrKnee.z, bend.elbowOrKnee.y, "3D pole orientation");
        Near(tilted.elbowOrKnee.y, 0f, "no invented Y bend");

        // An unreachable wrist is brought into the anatomically allowed arc.
        TwoBoneSolution far = Solve(P(0, 0, 0), P(3, 0, 0), P(0, 1, 0),
            1f, 1f, 10f, 150f);
        Assert(far.targetDistanceClamped, "reject impossible reach by correction");
        Near(far.flexionDegrees, 10f, "clamp to minimum flexion");
        Assert(Distance(far.proximal, far.distal) < 2f, "max extension limited");

        TwoBoneSolution near = Solve(P(0, 0, 0), P(0.1f, 0, 0), P(0, 1, 0),
            1f, 1f, 10f, 150f);
        Assert(near.targetDistanceClamped, "clamp impossible hyperflexion");
        Near(near.flexionDegrees, 150f, "max flexion limit");

        TwoBoneSolution translated = Solve(
            P(12, -7, 2), P(14, -7, 2), P(12, -4, 5),
            1.5f, 1.2f, 5f, 155f);
        Near(translated.proximal.x, 12f, "translated source root");
        Assert(translated.elbowOrKnee.z > 2f, "3D oblique pole");

        Rejected(P(0, 0, 0), P(0, 0, 0), P(0, 1, 0),
            1, 1, 0, 150, "unknown distal direction");
        Rejected(P(0, 0, 0), P(1, 0, 0), P(3, 0, 0),
            1, 1, 0, 150, "collinear bend pole");
        Rejected(P(0, 0, 0), P(1, 0, 0), P(0, 1, 0),
            0, 1, 0, 150, "zero reference length");
        Rejected(P(0, 0, 0), P(1, 0, 0), P(0, 1, 0),
            1, 1, 160, 30, "inverted hinge range");
        Rejected(P(0, 0, 0), P(1, 0, 0), P(0, 1, 0),
            1, 1, 0, 180, "disallowed singular 180-degree bend");
        Rejected(P(float.NaN, 0, 0), P(1, 0, 0), P(0, 1, 0),
            1, 1, 0, 150, "non-finite landmark");
        Rejected(P(0, 0, 0), P(1, 0, 0), P(0, 1, 0),
            float.PositiveInfinity, 1, 0, 150, "non-finite reference length");
        Rejected(P(0, 0, 0), P(1, 0, 0), P(0, 1, 0),
            1, 1, -3, 150, "invalid negative flexion");

        Console.WriteLine("MAGICMIRROR_M4_TWO_BONE_CSHARP_PASS: " + checks +
            " engine-independent assertions (NOT Unity/FBX validation).");
        CalibrationChecks.Run();
        BodyBridgeChecks.Run();
        ReprojectionChecks.Run();
    }
}

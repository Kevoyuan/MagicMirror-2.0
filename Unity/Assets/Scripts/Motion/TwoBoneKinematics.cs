// Pure C# mathematical kernel: no UnityEngine dependency.
// This file is compiled BOTH by Unity 6.3 and by dotnet CI smoke tests.
// The solver works in an arbitrary CONSISTENT 3D coordinate frame; it does
// NOT transform MediaPipe world landmarks into Unity or identify real bones.
using System;

namespace MagicMirror.Motion
{
    /// <summary>Lightweight engine-independent 3D vector for testable IK math.</summary>
    public struct KinematicVector3
    {
        public readonly float x;
        public readonly float y;
        public readonly float z;

        public KinematicVector3(float x, float y, float z)
        {
            this.x = x;
            this.y = y;
            this.z = z;
        }

        public static KinematicVector3 Zero
        {
            get { return new KinematicVector3(0f, 0f, 0f); }
        }

        public static KinematicVector3 operator +(KinematicVector3 a, KinematicVector3 b)
        {
            return new KinematicVector3(a.x + b.x, a.y + b.y, a.z + b.z);
        }
        public static KinematicVector3 operator -(KinematicVector3 a, KinematicVector3 b)
        {
            return new KinematicVector3(a.x - b.x, a.y - b.y, a.z - b.z);
        }
        public static KinematicVector3 operator *(KinematicVector3 a, float scale)
        {
            return new KinematicVector3(a.x * scale, a.y * scale, a.z * scale);
        }

        public static float Dot(KinematicVector3 a, KinematicVector3 b)
        {
            return a.x * b.x + a.y * b.y + a.z * b.z;
        }
        public float SqrMagnitude { get { return Dot(this, this); } }
        public float Magnitude { get { return (float)Math.Sqrt(SqrMagnitude); } }

        public static bool IsFinite(KinematicVector3 p)
        {
            return !float.IsNaN(p.x) && !float.IsInfinity(p.x) &&
                   !float.IsNaN(p.y) && !float.IsInfinity(p.y) &&
                   !float.IsNaN(p.z) && !float.IsInfinity(p.z);
        }
    }

    /// <summary>Two rigid segment endpoints, a hinge center and applied flexion.</summary>
    public struct TwoBoneSolution
    {
        public KinematicVector3 proximal;
        public KinematicVector3 elbowOrKnee;
        public KinematicVector3 distal;
        public float flexionDegrees;
        public bool targetDistanceClamped;
    }

    /// <summary>
    /// Two-link IK geometry with fixed lengths and a conservative flexion range.
    /// Pole is an OBSERVED/REVIEWED bend-plane hint, not a measured twist axis.
    /// This does not do skinning, true joint tracking, rotation about the limb
    /// axis, pelvis/head motion, or 3D camera registration.
    ///
    /// For a straight arm, flexion = 0 degrees; larger flexion means more
    /// bending. Unrealizable wrist/ankle targets are clamped to the closest
    /// reachable distance along their measured target direction.
    ///
    /// If the pole is collinear with the target axis or the target direction
    /// is undefined, we explicitly fail; inventing a bend plane can flip a
    /// limb when occluded.
    /// </summary>
    public static class TwoBoneKinematics
    {
        private const float Epsilon = 1e-6f;
        private const float DegreesToRadians = (float)(Math.PI / 180.0);
        private const float RadiansToDegrees = (float)(180.0 / Math.PI);

        public static bool TrySolve(
            KinematicVector3 proximal,
            KinematicVector3 observedDistal,
            KinematicVector3 bendPole,
            float firstLength,
            float secondLength,
            float minFlexionDegrees,
            float maxFlexionDegrees,
            out TwoBoneSolution solution)
        {
            solution = default(TwoBoneSolution);
            if (!KinematicVector3.IsFinite(proximal) ||
                !KinematicVector3.IsFinite(observedDistal) ||
                !KinematicVector3.IsFinite(bendPole) ||
                !FinitePositive(firstLength) || !FinitePositive(secondLength) ||
                !Finite(minFlexionDegrees) || !Finite(maxFlexionDegrees) ||
                minFlexionDegrees < 0f || maxFlexionDegrees > 175f ||
                minFlexionDegrees > maxFlexionDegrees)
                return false;

            KinematicVector3 targetDelta = observedDistal - proximal;
            float targetDistance = targetDelta.Magnitude;
            if (!Finite(targetDistance) || targetDistance < Epsilon)
                return false;
            KinematicVector3 axis = targetDelta * (1f / targetDistance);

            // Remove the projection of the pole onto the target direction.
            // Its remaining component decides which of the two elbow/knee
            // solutions is allowed. Reject a degenerate bend plane.
            KinematicVector3 poleDelta = bendPole - proximal;
            KinematicVector3 poleSide = poleDelta -
                axis * KinematicVector3.Dot(poleDelta, axis);
            float poleMagnitude = poleSide.Magnitude;
            if (!Finite(poleMagnitude) || poleMagnitude < Epsilon)
                return false;
            KinematicVector3 poleDirection = poleSide * (1f / poleMagnitude);

            float a = firstLength;
            float b = secondLength;
            float minDistance = ReachForFlexion(a, b, maxFlexionDegrees);
            float maxDistance = ReachForFlexion(a, b, minFlexionDegrees);
            if (!Finite(minDistance) || !Finite(maxDistance) ||
                minDistance < Epsilon || maxDistance < minDistance)
                return false;

            float d = Math.Max(minDistance, Math.Min(maxDistance, targetDistance));
            float along = (a * a - b * b + d * d) / (2f * d);
            float squaredHeight = a * a - along * along;
            // Numerical roundoff at the fully straight limit can create a
            // tiny negative radicand; reject anything significantly invalid.
            if (!Finite(along) || !Finite(squaredHeight) ||
                squaredHeight < -1e-4f * Math.Max(1f, a * a))
                return false;
            float height = (float)Math.Sqrt(Math.Max(0f, squaredHeight));
            KinematicVector3 joint = proximal + axis * along +
                                     poleDirection * height;
            KinematicVector3 correctedDistal = proximal + axis * d;

            float cosFlexion = Clamp(
                (d * d - a * a - b * b) / (2f * a * b), -1f, 1f);
            float flexion = (float)Math.Acos(cosFlexion) * RadiansToDegrees;
            if (!KinematicVector3.IsFinite(joint) ||
                !KinematicVector3.IsFinite(correctedDistal) ||
                !Finite(flexion))
                return false;

            solution = new TwoBoneSolution
            {
                proximal = proximal,
                elbowOrKnee = joint,
                distal = correctedDistal,
                flexionDegrees = flexion,
                targetDistanceClamped = Math.Abs(d - targetDistance) > 1e-5f
            };
            return true;
        }

        private static float ReachForFlexion(float a, float b, float flexionDegrees)
        {
            return (float)Math.Sqrt(Math.Max(0f,
                (double)a * a + (double)b * b +
                2.0 * a * b * Math.Cos(flexionDegrees * DegreesToRadians)));
        }
        private static float Clamp(float v, float min, float max)
        {
            return Math.Max(min, Math.Min(max, v));
        }
        private static bool FinitePositive(float x) { return Finite(x) && x > Epsilon; }
        private static bool Finite(float x)
        {
            return !float.IsNaN(x) && !float.IsInfinity(x);
        }
    }
}

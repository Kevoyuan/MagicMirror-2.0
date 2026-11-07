using System;
using MagicMirror.Motion;
using MagicMirror.Tracking;
using UnityEditor;
using UnityEngine;

namespace MagicMirror.Editor
{
    /// <summary>
    /// Synthetic Unity Editor bridge checks (actual Editor execution pending).
    /// Pure IK geometry is compiled/tested independently in dotnet CI.
    /// No anatomical FBX or real camera is needed for this suite.
    /// </summary>
    public static class M4TwoBoneWorldSelfCheck
    {
        [MenuItem("MagicMirror/Validation/Constrained Two-Bone IK Check")]
        public static void Run()
        {
            var frame = new PoseFrame
            {
                version = 1,
                width = 1280,
                height = 720,
                frameId = 1,
                timestampMs = 1000,
                landmarks = new PoseLandmark[33],
                worldLandmarks = new PoseLandmark[33]
            };
            for (int i = 0; i < 33; i++)
            {
                frame.landmarks[i] = Point(0f, 0f, 0f);
                frame.worldLandmarks[i] = Point(0f, 0f, 0f);
            }
            SetWorld(frame, 11, 0f, 0f, 0f);
            SetWorld(frame, 13, 0.5f, 0.8f, 0f);
            SetWorld(frame, 15, 1f, 0f, 0f);
            SetWorld(frame, 12, 0f, 0f, 0f);
            SetWorld(frame, 14, 0.5f, -0.8f, 0f);
            SetWorld(frame, 16, 1f, 0f, 0f);
            foreach (int index in new[] { 11, 13, 15, 12, 14, 16 })
            {
                frame.landmarks[index].visibility = 1f;
                frame.landmarks[index].presence = 1f;
            }

            TwoBoneSolution left, right;
            Ensure(TwoBoneWorldPoseBridge.TrySolveEstimatedWorld(
                frame, TrackedTwoLinkLimb.LeftArm, 0.5f,
                1f, 1f, 0f, 150f, out left),
                "left arm should solve");
            Ensure(Math.Abs(left.flexionDegrees - 120f) < 0.01f,
                   "left elbow flexion");
            Ensure(TwoBoneWorldPoseBridge.TrySolveEstimatedWorld(
                frame, TrackedTwoLinkLimb.RightArm, 0.5f,
                1f, 1f, 0f, 150f, out right),
                "right arm should solve");
            Ensure(left.elbowOrKnee.y > 0f && right.elbowOrKnee.y < 0f,
                   "left/right elbow bend poles are distinct");

            frame.landmarks[13].visibility = 0f;
            Ensure(!TwoBoneWorldPoseBridge.TrySolveEstimatedWorld(
                frame, TrackedTwoLinkLimb.LeftArm, 0.5f,
                1f, 1f, 0f, 150f, out left),
                "occluded elbow rejected");
            frame.landmarks[13].visibility = 1f;

            frame.worldLandmarks[13].z = float.NaN;
            Ensure(!TwoBoneWorldPoseBridge.TrySolveEstimatedWorld(
                frame, TrackedTwoLinkLimb.LeftArm, 0.5f,
                1f, 1f, 0f, 150f, out left),
                "NaN world coordinate rejected");
            frame.worldLandmarks[13].z = 0f;

            SetWorld(frame, 13, 0.5f, 0f, 0f);
            Ensure(!TwoBoneWorldPoseBridge.TrySolveEstimatedWorld(
                frame, TrackedTwoLinkLimb.LeftArm, 0.5f,
                1f, 1f, 0f, 150f, out left),
                "undefined bend plane rejected");
            SetWorld(frame, 13, 0.5f, 0.8f, 0f);

            frame.worldLandmarks = null;
            Ensure(!TwoBoneWorldPoseBridge.TrySolveEstimatedWorld(
                frame, TrackedTwoLinkLimb.LeftArm, 0.5f,
                1f, 1f, 0f, 150f, out left),
                "missing estimated world landmarks rejected");
            Debug.Log("MAGICMIRROR_M4_WORLD_BRIDGE_PASS: " +
                      "synthetic bridge/limb safety gates passed; NOT anatomical validation.");
        }

        private static void SetWorld(PoseFrame frame, int i, float x, float y, float z)
        {
            frame.worldLandmarks[i].x = x;
            frame.worldLandmarks[i].y = y;
            frame.worldLandmarks[i].z = z;
        }

        private static PoseLandmark Point(float x, float y, float z)
        {
            return new PoseLandmark
            {
                x = x, y = y, z = z, visibility = 0f, presence = 0f
            };
        }

        private static void Ensure(bool valid, string name)
        {
            if (!valid)
                throw new InvalidOperationException("M4 IK world bridge: " + name);
        }
    }
}

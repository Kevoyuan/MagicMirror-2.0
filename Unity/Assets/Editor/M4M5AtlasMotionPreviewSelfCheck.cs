using System;
using MagicMirror.Motion;
using MagicMirror.Tracking;
using UnityEditor;
using UnityEngine;

namespace MagicMirror.Editor
{
    /// <summary>
    /// Author-time check of exact source 3D limb command planner in Unity.
    /// This does NOT import an FBX or animate a physical-camera scene.
    /// </summary>
    public static class M4M5AtlasMotionPreviewSelfCheck
    {
        [MenuItem("MagicMirror/Validation/3D Full Atlas Motion Planner Check")]
        public static void Run()
        {
            var frame = new PoseFrame
            {
                version = 1, frameId = 42, timestampMs = 1500,
                width = 1280, height = 720, mirrored = false,
                demo = false,
                landmarks = new PoseLandmark[33],
                worldLandmarks = new PoseLandmark[33]
            };
            for (int i = 0; i < 33; i++)
            {
                frame.landmarks[i] = Point(0.5f, 0.5f, 0f);
                frame.worldLandmarks[i] = Point(0f, 0f, 0f);
            }
            frame.worldLandmarks[11] = Point(-1f, 0f, 0f);
            frame.worldLandmarks[12] = Point(1f, 0f, 0f);
            frame.worldLandmarks[13] = Point(-0.5f, 0.8f, 0f);
            frame.worldLandmarks[15] = Point(0f, 0f, 0f);
            frame.worldLandmarks[23] = Point(-0.2f, -1f, 0f);
            frame.worldLandmarks[24] = Point(0.2f, -1f, 0f);

            BodySimilarityCalibration calibration;
            Ensure(BodySimilarityCalibration.TryCreate(
                K(-1f, 0f, 0f), K(1f, 0f, 0f), K(0f, -1f, 0f),
                K(5f, 8f, 2f), K(5f, 12f, 2f), K(7f, 10f, 2f),
                0.1f, 10f, 0.01f, out calibration),
                "synthetic 3D similarity registration");

            var anchors = new ReviewedAtlasTwoLinkChain
            {
                proximalAtlasLocal = K(5f, 8f, 2f),
                hingeAtlasLocal = K(5f, 10f, 2f),
                distalAtlasLocal = K(5f, 12f, 2f),
                upperRegionReviewed = true,
                lowerRegionReviewed = true
            };

            AtlasTwoLinkMotionCommand command;
            Ensure(AtlasTwoLinkMotionPlanner.TryPlan(
                frame, TrackedTwoLinkLimb.LeftArm, calibration, anchors,
                0.5f, 0f, 150f, out command),
                "compiled planner accepts fully reviewed left arm");
            Ensure(command.isValid && command.sourceFrameId == frame.frameId,
                   "plan carries same PoseFrame identity");
            Ensure(Math.Abs((command.upper.targetEndAtlasLocal -
                             command.lower.targetStartAtlasLocal).Magnitude) < 0.001f,
                   "IK elbow remains connected");

            frame.mirrored = true;
            Ensure(!AtlasTwoLinkMotionPlanner.TryPlan(
                frame, TrackedTwoLinkLimb.LeftArm, calibration, anchors,
                0.5f, 0f, 150f, out command),
                "unsupported source mirror cannot drive a reviewed atlas");
            frame.mirrored = false;

            anchors.lowerRegionReviewed = false;
            Ensure(!AtlasTwoLinkMotionPlanner.TryPlan(
                frame, TrackedTwoLinkLimb.LeftArm, calibration, anchors,
                0.5f, 0f, 150f, out command),
                "unreviewed distal group cannot drive anatomy");
            Debug.Log("MAGICMIRROR_M4_M5_ATLAS_MOTION_EDITOR_PASS: " +
                      "synthetic planner only; no real FBX/Unity camera motion validated.");
        }

        private static KinematicVector3 K(float x, float y, float z)
        {
            return new KinematicVector3(x, y, z);
        }

        private static PoseLandmark Point(float x, float y, float z)
        {
            return new PoseLandmark
            {
                x = x, y = y, z = z, visibility = 1f, presence = 1f
            };
        }

        private static void Ensure(bool valid, string message)
        {
            if (!valid)
                throw new InvalidOperationException(
                    "M4/M5 atlas preview check: " + message);
        }
    }
}

using System;
using MagicMirror.Motion;
using MagicMirror.Tracking;
using UnityEditor;
using UnityEngine;

namespace MagicMirror.Editor
{
    /// <summary>
    /// One-shot synthetic M5 coordinate validation in the actual Unity Editor.
    /// Source-only until the editor suite is executed on target hardware.
    /// No anatomical model assets, real camera or individualized bone claims.
    /// </summary>
    public static class M5BodyCalibrationSelfCheck
    {
        [MenuItem("MagicMirror/Validation/3D Body-to-Atlas Calibration Check")]
        public static void Run()
        {
            var frame = new PoseFrame
            {
                version = 1,
                frameId = 1,
                timestampMs = 1000,
                width = 1280,
                height = 720,
                demo = false,
                mirrored = false,
                landmarks = new PoseLandmark[33],
                worldLandmarks = new PoseLandmark[33]
            };
            for (int i = 0; i < 33; i++)
            {
                frame.landmarks[i] = Point(0.5f, 0.5f, 0f, 1f);
                frame.worldLandmarks[i] = Point(0f, 0f, 0f, 1f);
            }
            SetWorld(frame, 11, -1f, 0f, 0f);
            SetWorld(frame, 12, 1f, 0f, 0f);
            SetWorld(frame, 23, -0.2f, -1f, 0f);
            SetWorld(frame, 24, 0.2f, -1f, 0f);

            BodySimilarityCalibration calibrated;
            Ensure(Capture(frame, true, out calibrated),
                "reviewed reference pose can be calibrated");
            Ensure(Math.Abs(calibrated.Scale - 2f) < 0.001f,
                "shoulder-derived calibration scale");

            KinematicVector3 mapped;
            Ensure(calibrated.TryPoseToAtlas(
                new KinematicVector3(-1f, 0f, 0f), out mapped),
                "map left shoulder");
            Ensure(Math.Abs(mapped.x - 5f) < 0.001f &&
                   Math.Abs(mapped.y - 8f) < 0.001f &&
                   Math.Abs(mapped.z - 2f) < 0.001f,
                "atlas-local shoulder alignment");

            frame.mirrored = true;
            Ensure(!Capture(frame, true, out calibrated),
                "unsupported mirrored source is refused");
            frame.mirrored = false;
            frame.demo = true;
            Ensure(!Capture(frame, true, out calibrated),
                "synthetic producer is refused for real reference capture");
            frame.demo = false;
            Ensure(!Capture(frame, false, out calibrated),
                "unreviewed anatomy is refused");

            frame.worldLandmarks[24].z = float.NaN;
            Ensure(!Capture(frame, true, out calibrated),
                "non-finite hip pose refused");
            Debug.Log("MAGICMIRROR_M5_EDITOR_CALIBRATION_PASS: " +
                      "synthetic gates passed, real FBX/camera NOT validated.");
        }

        private static bool Capture(PoseFrame frame, bool reviewed,
                                    out BodySimilarityCalibration output)
        {
            return BodyWorldCalibrationBridge.TryCaptureReferencePose(
                frame, reviewed,
                new KinematicVector3(5f, 8f, 2f),
                new KinematicVector3(5f, 12f, 2f),
                new KinematicVector3(7f, 10f, 2f),
                0.5f, 0.1f, 10f, 0.1f, out output);
        }

        private static void SetWorld(PoseFrame frame, int id,
                                     float x, float y, float z)
        {
            frame.worldLandmarks[id] = Point(x, y, z, 1f);
        }

        private static PoseLandmark Point(float x, float y, float z, float confidence)
        {
            return new PoseLandmark
            {
                x = x, y = y, z = z,
                visibility = confidence, presence = confidence
            };
        }

        private static void Ensure(bool condition, string label)
        {
            if (!condition)
                throw new InvalidOperationException("M5 calibration: " + label);
        }
    }
}

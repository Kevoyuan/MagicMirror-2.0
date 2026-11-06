"""Deterministic source-quality benchmarks; pure stdlib, no ML or camera."""
import io
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from Tools.pose_sidecar.benchmark import (
    analyze_trace, generate_trace, read_jsonl, validate_record, write_jsonl
)
from Tools.pose_sidecar.demo import SCENARIOS


class PoseBenchmarkTests(unittest.TestCase):
    def test_all_synthetic_traces_are_repeatable(self):
        for scenario in SCENARIOS:
            with self.subTest(scenario=scenario):
                self.assertEqual(generate_trace(scenario), generate_trace(scenario))

    def test_synthetic_timestamps_and_frame_ids_are_monotonic(self):
        frames = generate_trace("walk", 30, 3)
        self.assertEqual(len(frames), 90)
        self.assertEqual([f["frameId"] for f in frames], list(range(90)))
        self.assertEqual(frames[0]["timestampMs"], 1000)
        report = analyze_trace(frames)
        self.assertEqual(report["corePoseVisibleRatio"], 1.0)
        self.assertEqual(report["missingCorePoseFrames"], 0)
        self.assertAlmostEqual(report["observedSourceFps"], 30.0, delta=0.1)
        self.assertGreater(report["adjacentVisibleShoulderDisplacementP95Normalized"], 0)

    def test_dropout_is_reported_without_fake_latency_claim(self):
        frames = generate_trace("dropout", 20, 6)
        result = analyze_trace(frames)
        self.assertEqual(result["frameCount"], 120)
        self.assertEqual(result["missingCorePoseFrames"], 4)
        self.assertEqual(result["longestMissingCorePoseRunFrames"], 4)
        self.assertEqual(result["approxMaxMissingCorePoseMs"], 200)
        self.assertEqual(result["corePoseVisibleFrames"], 116)
        self.assertEqual(result["corePoseVisibleRatio"], round(116 / 120, 6))
        self.assertIn("not detection accuracy", result["metricsScope"])

    def test_rejects_non_monotonic_and_duplicate_packets(self):
        frames = generate_trace("wave", 20, 2)
        frames[1]["frameId"] = frames[0]["frameId"]
        with self.assertRaisesRegex(ValueError, "frameId"):
            analyze_trace(frames)
        frames[1]["frameId"] = 1
        frames[1]["timestampMs"] = frames[0]["timestampMs"]
        with self.assertRaisesRegex(ValueError, "timestampMs"):
            analyze_trace(frames)

    def test_rejects_invalid_landmark_schema_and_values(self):
        frames = generate_trace("squat", 20, 1)
        frames[0]["landmarks"][11]["x"] = float("nan")
        with self.assertRaisesRegex(ValueError, "Landmark"):
            analyze_trace(frames)
        frames = generate_trace("wave", 20, 1)
        frames[0]["worldLandmarks"] = [{}]
        with self.assertRaisesRegex(ValueError, "landmark count"):
            analyze_trace(frames)

    def test_empty_landmarks_counted_missing(self):
        frames = generate_trace("wave", 20, 1)
        frames[3]["landmarks"] = []
        report = analyze_trace(frames)
        self.assertEqual(report["missingCorePoseFrames"], 1)

    def test_jsonl_roundtrip_lossless(self):
        records = generate_trace("walk", 20, 1)
        with TemporaryDirectory() as tmp:
            path = Path(tmp) / "pose-trace.jsonl"
            write_jsonl(records, path)
            self.assertEqual(read_jsonl(path), records)
            self.assertEqual(analyze_trace(read_jsonl(path)),
                             analyze_trace(records))

    def test_bounded_input_and_malformed_lines(self):
        with TemporaryDirectory() as tmp:
            path = Path(tmp) / "bad.jsonl"
            path.write_text('{"version":NaN}\n', encoding="utf-8")
            with self.assertRaises(ValueError):
                read_jsonl(path)
            path.write_text("{}\n" * 3, encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "safe frame count"):
                read_jsonl(path, max_frames=2)

    def test_single_frame_has_no_invented_fps(self):
        report = analyze_trace(generate_trace("wave", 20, 0.05))
        self.assertEqual(report["frameCount"], 1)
        self.assertIsNone(report["observedSourceFps"])
        self.assertIsNone(report["medianSourceFrameIntervalMs"])

    def test_bad_configuration(self):
        for fps, seconds in ((0, 3), (61, 3), (20, 0), (20, float("inf"))):
            with self.subTest(fps=fps, seconds=seconds), self.assertRaises(ValueError):
                generate_trace("wave", fps, seconds)
        with self.assertRaises(ValueError):
            analyze_trace([], 0.5)
        with self.assertRaises(ValueError):
            validate_record({"version": 42})


if __name__ == "__main__":
    unittest.main()

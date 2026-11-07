"""Reproducible, webcam-free pose TRACE generation and quality analysis.

This is NOT a MediaPipe speed benchmark: generated frames use known schematic
positions and no model inference, camera, Unity renderer, or display latency.
Use a recorded JSONL trace separately to inspect landmark availability and
source frame ordering. No patient/person data should be committed.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import statistics

from .demo import SCENARIOS, synthetic_landmarks
from .main import make_header
from .metrics import percentile

CORE_JOINTS = (11, 12, 23, 24)
SCHEMA_VERSION = 1


def generate_trace(scenario: str, fps: int = 20, seconds: float = 6.0):
    """Return deterministic PoseFrame-v1 headers for a schematic scenario."""
    if scenario not in SCENARIOS:
        raise ValueError("Unknown scenario")
    if not 1 <= fps <= 60 or not math.isfinite(seconds) or seconds <= 0:
        raise ValueError("Invalid fps or duration")
    frames = round(fps * seconds)
    if not 1 <= frames <= 20000:
        raise ValueError("Trace size must be between 1 and 20000 frames")
    return [
        make_header(
            frame_id=i, timestamp_ms=1000 + round(i * 1000 / fps),
            width=1280, height=720,
            landmarks=synthetic_landmarks(i / fps, scenario),
            world_landmarks=[], demo=True
        )
        for i in range(frames)
    ]


def write_jsonl(records: list[dict], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as output:
        for frame in records:
            output.write(json.dumps(frame, allow_nan=False, separators=(",", ":")) + "\n")


def read_jsonl(path: Path, max_frames: int = 20000) -> list[dict]:
    """Strict, bounded parser. Reject malformed lines instead of dropping them."""
    records = []
    with path.open("r", encoding="utf-8") as stream:
        for line_number, line in enumerate(stream, 1):
            if line_number > max_frames:
                raise ValueError("Trace exceeds safe frame count")
            try:
                value = json.loads(line, parse_constant=lambda _: (_ for _ in ()).throw(
                    ValueError("Non-finite JSON constant")))
            except (ValueError, json.JSONDecodeError) as error:
                raise ValueError(f"Invalid JSON at line {line_number}: {error}") from error
            if not isinstance(value, dict):
                raise ValueError(f"Expected an object at line {line_number}")
            records.append(value)
    if not records:
        raise ValueError("Trace is empty")
    return records


def _visible_point(point: dict, threshold: float):
    return (isinstance(point, dict)
            and all(isinstance(point.get(k), (int, float))
                    and not isinstance(point[k], bool)
                    and math.isfinite(point[k]) for k in
                    ("x", "y", "z", "visibility", "presence"))
            and point["visibility"] >= threshold
            and point["presence"] >= threshold)


def validate_record(frame: dict, prev: dict | None = None) -> None:
    if not isinstance(frame, dict) or frame.get("version") != SCHEMA_VERSION:
        raise ValueError("Unsupported PoseFrame schema/version")
    for name in ("frameId", "timestampMs", "width", "height"):
        if type(frame.get(name)) is not int or frame[name] < 0:
            raise ValueError(f"Invalid {name}")
    if not 0 < frame["width"] <= 8192 or not 0 < frame["height"] <= 8192:
        raise ValueError("Invalid frame dimensions")
    if type(frame.get("mirrored")) is not bool or type(frame.get("demo")) is not bool:
        raise ValueError("Invalid frame flags")
    points = frame.get("landmarks")
    world = frame.get("worldLandmarks", [])
    if (not isinstance(points, list) or len(points) not in (0, 33)
            or not isinstance(world, list) or len(world) not in (0, 33)):
        raise ValueError("Invalid landmark count")
    for point in points + world:
        if not _visible_point(point, 0.0):
            raise ValueError("Landmark contains non-finite or missing fields")
        if not 0.0 <= point["visibility"] <= 1.0 or not 0.0 <= point["presence"] <= 1.0:
            raise ValueError("Invalid visibility or presence")
    if prev is not None:
        if frame["frameId"] <= prev["frameId"]:
            raise ValueError("Duplicate/backwards frameId")
        if frame["timestampMs"] <= prev["timestampMs"]:
            raise ValueError("Duplicate/backwards timestampMs")


def analyze_trace(records: list[dict], confidence: float = 0.5) -> dict:
    """Compute source observation health, not pose accuracy or screen latency.

    Timing is measured from source timestamps. Dropouts count samples where
    all four core shoulder/hip landmarks are not confidently visible.
    Max dropout duration approximates consecutive missing sample count times
    the median sample period; it does not measure a Unity render timeout.
    """
    if not records or not 0 <= confidence <= 1:
        raise ValueError("Trace and confidence must be valid")
    prev = None
    visible_count = 0
    run = longest_run = 0
    sample_periods = []
    adjacent_shoulder_movement = []
    last_visible_shoulders = None
    for frame in records:
        validate_record(frame, prev)
        if prev is not None:
            sample_periods.append(frame["timestampMs"] - prev["timestampMs"])
        points = frame["landmarks"]
        visible = (len(points) == 33 and
                   all(_visible_point(points[i], confidence) for i in CORE_JOINTS))
        if visible:
            visible_count += 1
            run = 0
            current = ((points[11]["x"], points[11]["y"]),
                       (points[12]["x"], points[12]["y"]))
            if last_visible_shoulders is not None:
                adjacent_shoulder_movement.append(
                    max(math.dist(current[j], last_visible_shoulders[j])
                        for j in (0, 1)))
            last_visible_shoulders = current
        else:
            run += 1
            longest_run = max(longest_run, run)
            last_visible_shoulders = None
        prev = frame

    median_period = statistics.median(sample_periods) if sample_periods else None
    result = {
        "protocolVersion": SCHEMA_VERSION,
        "frameCount": len(records),
        "startFrameId": records[0]["frameId"],
        "endFrameId": records[-1]["frameId"],
        "coreJoints": list(CORE_JOINTS),
        "confidenceThreshold": confidence,
        "corePoseVisibleFrames": visible_count,
        "corePoseVisibleRatio": round(visible_count / len(records), 6),
        "missingCorePoseFrames": len(records) - visible_count,
        "longestMissingCorePoseRunFrames": longest_run,
        "medianSourceFrameIntervalMs": median_period,
        "approxMaxMissingCorePoseMs": (
            round(longest_run * median_period, 3) if median_period is not None else None),
        "adjacentVisibleShoulderDisplacementP95Normalized": (
            round(percentile(adjacent_shoulder_movement, 0.95), 6)
            if adjacent_shoulder_movement else None),
        "observedSourceFps": (
            round(1000 / (sum(sample_periods) / len(sample_periods)), 3)
            if sample_periods else None),
        "metricsScope": (
            "Source PoseFrame sequence and landmark availability ONLY; "
            "not detection accuracy, joint-position error, real-camera "
            "inference throughput, end-to-end latency, or medical measurement."
        ),
    }
    return result


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="MagicMirror deterministic pose-trace quality checks")
    choice = p.add_mutually_exclusive_group(required=True)
    choice.add_argument("--scenario", choices=SCENARIOS,
                        help="Generate fixed synthetic PoseFrame v1 sequence")
    choice.add_argument("--input", type=Path,
                        help="Inspect a previously recorded local JSONL frame trace")
    p.add_argument("--fps", type=int, default=20)
    p.add_argument("--seconds", type=float, default=6.0)
    p.add_argument("--confidence", type=float, default=0.5)
    p.add_argument("--write-trace", type=Path, default=None,
                   help="Write synthetic JSONL (never run on raw user recordings in CI)")
    p.add_argument("--report", type=Path, default=None)
    args = p.parse_args(argv)
    try:
        if args.input and args.write_trace:
            p.error("--write-trace is only for synthetic scenarios")
        frames = (generate_trace(args.scenario, args.fps, args.seconds)
                  if args.scenario else read_jsonl(args.input))
        report = analyze_trace(frames, args.confidence)
        report["traceSource"] = "synthetic" if args.scenario else "external-jsonl"
        if args.scenario:
            report["scenario"] = args.scenario
            if args.write_trace is not None:
                write_jsonl(frames, args.write_trace)
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(report, indent=2))
        return 0
    except (OSError, ValueError, OverflowError) as error:
        p.error(str(error))


if __name__ == "__main__":
    raise SystemExit(main())

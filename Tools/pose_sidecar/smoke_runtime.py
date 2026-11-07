"""Real MediaPipe Tasks VIDEO runtime smoke check, without a webcam or Unity.

This does execute the downloaded Lite/Full/Heavy Pose Landmarker model, but
the synthetic black image is NOT a human detection accuracy benchmark.
GitHub CI downloads model bytes temporarily and never commits or uploads them.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import pathlib
import time

from .download_model import model_path
from .metrics import percentile


def verify_video_runtime(model_file: pathlib.Path, frames: int = 3) -> dict:
    if not model_file.is_file():
        raise FileNotFoundError(
            f"Missing Pose Landmarker model {model_file}. "
            "Use python -m Tools.pose_sidecar.download_model --profile lite")
    if not 1 <= frames <= 100:
        raise ValueError("frames must be between 1 and 100")

    # Lazy imports: all other unit tests and --demo need only stdlib.
    import numpy as np
    import mediapipe as mp

    payload = model_file.read_bytes()
    digest = hashlib.sha256(payload).hexdigest()
    image_data = np.zeros((256, 256, 3), dtype=np.uint8)
    image_data[:, :, :] = (32, 32, 32)
    image = mp.Image(image_format=mp.ImageFormat.SRGB, data=image_data)
    options = mp.tasks.vision.PoseLandmarkerOptions(
        base_options=mp.tasks.BaseOptions(model_asset_path=str(model_file)),
        running_mode=mp.tasks.vision.RunningMode.VIDEO,
        num_poses=1,
        min_pose_detection_confidence=0.5,
        min_pose_presence_confidence=0.5,
        min_tracking_confidence=0.5,
    )

    inference_ms = []
    pose_counts = []
    with mp.tasks.vision.PoseLandmarker.create_from_options(options) as detector:
        for i in range(frames):
            # The VIDEO-mode API requires monotonic timestamps. These are
            # synthetic input times, not physical camera timestamps.
            start = time.perf_counter()
            result = detector.detect_for_video(image, 1000 + i * 33)
            inference_ms.append((time.perf_counter() - start) * 1000)
            poses = result.pose_landmarks or []
            world = result.pose_world_landmarks or []
            if len(poses) > 1:
                raise AssertionError("Expected no more than one pose")
            for person in poses:
                if len(person) != 33:
                    raise AssertionError("MediaPipe result was not 33 landmarks")
            for person in world:
                if len(person) != 33:
                    raise AssertionError("MediaPipe world result was not 33 landmarks")
            if len(world) != len(poses):
                raise AssertionError("Pose/world result counts disagree")
            pose_counts.append(len(poses))

    # NOTE: benchmark timings from blank synthetic frames on CI are not
    # representative of human input or end-to-end display performance.
    return {
        "mode": "VIDEO",
        "input": "blank-synthetic-256x256",
        "frames": frames,
        "landmarkSchema": 33,
        "mediapipeVersion": importlib.metadata.version("mediapipe"),
        "numpyVersion": np.__version__,
        "modelFileName": model_file.name,
        "modelSizeBytes": len(payload),
        "modelSha256": digest,
        "posesPerFrame": pose_counts,
        "syntheticModelCallMeanMs": round(sum(inference_ms) / frames, 3),
        "syntheticModelCallP95Ms": round(percentile(inference_ms, 0.95), 3),
        "notMeasured": [
            "real-person accuracy",
            "camera FPS",
            "pose jitter",
            "camera-to-display latency",
            "Unity AR",
            "anatomical alignment",
        ],
    }


def main(argv=None) -> int:
    p = argparse.ArgumentParser(
        description="Smoke-check a REAL MediaPipe Pose Landmarker in VIDEO mode")
    p.add_argument("--profile", choices=("lite", "full", "heavy"), default="lite")
    p.add_argument("--model", type=pathlib.Path, help="Override local model path")
    p.add_argument("--frames", type=int, default=3)
    p.add_argument("--report", type=pathlib.Path)
    args = p.parse_args(argv)
    result = verify_video_runtime(args.model or model_path(args.profile), args.frames)
    encoded = json.dumps(result, indent=2) + "\n"
    print(encoded)
    if args.report is not None:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(encoded, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

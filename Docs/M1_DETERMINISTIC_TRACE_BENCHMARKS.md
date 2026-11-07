# M1 — Deterministic pose trace benchmark and quality report

**Source-only engineering and CI regression tool.** This is deliberately
not a claim of real model accuracy, real camera throughput, or any measured
webcam-to-display latency.

## Purpose

The project must have repeatable scenario fixtures before comparing Lite,
Full and Heavy models or tuning the future anatomical rig. The M1 tool
generates a fixed, version-1 JSONL PoseFrame sequence from the standard
`wave`, `walk`, `squat`, and `dropout` schematic pose scenarios.

It also audits external JSONL traces *if the developer separately captures
them locally*. Each trace line contains a PoseFrame v1 JSON header, **not
JPEG data**; no personal recording is created by default.

## Offline reproducible scenario

~~~bash
python3 -m Tools.pose_sidecar.benchmark \
  --scenario dropout --fps 20 --seconds 6 \
  --write-trace /tmp/magicmirror-synthetic.jsonl \
  --report /tmp/magicmirror-quality.json

python3 -m Tools.pose_sidecar.benchmark \
  --input /tmp/magicmirror-synthetic.jsonl
~~~

For 20 FPS, six seconds and the deterministic 180 ms dropout window,
the generated sequence has 120 frames with **four sampled frames**
whose shoulder/hip pose is missing, and an approximately **200 ms**
missing-sample run. This is a property of the fixture and its chosen
sampling interval, NOT an observed real tracking dropout.

CI checks this exact expectation so changes to the fixture or analyzer
cannot silently alter the baseline.

## What is measured

- Version, frame count, monotonic frame IDs and source timestamps.
- Confidence-gated visibility of **both shoulders and both hips** (landmarks
  11, 12, 23, 24), `corePoseVisibleRatio` and missing-frame streaks.
- Source frame cadence from timestamp deltas; this is *not inference FPS*.
- Maximum adjacent visible shoulder displacement in normalized source image
  coordinates (p95), which includes **intentional movement** and cannot be
  interpreted as jitter or anatomical error.
- The approximate length of a missing run, derived from frame count and
  median source frame interval.

## What is NOT measured

This fixture does NOT run MediaPipe inference, a real webcam, JPEG encoding,
Unity decoding, full Z-Anatomy retargeting, 3D accuracy, or video display.
It cannot benchmark **per-model precision/recall**, inference latency,
total end-to-end latency, FPS under physical load, or actual bone placement.

The pre-existing `ProcessingStats` module reports processing-only
inference/JPEG timings when using a real MediaPipe camera run. Those values
cannot be converted into measured end-to-end latency by assuming Python and
Unity clocks are the same.

## Data safety

Do not commit real webcam frames, personal pose sequences or unreviewed
recordings to Git. Generated fixtures contain only code-defined landmarks.
If external real-person PoseFrame JSONL is used, keep it local, seek
appropriate consent, and delete it when no longer needed.

## Next gate

1. Lock a tested MediaPipe wheel and each model blob by checksum on
   representative Windows/macOS hardware.
2. Add anonymized, consented, independently labeled reference clips and
   evaluate model accuracy and tracking stability against ground truth.
3. Compare Lite / Full / Heavy processing time on the **same device**;
   report version, warm-up, frame count and environment.
4. Run the actual Unity 6.3 project on-device; measure real video/pose
   alignment and valid end-to-end latency.
5. Use the resulting pose-quality evidence to tune M4 kinematic constraints.

The M1 source tool is an **offline regression foundation**, not M1 completion.

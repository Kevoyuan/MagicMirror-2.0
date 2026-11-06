# MagicMirror 2.0 — Interactive Anatomical AR Mirror

**Make human anatomy visible, interactive, and understandable through natural body movement.**

A **MediaPipe-only**, local-first, single-person educational anatomy mirror.
A standard, complete Z-Anatomy skeleton will be registered over the user's
live webcam image, with future muscle, organ and guided-learning layers.

> **Source status:** The Phase 4B schematic full-body Unity code and the
> MediaPipe/Python pipeline are implemented, with Python/static CI checks.
> **Actual Unity Editor compilation, real webcam alignment, and real
> SkeletalSystem100.fbx motion are NOT yet verified.** This is a research
> prototype, not a clinical scanner or personalized anatomical reconstruction.

## M2 offline integration test

No local Unity installation is needed to test the real Python producer and
its loopback TCP framing. The test starts the sidecar **as a subprocess**,
receives multiple ordered PoseFrame v1 packets, disconnects and reconnects,
and verifies that a new connection starts its own frame sequence:

~~~bash
python3 -m unittest Tools.pose_sidecar.tests.test_sidecar_integration -v
~~~

If OpenCV/NumPy are installed, it also receives and validates actual JPEG
bytes from the `--demo-video` source. GitHub Actions performs both variants.
It does **not** prove that Unity compiled, that a real camera inferred a pose,
or that the Z-Anatomy model is aligned.

## First steps (without Unity or a webcam)

~~~bash
python3 -m unittest discover -s Tools/pose_sidecar/tests -v
python3 -m unittest discover -s Tools/anatomy_tools/tests -v
python3 -m unittest discover -s Tools/ci/tests -v
python3 Tools/ci/check_mediapipe_only.py
python3 -m Tools.pose_sidecar.main --demo --demo-scenario walk
~~~

Optional synthetic **JPEG + synchronized landmarks**, with no camera or
MediaPipe model required:

~~~bash
python3 -m pip install "opencv-python>=4.10,<5" "numpy>=1.26,<3"
python3 -m Tools.pose_sidecar.main --demo-video --demo-scenario wave
~~~

Open the **Unity/** directory (not this repo root) in the editor version
specified by Unity/ProjectSettings/ProjectVersion.txt. See
Docs/UNITY_RUNTIME_VALIDATION.md for the batch smoke test and live-camera
checklist. The Unity Editor and real anatomical asset are not included.

## Architecture

- Camera + MediaPipe Tasks Pose Landmarker: Tools/pose_sidecar/
- Timestamped same-frame PoseFrame v1 + JPEG over local TCP
- Unity 6.3 LTS: pose receiver, full-body atlas mapping, AR compositor, UI
- Complete pinned Z-Anatomy FBX, **not independent re-exported bones**
- Default local-only image processing and no recording/upload

## Documentation

- Docs/PRODUCT_VISION.md — final educational experience
- Docs/ARCHITECTURE.md — active runtime
- Docs/POSE_FRAME_CONTRACT.md — precise coordinates and timestamps
- Docs/ROADMAP.md — M0 through M9, implementation gates
- Docs/M1_MEDIAPIPE_PROFILES.md — Lite/Full/Heavy and performance metrics
- Docs/M2_FRAME_INTEGRITY_AND_DEMO_VIDEO.md — M2 synthetic video checks
- Docs/UNITY_RUNTIME_VALIDATION.md — actual Unity/hardware acceptance

## Scientific and licensing boundaries

The anatomy overlay is a **standard reference model** aligned by an estimated
pose. It cannot image someone's real bones or organs, and is not an X-ray,
CT, MRI or medical diagnostic tool. Camera processing defaults to local only.

Source anatomy models are NOT included. The complete Z-Anatomy skeletal FBX
requires its own source/license review before redistribution. See
Docs/ASSETS_AND_LICENSES.md and NOTICE.md.

**Code license:** deliberately not assumed or invented during migration.
The repository owner should choose and add an explicit LICENSE before calling
the new repository licensed open source.

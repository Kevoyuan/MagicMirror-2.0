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

The Lite model can also be smoke-tested **without a camera or Unity**:
~~~bash
python3 -m pip install -r Tools/pose_sidecar/requirements.txt
python3 -m Tools.pose_sidecar.download_model --profile lite
python3 -m Tools.pose_sidecar.download_model --profile lite --verify-only
python3 -m Tools.pose_sidecar.smoke_runtime --profile lite --frames 3
~~~
This executes real VIDEO inference on blank synthetic frames, not human
pose accuracy or camera-to-display latency. Linux CI also needs GLES/EGL
libraries; see Docs/M1_REAL_MEDIAPIPE_SMOKE.md.

The production **C# kinematics, body registration, stable reference capture
and camera reprojection math** can be compiled and tested without Unity,
camera or Z-Anatomy assets:
~~~bash
dotnet run -c Release --project Tools/ci/csharp_kinematics/KinematicsChecks.csproj
~~~
This tests original C# IK/pose-contract/registration/reprojection sources
with constructed inputs, **not** Unity rendering, anatomy accuracy, true
camera calibration or measured live-device performance.

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
- Docs/M1_MEDIAPIPE_PROFILES.md — Lite/Full/Heavy and processing metrics
- Docs/M1_REAL_MEDIAPIPE_SMOKE.md — Lite VIDEO baseline and Linux native dependencies
- Docs/M1_ALL_PROFILES_RUNTIME.md — real Lite/Full/Heavy VIDEO model identity and SHA-256 locks (Linux CI)
- Docs/M2_FRAME_INTEGRITY_AND_DEMO_VIDEO.md — M2 synthetic video checks
- Docs/M4_CONSTRAINED_TWO_BONE_IK.md — compiled pure C# constrained 3D joint solver and safety limits
- Docs/M5_BODY_ATLAS_REGISTRATION.md — reviewed 3D body-to-atlas reference calibration
- Docs/M5_STABLE_CAPTURE_AND_REPROJECTION.md — bounded reference capture, explicit camera projection and P90 diagnostics
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

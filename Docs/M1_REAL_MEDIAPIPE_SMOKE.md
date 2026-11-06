# M1 — Actual MediaPipe VIDEO runtime smoke and Lite model lock

**Validation date:** 2026-11-06. **Environment tested:** GitHub-hosted Ubuntu Linux,
Python 3.11 and MediaPipe `0.10.35`. Actual macOS/Windows camera integration,
Unity compilation and full reference-body motion remain untested.

## What was executed

Unlike the synthetic PoseFrame generator, this test **instantiates the actual
MediaPipe Tasks Pose Landmarker**, loads the upstream Lite model bundle and
calls `detect_for_video()` on three 256×256 RGB test images with increasing
timestamps. The images are deliberately a uniform background, **not human
examples**. The test validates package loading, native libraries, model
compatibility, VIDEO-mode callability and output schema without a webcam.

Run locally after installing dependencies:

~~~bash
python3 -m pip install -r Tools/pose_sidecar/requirements.txt
python3 -m Tools.pose_sidecar.download_model --profile lite
python3 -m Tools.pose_sidecar.download_model --profile lite --verify-only
python3 -m Tools.pose_sidecar.smoke_runtime --profile lite --frames 3
~~~

The Python test suite still runs without any downloaded model or
MediaPipe installation.

## Verified identities from the CI runtime

| Component | Tested value |
| --- | --- |
| Python runtime | 3.11 (Ubuntu GitHub runner) |
| `mediapipe` | **0.10.35** (pinned in requirements) |
| Model | Pose Landmarker **Lite**, float16 `.task` |
| Model size | **5,777,746 bytes** |
| Model SHA-256 | `59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a` |
| Tasks mode | **VIDEO**, one person maximum |
| Input | 3 synthetic blank 256×256 RGB images |
| Result | Successful real model load + VIDEO inference calls in Linux CI |

The model originates from the official MediaPipe model storage URL used by
`Tools/pose_sidecar/download_model.py`. That URL includes `latest`, so it
is **mutable**. The Lite downloader now refuses a changed file based on the
fixed size and SHA-256 lock, including when an existing local file is reused.
The test does not redistribute Google model binaries.

**Important:** Lite has a tested checksum, but **Full and Heavy still have
no binary SHA-256 locks and have not completed this real inference check**.
Do not claim all three profiles are reproducible yet.

## Linux runtime dependency discovered by the test

The first run failed with missing `libGLESv2.so.2`, despite the Python
package installing successfully. The GitHub Actions job now installs the
Linux GLES/EGL/OpenGL shared libraries before loading MediaPipe:

~~~bash
sudo apt-get install -y libgles2 libegl1 libgl1
~~~

This is a compatibility requirement observed in the GitHub Linux environment;
it does not establish equivalent Windows/macOS packaging requirements.

## Interpretation boundaries

- Success confirms **the tested package and actual Lite model can execute**.
- A few CPU inference timings on uniform images are **not real-human FPS,
  accuracy, motion stability, production latency or target-device benchmark**.
- A blank-image test cannot verify the left/right landmark convention,
  physical camera capture, human pose detection quality, occlusion recovery,
  segmentation, Z-Anatomy mapping, or AR alignment.
- Unity Editor has not compiled or run in this test.
- The local model file is gitignored; license/source attribution and
  redistribution review remain release gates.

## Next acceptance gates

1. Run real camera inference with a consented person on Windows and macOS.
2. Verify the **Full and Heavy** model bytes and package compatibility;
   record source SHA-256 for each profile.
3. Evaluate accuracy against appropriately labeled real pose sequences.
4. Compare inference time under consistent hardware, frame size and load.
5. Run Unity, validate source-video↔pose correspondence and compositor,
   then measure true camera-to-display latency with a valid clock strategy.

This narrows M1 risk but does **not** close M1, M2 or M3.

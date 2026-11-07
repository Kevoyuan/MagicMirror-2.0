# Unity on-device acceptance worksheet (M2 gate)

**Status: NOT YET EXECUTED.** This file is a reproducible test protocol, not a report of passing tests. The first Unity Editor execution is the current major blocker.

## Setup

- Branch: `main` (or later branch carrying these changes)
- Editor: version pinned in `Unity/ProjectSettings/ProjectVersion.txt` (currently `6000.3.27f2`).
- Open **`Unity/`** as the project root, not `OpenPosePlugin/`.
- Confirm no OpenPose native library, OpenPose Unity package, separate BODY_25 service or second camera controller is needed.
- Record OS, camera, CPU/GPU, editor version, sidecar Python/MediaPipe versions and failures.

## Automated Unity Editor synthetic gate (added in M2)

The repository now includes `Unity/Assets/Editor/M2BatchValidation.cs` and `Tools/ci/run_unity_m2.py` so the already-authored Unity self-checks can be executed without clicking menus. **This gate has not yet been run against an actual Unity installation.**

Close any Unity Editor instance already opening the same project, then run the following from the repository root. Replace the editor path with the executable installed via Unity Hub:

~~~bash
# macOS (example path; adjust for local Unity Hub installation)
python3 Tools/ci/run_unity_m2.py \
  --unity "/Applications/Unity/Hub/Editor/6000.3.27f2/Unity.app/Contents/MacOS/Unity"

# Windows PowerShell (example path)
python Tools/ci/run_unity_m2.py --unity "C:\\Program Files\\Unity\\Hub\\Editor\\6000.3.27f2\\Editor\\Unity.exe"
~~~

The script launches Unity with `-batchmode -nographics -quit -projectPath ... -executeMethod MagicMirror.Editor.M2BatchValidation.Run`. It requires **both** Unity exit code 0 **and** the explicit `MAGICMIRROR_M2_BATCH_PASS` log marker; stale logs are cleared before invocation. Nonzero exit, an explicit fail marker, or missing success marker fails closed. The default log is `m2-editor-validation.log` in the repository root (do not commit it).

The Editor suite invokes seven synthetic suites: pose math, full-body pose, stability/hierarchy, atlas registration/paths, TCP pose-frame ordering, M4 constrained two-bone world-pose bridge, and M5 body-world ↔ atlas reference calibration. The M5 Unity Editor check is authored but not yet executed. Passing it proves **those synthetic Editor checks were executed** and the Unity project compiled sufficiently to run the entrypoint; it does NOT prove real webcam access, MediaPipe native inference, camera/video synchronization, RenderTexture alpha, imported FBX integrity or complete AR performance.

The runner itself is covered by `python3 -m unittest discover -s Tools/ci/tests -v` in CI, which does **not** launch Unity. Record the actual Editor log and hardware details before marking any M2 gate as passed.

## Gate A — no camera / no MediaPipe wheel

~~~bash
python3 -m unittest discover -s Tools/pose_sidecar/tests -v
python3 -m unittest discover -s Tools/ci/tests -v
python3 Tools/ci/check_mediapipe_only.py
python3 -m Tools.pose_sidecar.main --demo --demo-scenario wave
~~~

In Unity, execute:
1. `MagicMirror > Validation > Pose Math Self Check`
2. `MagicMirror > Validation > Full Body Pose Self Check`
3. `MagicMirror > Validation > Full Body Stability & Hierarchy Self Check`
4. `MagicMirror > Validation > Atlas Registration & Path Check`
5. `MagicMirror > Validation > Pose Frame Integrity Self Check`
6. `MagicMirror > Validation > Constrained Two-Bone IK Check` (synthetic M4 bridge; no real FBX/pose calibration)
7. `MagicMirror > Phase 1 > Create Pose Tracking Scene`; enter Play, verify moving keypoints on black preview.
8. `MagicMirror > Phase 4 > Create Full Body Schematic Demo`; run `Phase4FullBodyAtlas.unity`.

Pass means **no C# compilation exceptions, no crashes, expected skeletal behavior and clean exit**. Record Unity Console logs and screenshots.

## Gate A2 — aligned synthetic video (new)

After the dependency-free black demo, test **video + landmarks together**, still without a webcam or MediaPipe model:

~~~bash
python3 -m pip install "opencv-python>=4.10,<5" "numpy>=1.26,<3"
python3 -m Tools.pose_sidecar.main --demo-video --demo-scenario walk
~~~

Run Unity Phase 1 Pose Tracking Scene and compare the moving **source-image marker locations** with Unity debug landmark positions; both must follow the same source frame when mirrored. Watch the source frame counter advance. Stop the sidecar: by default after ~0.75 seconds of silence the preview should turn black and debug points disappear. Restart: a fresh TCP session must accept frame IDs starting at zero. Run `--demo` after `--demo-video` and verify old JPEG frames are no longer displayed.

Execute `MagicMirror > Validation > Pose Frame Integrity Self Check` (or the full batch runner) to check duplicate/out-of-order frames, timestamps and reconnect behavior in actual Unity Editor. These tests are synthetic; see `Docs/M2_FRAME_INTEGRITY_AND_DEMO_VIDEO.md`.

## Gate B — real camera and sidecar

Use `Docs/PHASE_1_SETUP.md` for a Python 3.11 environment and the model bundle. With a single webcam owner:

~~~bash
python3 -m Tools.pose_sidecar.main --camera 0 --width 1280 --height 720 --fps 20
~~~

Verify:
- Camera image is reflected once, not zero or twice.
- Landmark points correspond to the **same** video frame, including rapid elbow movement.
- Subject-left/subject-right stay anatomically correct after display mirroring.
- Stopping/restarting the sidecar reconnects without a Unity restart.
- Pose loss and return do not leave permanent or incorrectly placed anatomy.
- RenderTexture transparency and alpha blending work with real video.
- Record mean/p95 processing latency, displayed FPS and resource use; no assumed numerical pass.

## Gate C — intact source atlas (M3; do not claim passed as part of M2)

After provenance review and pinned asset download, import **one** original `SkeletalSystem100.fbx`, export hierarchy inventory, validate anchors/paths, then test calibration. Do not split six independent FBXs as the primary path. Full kinematic accuracy is a later M4/M5 gate.

## Gate D — real M5 camera projection and overlay error (NOT YET EXECUTED)

After completing M2's real Unity build and M3's reviewed *intact* atlas
import, confirm real camera intrinsics, body-world camera extrinsics,
left/right/facing axes and display mirroring. Follow
`Docs/M5_STABLE_CAPTURE_AND_REPROJECTION.md` for the newly-authored
source-only `ReferencePoseCaptureWindow`, `BodyWorldPinholeCamera`
and `AtlasReprojectionDiagnostics` API contracts.

Measure actual **same-source-frame** overlay-to-estimated 2D landmarks
using a reviewed, currently animated atlas prediction for each measured
joint, not a rest-pose anchor from an unrelated frame. Record source
frame ID, source resolution, model profile, view angle, visible samples,
confidence, calibrated intrinsics/extrinsics, failure cases, numeric p90
and actual visual samples. A separate, consented, independently labelled
evaluation set is required before discussing pose accuracy or an
anatomical correctness claim.

**Roadmap target (not current result):** joint reprojection p90 <= 3% of
source image width for the defined frontal evaluation set. Source-landmark
consistency is not equivalent to ground-truth internal bone placement.
Reject missing calibration and invalid/noisy pose input rather than
hiding large errors or constructing unsupported body geometry.

## Results template

| Item | OS / hardware | Result (PASS / FAIL / BLOCKED) | Evidence (log, screenshot, recording) | Notes |
| --- | --- | --- | --- | --- |
| Unity import + compiler | | BLOCKED | | |
| Simulated pose + TCP | | BLOCKED | | |
| Full-body schematic | | BLOCKED | | |
| Camera + mirror alignment | | BLOCKED | | |
| Stop/reconnect | | BLOCKED | | |
| Transparent overlay | | BLOCKED | | |
| Measured FPS + p95 latency | | BLOCKED | | |
| M5 real camera intrinsics/extrinsics reviewed | | BLOCKED | | |
| M5 real source-frame reprojection p90 | | BLOCKED | | |
| M5 full-atlas motion/anatomical reference review | | BLOCKED | | |

Do not mark M2 complete until Gate A and B are recorded on target hardware.

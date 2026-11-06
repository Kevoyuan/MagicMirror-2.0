# M4/M5 — reviewed whole-FBX 3D motion preview (source integration)

**Current validation:** the original C# motion command planner is actually
compiled and executes **59 synthetic assertions** in Linux .NET CI.
`FullBodyAtlasRetargeter`, the coordinator and the Unity Editor self-check
pass **C# syntax/static checks only**. A real Unity Editor compile, actual
original FBX motion and camera overlay are **NOT YET VERIFIED**.

## What is now connected

The opt-in diagnostic path is:

`ONE MediaPipe sidecar camera`
→ `PoseStreamReceiver.FrameReceived` (PoseFrame v1)
→ `ReviewedAtlas3DPreviewCoordinator`
→ `ReferencePoseCaptureWindow` (12 stable non-demo frames)
→ frozen `BodySimilarityCalibration`
→ `FullBodyAtlasRetargeter.TryEnableReviewed3DPreview(...)`
→ `AtlasTwoLinkMotionPlanner` / M4 constrained IK
→ original intact FBX renderer transforms.

The original **2D schematic mirror is still the default**. Neither a
program startup nor a synthetically generated demo frame enables the
experimental 3D mode.

### 1. The engine-independent motion plan

`Unity/Assets/Scripts/Motion/AtlasTwoLinkMotionPlanner.cs` plans one
reviewed two-link region at a time. Four chains are supported:

| Chain | Atlas groups | Model indices |
| --- | --- | --- |
| Left arm | LeftUpperArm + LeftForearm | 11 → 13 → 15 |
| Right arm | RightUpperArm + RightForearm | 12 → 14 → 16 |
| Left leg | LeftThigh + LeftShin | 23 → 25 → 27 |
| Right leg | RightThigh + RightShin | 24 → 26 → 28 |

A chain requires independently reviewed proximal/hinge/distal anchors,
valid original FBX segment lengths, the M5 frozen scale transform,
one valid source frame with sufficient confidence, and a non-collinear
elbow/knee bending pole.

Atlas-rest bone lengths are converted into MediaPipe-estimated world
units before solving M4 two-link IK, then results are mapped back to
the atlas **root-local** frame. The planner returns a pair of rigid
region commands **stamped with the original PoseFrame ID/timestamp**;
both share the exact solved hinge and preserve reference link length.

It refuses demo/mirrored-source packets, missing confidence, missing or
unreviewed chains, invalid lengths, nonfinite coordinates and impossible
bend planes. It does NOT reconstruct real bone centers or twists.

### 2. One whole atlas — never detached FBX pieces

The optional 3D path is implemented inside the existing
`FullBodyAtlasRetargeter.cs`; it **reuses the single original FBX
prefab instance already instantiated by that component**, along with
the manually reviewed `FullBodyAtlasProfile`. Its default 2D code
path is preserved.

The 3D path uses non-destructively mapped `MeshRenderer` objects only.
Selected rigid regions are transformed relative to the saved
**immutable source/rest transforms** each frame; parent/child
world poses are calculated before they are applied. Unmapped anatomy
stays in the atlas reference pose. SkinnedMeshRenderer-only groups are
unsupported, and ambiguous axial twists remain unresolved.

The output is a **3D atlas-space diagnostic**. This code does not
solve camera-to-Unity extrinsics, render realistic occlusion, determine
actual user bone positions, or prove bones overlay the live RGB person.

## Explicit manual Unity Play Mode steps — NOT executed yet

1. Open `Unity/` in the pinned Unity Editor.
2. Import **one intact pinned original** `SkeletalSystem100.fbx` and
   confirm source licenses / anatomical provenance.
3. Author `FullBodyAtlasProfile` with reviewed left/right shoulders,
   mid-hip and the paired upper/lower rigid bone regions.
4. Ensure upper segment `atlasEndLocal` and lower segment
   `atlasStartLocal` share the same reviewed elbow/knee center within
   **0.5% of the shorter segment length**. A missing partner or
   overlapping source hierarchy path blocks 3D motion.
5. In a scene using the **existing** `PoseStreamReceiver` and
   `FullBodyAtlasRetargeter`, add
   `ReviewedAtlas3DPreviewCoordinator`. Assign the SAME receiver,
   retargeter and profile in its Inspector. It opens **no second camera**.
6. Check the Inspector toggle confirming this is an
   **operator-approved diagnostic only**.
7. Enter Unity Play Mode with **real non-demo** MediaPipe video.
   In the coordinator Component context menu, explicitly invoke
   **Begin reviewed 3D diagnostic capture (Play Mode ONLY)**.
   The system captures 12 stable frames, computes a median reference
   pose and freezes registration if quality/review checks pass.
8. Inspect limb connectivity/rest lengths in **atlas coordinates**.
   Stopping/restarting TCP, excessive gaps or frame rollback must
   hide the atlas and require fresh authorization.
   To exit, use **Stop reviewed 3D diagnostic preview**.

This cannot be triggered from the schematic `--demo` source because
the real atlas profile, reviewed source reference and live pose
frames are required. There is no implicit fallback from a failed 3D
preview into 2D animation.

### Important camera-space limitation

The atlas remains in its **own original root coordinate system**.
Its 3D motion may be displayed in a diagnostic Scene camera, but it
is **NOT YET aligned over the actual RGB video**. Camera intrinsics,
extrinsics, person-facing direction, depth/occlusion and actual
same-frame reprojection evaluation are M5 hardware/visual acceptance
gates. See `Docs/M5_STABLE_CAPTURE_AND_REPROJECTION.md`.

## What automated CI tests really prove

~~~bash
dotnet build Tools/ci/csharp_kinematics/KinematicsChecks.csproj \
  -c Release --warnaserror
dotnet run --no-build -c Release \
  --project Tools/ci/csharp_kinematics/KinematicsChecks.csproj
~~~

The test executable compiles the **same engine-independent production C#**
`AtlasTwoLinkMotionPlanner.cs` source as Unity and executes
`AtlasPlannerChecks.cs` (59 assertions), on top of prior M4/M5 math
and PoseFrame checks. It covers both arm/leg sides, hinge and segment
connectivity, clamped motion, source packet identity, confidence,
unreviewed reference anchors, invalid model/world data and pose limits.

The newly added `M4M5AtlasMotionPreviewSelfCheck` is authored into the
Unity batch validation as an **eighth** synthetic Editor check, to be
**executed on an actual Unity installation later**. Source syntax
parsing is not a Unity compilation or a scene run.

## Acceptance checklist still BLOCKED by no Unity/FBX hardware gate

- Real Unity Editor compiles and executes all eight synthetic suites.
- Whole Z-Anatomy FBX imports with true source-local scale and anchors.
- Reviewed 3D prefab limb motion is visually plausible without overlap.
- Loss/reacquisition and stream reconnect do not retain wrong identity.
- Validated source camera extrinsics and anatomical left/right identity.
- Actual 2D projection/reprojection p90 in real-camera test clips.
- Physical camera-to-display end-to-end latency, target OS benchmarks.
- Asset author/license review for distributing each anatomy layer.

**Research/educational illustration only; never actual X-ray or
personalized measurement of the viewer's internal anatomy.**

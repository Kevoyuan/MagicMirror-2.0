# M5 — Optional camera-aligned anatomy overlay (source implementation)

**Status: EXPERIMENTAL SOURCE ONLY.** The complete Unity 6.3 Editor has NOT
compiled this new integration, no real Z-Anatomy FBX was imported in CI, and
no physical webcam calibration, subject-pose reprojection or live AR
overlay has been validated. The feature is **disabled by default**.

## What was added

The single MediaPipe → same-frame PoseFrame → M4 IK → frozen M5 3D atlas
pipeline can now *optionally* register the **entire original unmodified
FBX container** to a real source camera by using independently measured
parameters instead of the old schematic orthographic projection.

- `PoseFrame.streamSessionId` is a non-wire, non-serialized field assigned
  by the trusted Unity TCP receiver **after packet acceptance**. A
  12-frame capture stores exactly one session generation. Mixing frames
  across reconnects rejects capture and invalidates an armed 3D preview.
- `BodyWorldPinholeCamera.TryToCameraSpace` converts *estimated*
  MediaPipe body-world points into explicit camera-local X-right,
  Y-up, Z-forward coordinates.
- `BodyWorldPinholeCamera.TryGetSourceFrustum` computes source-video
  pixel-calibrated off-axis near-plane frustum. This respects measured
  focal lengths and noncentral principal points.
- `AtlasCameraSpaceRegistration` composes the reviewed full-atlas
  reference registration with camera extrinsics; its output is a
  proper right-handed 3D rotation, uniform scale and translation.
- `ReviewedCameraCalibrationProfile` is a **ScriptableObject invalid by
  default**. Both independent camera intrinsics and external body-world
  camera pose must be entered and manually reviewed.
- `BodyWorldCameraConsistency` checks shoulders (11,12) and hips
  (23,24) against the **same source frame's** observed 2D landmarks.
  P90 Euclidean pixel residual is divided by source image width.
  Reprojection failures, absent landmarks, source-session changes,
  unreviewed camera parameters or incorrect dimensions hide the model.
- The existing `FullBodyAtlasRetargeter` gains a second authorization
  gate `TryEnableReviewedCameraOverlay`. It does NOT change the normal
  2D motion path, and does NOT automatically enable camera alignment.
- `ReviewedAtlas3DPreviewCoordinator` can optionally load a reviewed
  camera profile after the explicit 12-frame body capture. The boolean
  `requestReviewedCameraOverlay` is **false by default**.
- Real-profile Phase 4 scene generation now creates and wires that
  coordinator to the same original receiver, retargeter and intact
  model. The schematic Phase 4 scene remains unchanged.

## Camera model and coordinate conventions

Normalized unmirrored source image coordinates, top-left origin:

`u = cx + fx * Xc / Zc`

`v = cy - fy * Yc / Zc`

`(Xc,Yc,Zc)` is measured relative to the source camera origin,
expressed in the model's estimated BODY-WORLD coordinate system.
The camera right/up/forward vectors must be unit length, orthogonal,
and right-handed. **This is NOT equivalent to a Unity Camera transform,
and is not obtained automatically from MediaPipe.**

The Unity `Matrix4x4.Frustum` boundaries at distance `near` are:

`left = -cx * near / fx`

`right = (1 - cx) * near / fx`

`bottom = -(1 - cy) * near / fy`

`top = cy * near / fy`

The FBX atlas root-local space is mapped via the frozen calibration into
estimated body-world, then camera-local, then the assigned Unity anatomy
Camera's world frame. The Unity adapter supports **only uniform,
positive source FBX root scale** and a camera transform with no unintended
non-unit hierarchy scale. It preserves original renderer rest transforms.

The transparent RenderTexture and live JPEG already share the same
mirror UV convention in `ArmXRayCompositor`. This camera-aligned mode
keeps the source-camera projection **unmirrored** and lets the compositor
flip both displayed layers together. No 3D coordinate reflection is used.

## How to test when Unity and original FBX are available

1. Import the exact pinned complete `SkeletalSystem100.fbx` and review
   anatomy identities, source license and joint anchors using the full
   atlas setup/calibration tools.
2. Create a real `FullBodyAtlasProfile` with individually reviewed
   shoulder/mid-hip landmarks and **paired** upper/lower limb groups.
   Create the real Phase 4 scene. The coordinator component is already
   connected to the same sidecar receiver and original model.
3. Independently calibrate the **physical RGB source camera** and its
   relationship to the stable observed body/reference pose, including
   exact resolution, intrinsics and body-world extrinsics. Save the
   measured values in a new `ReviewedCameraCalibrationProfile` asset.
   Nothing is prefilled with fictional camera constants.
4. Tick the source intrinsics/extrinsics reviewed boxes on that asset.
   In the coordinator Inspector, assign it; explicitly enable
   `requestReviewedCameraOverlay`, mark the **separate** operator approval,
   and confirm the diagnostic-only authorization.
5. In Play Mode, run the real MediaPipe sidecar, then choose
   **Begin reviewed 3D diagnostic capture (Play Mode ONLY)** from the
   coordinator context menu. Hold the reference pose for 12 stable
   frames. No camera is opened twice.
6. The preview becomes available only if review flags, TCP source session,
   frozen reference fit, source dimensions, model identity and the
   per-frame estimated 2D/3D P90 check all pass. It remains disabled on
   bad measurements, reconnects or model dropouts.
7. Visually inspect actual video/atlas alignment and physically measure
   source-frame reprojection, occlusion, latency, and left/right/facing
   semantics on representative consented real videos. Do not report
   success from synthetic tests alone.

The camera pose is held fixed in the reference **estimated body-world**
frame. Translating/rotating the viewer's torso changes the relationship
to the physical camera and will generally trigger the reprojection guard.
True free movement needs a **per-frame camera↔body pose estimate** (e.g.
reviewed PnP using known image camera intrinsics, confidence and
independently validated reference correspondences). The current source
does not implement this or automatic video calibration.

## Source CI evidence

Run on a machine with .NET 8:

~~~bash
dotnet build Tools/ci/csharp_kinematics/KinematicsChecks.csproj -c Release --warnaserror
dotnet run --no-build -c Release --project Tools/ci/csharp_kinematics/KinematicsChecks.csproj
~~~

The suite compiles and executes the **exact production C#** for camera
projection, image-width-normalized P90, atlas-to-camera registration,
source TCP session capture and existing constrained 3D motion planner.
Its camera tests use constructed 1280x720 observations; the reported
residuals do **not** represent hardware performance.

The Editor batch also includes the ninth synthetic check
`M5ReviewedSourceCameraSelfCheck` — authored, **not yet run in Unity**.

## Blockers to an actual v0.5 full-skeleton AR MVP

- Real Unity C# API compile and full original FBX model import.
- Independent camera calibration and stable, accurate world↔camera pose
  under actual body motion.
- Reviewed true anatomy mesh membership, joint centers and license rights.
- Confirmed RGB overlay, mirror and video frame synchronization.
- Tested 3D bone motion, depth ordering, occlusion and torso rotations.
- Reproducible real-video joint reprojection (P90 <=3% width target,
  not a current result) and measured device end-to-end latency.
- An installable, supportable Windows/macOS app and packaging.

**MagicMirror presents a standardized educational anatomy reference
overlay. Ordinary RGB cameras do not capture the viewer's internal bones.**

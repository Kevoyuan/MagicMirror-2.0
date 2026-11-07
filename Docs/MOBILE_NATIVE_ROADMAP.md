# MagicMirror Mobile — exclusive product delivery roadmap (2026-11-06)

**User promise:** launch a phone app, point one phone camera at a person,
see a semi-transparent standard *reference* skeleton automatically follow
their movement. Entirely on device: no computer, Unity, Python service,
cloud AI, account or wearable. A native iOS SwiftUI/MediaPipe **prototype**
now exists and has passed arm64 Simulator compilation; real iPhone operation,
3D anatomical mesh and mobile release readiness are **not yet validated**.

**Authority:** ADR-002_MOBILE_NATIVE_OFFLINE_FIRST.md records the accepted
**smartphone-only** product scope. This is the sole active product delivery
roadmap. Docs/ROADMAP.md is archived desktop engineering history. We are
not planning or shipping Windows/macOS versions, and Unity or Python will
not be required in the installed iOS/Android runtime.

## Active smartphone milestones; each must build and run on a physical handset

| Milestone | Deliverable | Exit gate |
| --- | --- | --- |
| **Mobile-0 — native camera shell** | iOS prototype first (provisional): Swift/SwiftUI app, one native camera owner, permissions, orientation, source frame ID/timestamps, local-only processing, no account or network | Real camera preview in airplane mode on identified device; no Python/Unity runtime; no data upload |
| **Mobile-1 — live body tracking** | MediaPipeTasksVision `PoseLandmarker` LIVE_STREAM with bundled Lite model, one person, 33 normalized + estimated world landmarks, optional segmentation, latest-only frame queue | Real person moves: landmarks remain on the SAME displayed source frame; drop/recover on occlusion without stalling rendering |
| **Mobile-2 — transparent procedural skeleton** | Rigid connected *proxy* skeleton, skeleton clipping to person silhouette, GPU alpha compositor and automatic framing/reacquisition | No manual bone anchors; walk/raise arm/squat in defined scenes; reference drawing stays over a moving user at a plausibility threshold |
| **Mobile-3 — reviewed coherent anatomy atlas** | Audit original Z-Anatomy asset/attribution; offline mobile mesh export and compression; coherent articulated rig with root/bone transforms | A complete reference atlas renders on actual mobile GPU without violating licenses, with proper connected limbs |
| **Mobile-4 — 3D correspondence** | Port validated IK/fit math from desktop into audited portable/native library; dynamic camera/body space alignment, segmentation, per-frame reprojection and reasonable reference limb movement | Measured real-person labeled landmark reprojection, no persistent detachment; lose/hide on bad fit or wrong left/right; tests on front/side/turning |
| **Mobile-5 — shipping quality** | UI for opacity/pause, explanation labels, thermal/latency instrumentation, camera permissions, offline/privacy, onboarding, device compatibility and TestFlight | Target >=30 FPS, p95 movement-to-display <=150 ms on selected physical device; camera interruption/resume and 10min thermal/battery tests recorded |
| **Mobile-6 — Android parity** | Android Kotlin/CameraX or single ARCore camera session + MediaPipe Tasks LIVE_STREAM + native GPU atlas compositor | Same camera/pose/rig/reprojection/gating test vectors on representative physical Android, offline end-to-end |

Do **not** claim a gate passed because Python unit tests, static C#
parser, or a browser mock passed. Physical smartphone test recordings and
measured latency are needed.

## Architecture work packages

### Mobile runtime (iOS first; not yet created)

```text
Mobile/iOS/MagicMirror/
  App/                      native SwiftUI state, permissions, privacy
  Camera/                   single captured-frame source + geometry
  Tracking/                 MediaPipeTasksVision LIVE_STREAM adapter
  Motion/                   native IK + frozen/reference model
  Anatomy/                  reviewed skinned atlas import/metadata
  Rendering/                Metal camera + alpha skeleton compositor
  Calibration/              automatic fit, confidence and invalidation
  Diagnostics/              frame-id/reprojection/latency counters
  Resources/                approved bundled .task + atlas asset
```

Do not create fake non-buildable Xcode project files before selecting the
actual iOS SDK/Xcode toolchain and reproducing the official sample on a
phone. The project can begin with a verified MediaPipe upstream example,
but must become a new independent MagicMirror app rather than depending
on a Python desktop sidecar.

### Interoperability from existing source

Export deterministic fixture vectors from the current compiled M4/M5
math and pose-frame protocol. New mobile native code must pass **parity
tests** for 3D handedness, body/world coordinates, left/right IDs, IK
joint limits, frame identity, pinhole intrinsics and source-to-display
mirroring.

Do not ship a loopback TCP receiver or run a localhost Python process
inside the app. Keep any offline FBX optimization scripts in development
only; the installable phone application bundles finalized audited assets.

## Usability contract

The normal path is a one-screen experience:

1. Open -> camera permission (only first run) -> live unmirrored rear camera.
2. One person enters frame -> detect shoulders and hips automatically.
3. After a short quality-gated stabilization, draw semitransparent **reference**
   bones; do not require tapping a calibration button.
4. Move the arm/knee/body -> pose and anatomical bone rig follow together.
5. Tracking dropout -> fade affected bones, then resume on reacquisition.
6. Optional opacity and pause controls appear without covering the subject.

A full-body skeleton requires the subject to be far enough away to
appear sufficiently in frame; on limited phone focal lengths or a close
selfie this may be impossible. Provide a clear, friendly framing hint and
optional upper-body mode rather than manufacturing missing bones.

## Risk register and how to validate

| Risk | Evidence required |
| --- | --- |
| Camera/pose frame mismatch | Image + landmarks bound to one capture timestamp; native automated fixture and physical capture checks |
| "Looks like X-ray" false confidence | Permanent illustrative/nonmedical label; all product copy tested for clarity |
| Wrong body side under mirror | Deliberate front/rear camera flip matrix, explicit real-movement left/right tests |
| Pose world lacks calibrated camera extrinsics | Test known camera intrinsics, dynamic body↔camera pose estimation, real reprojection |
| Full atlas huge/unrigged | Mobile-optimized offline asset conversion, rig audit, measured memory/GPU and attribution |
| Segmentation hides intended inside-body bones | Custom person-silhouette compositing; avoid blanket occlusion that masks all virtual anatomy |
| Moving/turning people, occlusion | Defined motion dataset with manual visible-joint labels, quality gates and fade behaviour |
| Battery / thermal throttling | >=10-minute sustained session metrics on named models, optional Lite fallback |
| Device variation | Capability-driven ARKit/ARCore depth fallback, no dependency on LiDAR/ToF |
| Android parity | Same frame/time and kinematics test fixtures, physical GPU tests per family |

## Definition of first usable mobile MVP

A user installs a signed app on a supported phone, disables networking,
grants camera permission, points its built-in camera at **one person**,
sees a clearly marked standard semitransparent skeleton appear automatically,
and watches the skeleton continue to follow visible joint motion with no
external machine, sensor, service or account.

The MVP can initially use a coherently rigged *proxy skeleton* pending
asset audit, but it must be labelled as such and cannot be represented as
the final verified Z-Anatomy full atlas. The final product acceptance also
requires reviewed anatomical content and appropriate device benchmarks.

## Next executable task (smartphone only)

Start **Mobile-0 + Mobile-1** together: a buildable native iOS camera +
MediaPipe Tasks 33-point live overlay with frame/latency diagnostics.
Obtain a physical iPhone and exact Xcode target version; choose between
AVFoundation and ARKit as the **single camera owner**. Use the official
on-device Pose Landmarker sample as a tested starting point:
https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker

An Android build should follow a shared pose/rig contract, not fork
different anatomical fitting algorithms. Do not return to any desktop
shipping milestone after completing a mobile phase.

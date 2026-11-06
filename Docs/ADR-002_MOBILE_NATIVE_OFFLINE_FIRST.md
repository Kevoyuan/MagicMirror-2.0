# ADR-002 — Mobile-native, offline-first MagicMirror as the primary product

**Status:** Proposed (product direction provided on 2026-11-06; implementation not started)
**Scope:** User-facing mobile experience. Historical desktop Unity + Python source remains a research/reference implementation, not a phone runtime dependency.
**Supersedes for new product delivery:** Desktop-first assumptions in PRODUCT_VISION.md, ARCHITECTURE.md and ROADMAP.md. Does NOT supersede ADR-001's MediaPipe-only principle.

## Product contract — the actual user's request

> Open MagicMirror on a phone → point its camera at one person →
> a semi-transparent *standard reference skeleton* appears automatically
> over the body → when the person moves, the skeleton follows.
>
> No separate computer, Unity, Python sidecar/server, cloud inference,
> wearable sensors or user-managed tracking device are required.
> Camera inference, rig calculations, rendering and UI run **on device**.

No account, calibration wizard, posture markers, long wait or elaborate
onboarding should stand between a successful camera permission grant and
a first plausible overlay. On-screen guidance is limited to actionable
conditions (e.g., "Move farther back so shoulders and hips are visible").
A hidden internal stabilization period is allowed; showing misleading
anatomy while keypoints are uncertain is not.

For the FIRST usable release, prefer **one subject** visible with the
rear-facing camera and the entire upper body. Full-body framing and
self-camera support are product extensions, not promised hardware
capabilities on every handset. No wearer/body-mounted sensor.

## Architectural decision

The end-user application is **native to iOS/Android**, not a remote
desktop screen, WebRTC streamed Unity scene, embedded browser requiring a
server, nor a Python process. The existing Unity 6.3/Python desktop
proof-of-concept is NOT included in the mobile binary.

The pipeline owns exactly **one camera** and one frame identity:

```text
PHONE CAMERA (one owner: native camera/AR session)
    | timestamped source frame + camera geometry
    v
ON-DEVICE MEDIAPIPE TASKS POSE LANDMARKER
    | 33 normalized landmarks + estimated world landmarks
    | optional person-confidence segmentation mask
    v
VISIBILITY / SINGLE-PERSON / FRAME-ID QUALITY GATE
    | deterministic latest-only queue; no growing latency
    v
MOBILE ANATOMICAL RETARGETING
    | reference-body proportions; bounded joint angles
    | filtered IK + bone rig; left/right and facing checks
    | explicit camera intrinsics / projection and reprojection
    v
MOBILE GPU SCENE / COMPOSITOR
    | standard full atlas mesh, semi-transparent material
    | camera background + body-fitting silhouette matte
    | depth/occlusion where device supports it
    v
FULL-SCREEN LIVE ANATOMY VIEW + minimal controls
```

The app must never overlay tracked landmarks from frame N on unrelated
frame M without explicit timestamp association and bounded latency.
A source-side mirror transform applies to image AND anatomy presentation
consistently, never changes anatomical left/right identities. Pose/world
coordinates are *estimates*, NOT camera extrinsics or measured bone
positions.

### Proposed native adapters (not yet implemented)

| Layer | iOS first proof | Android follow-up |
| --- | --- | --- |
| Camera | AVFoundation AVCaptureVideoDataOutput OR ARKit ARSession capturedImage; one owner, never both simultaneously | CameraX OR ARCore session; one owner |
| Pose | MediaPipe Tasks Vision Pose Landmarker, LIVE_STREAM and bundled .task model | MediaPipe Tasks Vision Pose Landmarker LIVE_STREAM |
| GPU skeletal overlay | Metal/MetalKit primary; RealityKit/ARKit optional for device/camera tracking and occlusion | Filament / OpenGL ES or Vulkan; ARCore optional |
| Confidence mask | MediaPipe pose segmentation, optimized for fitted skeleton clipping; not blanket default person-occlusion | MediaPipe segmentation; optional ARCore Depth when supported |
| UI | Native SwiftUI plus render view | Native Jetpack Compose plus render view |
| Storage | bundled weights/approved atlas + on-device settings, no upload by default | same |
| Shared math | First port relevant M4/M5 formulas and test vectors to a portable, audited library; avoid porting Unity scene or TCP | reuse parity vectors and/or portable core |

MediaPipe on-device availability: https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker

iOS ARKit occlusion is capability-gated; its stock person-occlusion can
hide virtual content BEHIND the person, which is *not* automatically
appropriate for an intentionally visible anatomy-inside-body overlay.
Use a custom compositing policy, not a naïve always-on occlusion flag.
Android ARCore Depth is optional and device-dependent:
https://developers.google.com/ar/develop/java/depth/developer-guide

### One-camera rule

Native camera frames are the sole authority for timestamps, image crop,
lens orientation, source mirror state, and the image shown to the user.
ARKit/ARCore must NOT open a second independently sampled camera beside
AVCapture/CameraX. Choose one source per mode and feed the **same frame**
into the pose model, texture upload, and 3D overlay compositor.

### Asset policy

The goal is still ONE coherent, anatomically connected reference atlas,
NOT separate ad-hoc FBX fragment downloads. The original source
`SkeletalSystem100.fbx` can be converted **OFFLINE during development**
to a mobile-optimized skinned rig asset (e.g. USDZ or glTF), preserving
joint identity, hierarchy, provenance and rest transform meaning.
The phone never requires Blender, FBX tooling, a PC process or a network
asset server. Binaries MUST NOT ship until source licenses and mesh
attribution are individually audited. Use an explicitly labelled
procedural proxy skeleton for first integration and performance checks;
do not misrepresent it as Z-Anatomy.

A mobile-ready mesh requires memory, GPU fill-rate, vertex count, draw
call and thermal budgets to be tested on physical target devices. Merely
copying an intact high-poly FBX to the app is not a release strategy.

## Explicit product UX states

1. **Permission required:** request camera access once; show a meaningful
   explanation if denied, with retry/settings path.
2. **Searching:** show live camera, lightweight silhouette guide and
   "Point at one person"; never fake a tracked skeleton.
3. **Tracking:** automatically place semitransparent **reference anatomy**
   within visible body silhouette. A small always-visible label makes
   the educational/reference nature clear.
4. **Partial visibility / tracking loss:** fade or hide affected bones,
   suppress stale predictions, provide short framing hint; avoid drawing
   apparently confident bones at arbitrary coordinates.
5. **Recovered:** automatically reacquire a person and stable scale without
   requiring an explicit manual calibration; do not persist stale identity.
6. **User control:** skeleton opacity and pause are secondary, optional
   controls; no login, no manual bone selection to begin use.

The statement "open -> point -> skeleton follows" is the acceptance test,
not proof that arbitrary motion, occlusion or under-the-skin anatomy can
be reconstructed from monocular RGB. Use public-facing language like
"interactive anatomy illustration" and "reference skeleton", NOT
"actual X-ray scan" or "your real bones".

## Success criteria (TARGETS, not observed)

- Offline airplane-mode install-and-run after app and packaged assets are
  already installed; no backend and no account.
- One camera input, one tracking session and one displayed source frame.
- Subject acquisition and automatic illustration without manual landmark
  configuration on the defined single-person test scenes.
- Aim >= 30 displayed FPS and p95 camera-to-photon movement <= 150 ms
  on a **named physical handset**; record device, thermal state, model,
  battery drain and repeated-session measurements.
- Track a reference moving rig without persistent detached joints or
  obvious wrong-side limbs on a defined representative test set.
- Reprojection p90 <= 3% of source width is an aspiration for explicitly
  defined and labelled visible joints, **not** a measure of personal
  internal-bone accuracy.
- Handle loss/recovery, framing changes, front/rear mirror conventions,
  camera interruption, app background/resume and unsupported depth modes.
- Include camera consent, local-only processing, attribution and a
  permanently accessible "illustrative, nonmedical" explanation.

## Open questions (do not block first proof)

- First shipping platform is provisionally **iOS**, since one native
  device family simplifies camera/GPU integration, with Android as a
  planned second frontend. User has not explicitly selected a platform.
- ARKit-first vs AVFoundation+Metal-first camera adapter should be
  benchmarked against frame latency/3D projection rather than guessed.
- 3D anatomical reference rig complexity and bundle size depend on
  the separately verified Z-Anatomy license and source geometry.
- On-device PnP/facing and occlusion for walking/turning remain major
  research and integration risks.
- Native pose-world estimates do not directly supply accurate camera
  extrinsics; a dynamic body↔camera alignment system is required.

## Effect on existing work

- `Tools/pose_sidecar/`: useful for historical benchmark/reference data,
  but **not** shipped in iOS/Android apps.
- `Unity/`: useful as a historical prototype/visual debugger, but **not**
  an app runtime, packaging dependency or hidden mobile engine.
- `Tools/ci/csharp_kinematics/` and M4/M5 tests: preserve as algorithm
  specifications/parity vectors; port math and reproduce tests in the
  mobile implementation rather than importing Unity C# code blindly.
- M6 desktop release gate becomes superseded for the user-facing mobile
  target; retain desktop roadmap only as a clearly labelled legacy plan.

No mobile runtime or actual app is claimed to exist by this ADR.

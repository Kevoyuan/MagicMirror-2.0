# AGENTS.md — MagicMirror Coding Agent Instructions

> Applies to the entire repository. This file is the coding agent's operating
> contract. Read it **before planning, editing, reviewing, or merging**.
> Last aligned with the user's product decision: 2026-11-07.

## 1. Product north star (non-negotiable)

**MagicMirror is a phone-only, offline-first, real-time educational anatomy AR app.**

The intended user journey is:

1. Open the installed phone app and grant camera permission once.
2. Point the built-in camera at **one person**.
3. A **semi-transparent, three-dimensional standard-reference skeleton**
   automatically appears aligned to the visible body.
4. Move, raise arms, bend elbows/knees, squat or walk; the skeleton follows.
5. Lose the person, a joint or camera tracking -> fade/hide uncertain bones
   and reacquire automatically, rather than fabricate internal anatomy.

Users must **not** need a computer, a Unity runtime, a Python process,
a local/remote server, cloud inference, an account, wearable sensors or
a manual bone calibration workflow. Inference, rigging, compositing and UI
run on the **phone itself** after installation. Developer machines,
Xcode and offline asset-conversion tools are allowed **for development only**.

**Only mobile products will ship. Implement iOS first with native Swift;
Android is a subsequent native phone target. Do not develop or release a
Windows/macOS desktop product.** Do not reintroduce Unity or a Python
sidecar into the installed app or call desktop TCP code from mobile.

The end result is **a real articulated anatomical 3D model**, NOT merely a
2D landmark stick figure. A 33-point line overlay is an *engineering
preview* and must be described honestly as such.

MagicMirror uses a generic, reviewed reference anatomy atlas. An ordinary
RGB camera **cannot see or measure the user's real internal bones**.
Never describe the overlay as an X-ray scan, medical diagnosis or an
anatomically exact personal reconstruction.

## 2. Source of truth and active work

Read these in order:

1. `Docs/ADR-002_MOBILE_NATIVE_OFFLINE_FIRST.md` — accepted phone-only product
   and architecture decision.
2. `Docs/MOBILE_NATIVE_ROADMAP.md` — **only active product delivery roadmap**.
3. `Mobile/iOS/README.md` — iOS build/run instructions, when available.
4. `Mobile/iOS/project.yml` and the implementation under
   `Mobile/iOS/MagicMirror/`.
5. `Docs/PRODUCT_VISION.md`, `Docs/ARCHITECTURE.md` and
   `Docs/ROADMAP.md` are **archived desktop-prototype context**.
   Do not continue their desktop milestones.

Development PRs may be stacked. At the time of this instruction:
- **PR #11:** accepted mobile-only product direction documentation (Draft,
  base `main`).
- **PR #12:** SwiftUI/AVFoundation/MediaPipe first iOS camera + landmark
  overlay (Draft, based on PR #11's branch).

Before editing or opening a PR, inspect the live repository branches,
PR bases, changed files and current CI. Do **not** assume these statuses
remain current. Keep PRs focused and avoid accidentally replacing
independent work in stacked branches. Never force-push or merge a Draft
without an explicit decision and reviewed tests.

The retained `Unity/`, `Tools/pose_sidecar/` and M4/M5 C# code are
**research/algorithm references**, NOT future app deliverables. Extract
and port validated math/test vectors when useful; do not continue Unity
scene development to meet the phone release. Do not delete research history
without a separate explicit cleanup decision.

## 3. iOS implementation conventions

**Language / app UI**
- Swift, SwiftUI, iOS 17+ baseline; prefer `@Observable` with
  `@MainActor` for view-facing state.
- Keep views small and composable; separate camera capture, inference,
  motion/retargeting, rendering and UI state.
- Use native SwiftUI controls with clear accessibility labels, permission
  and privacy explanations. Prefer straightforward standard Apple APIs;
  do not introduce Flutter or Unity.
- Reuse `swiftui-expert` guidance for state ownership, concurrency,
  view identity, accessibility and performance-sensitive refactors.

**Single-camera, real-time contract**
- One video source owner: AVFoundation **or** an ARKit-owned camera session,
  but not competing simultaneous sessions.
- Start/stop capture off the main thread. Respect camera authorization,
  foreground/background, interruption, and orientation/mirror transforms.
- MediaPipe Tasks Vision `PoseLandmarker` runs **on device** in
  `.liveStream` mode with the bundled, verified `.task` model.
- Use capture timestamps, original image dimensions, camera orientation
  and stable source-frame identity throughout inference, compositing and
  diagnostics. Never silently overlay pose N onto unrelated video frame M.
- Drop stale frames rather than building latency; guard missing, low
  confidence, duplicate or out-of-order landmarks. Reset tracking when
  capture sessions change. Hide stale anatomy.
- MediaPipe `worldLandmarks` are estimated model-space values; they
  are **not** validated camera extrinsics or measured human bone centers.

**Anatomical rendering**
- A lightweight connected proxy skeleton is acceptable for initial
  camera/pose integration. Mark it visibly as **reference/proxy**.
- The actual product requires a coherent **3D** articulated reference
  skeleton, human-reviewed joint centers/hierarchy, reference lengths,
  constrained IK, 3D camera/body alignment and appropriate transparency.
- Use RealityKit and/or Metal for 3D GPU rendering as justified by
  measured native performance. ARKit depth/occlusion is an optional
  capability-gated enhancement; the baseline must work without LiDAR.
- Correct aspect-fill source-image crop, source pixel intrinsics,
  left/right anatomical identity, portrait/landscape rotation and
  front-camera mirroring explicitly. Avoid arbitrary 3D reflections.
- Bad tracking, ambiguous anatomy, incorrect calibration or lost identity
  must fail closed (fade/hide), NOT display confidently incorrect bones.
- Full source Z-Anatomy models may be converted and optimized **offline**
  into a cohesive mobile rig/mesh. Preserve attribution, hierarchy and
  provenance; verify each asset's license before bundling/distribution.
  Do not ship a high-poly original FBX by copying it blindly, invent
  anatomy joints, or split arbitrary mesh pieces into false structures.

**Privacy and release**
- The installed app must function in airplane mode with all required
  models/assets already bundled. No upload or storage of camera frames by
  default. No account/backend is needed for core functionality.
- Display a clear, persistent "illustrative reference / not medical
  imaging" explanation; no clinical claims.
- Keep camera and motion data on device by default. Any telemetry,
  photos, recording or network features require an explicit separate
  privacy/product decision.

## 4. Active execution order (do not skip hardware gates)

1. **Mobile-0 — iOS build + camera:** Make the XcodeGen project,
   SwiftPM model dependency, bundled model and native SwiftUI app compile.
   Verify permission, camera preview and app lifecycle on a real iPhone.
2. **Mobile-1 — on-device pose:** Show 33 live landmarks from the
   **same captured video stream**, with confidence and stale-frame gates;
   measure actual subject acquisition/recovery on device.
3. **Mobile-2 — automatic translucent proxy:** A connected, motion-following
   placeholder skeleton that appears without an onboarding calibration
   wizard; correct image crop/mirroring and graceful partial occlusion.
4. **Mobile-3 — reviewed 3D anatomy atlas:** Audit Z-Anatomy license and
   source identity, build a mobile-optimized **single coherent rig**,
   preserve joint mapping and test real mobile GPU memory/fill-rate.
5. **Mobile-4 — robust 3D body-to-atlas AR:** Port verified M4/M5 math
   with parity fixtures; dynamic camera-to-body alignment, 3D constrained
   joint motion, proper perspective, reprojection and controlled occlusion.
6. **Mobile-5 — iOS release quality:** Usability, privacy/attribution,
   TestFlight, framing/recovery, real device FPS/latency/thermal testing.
7. **Mobile-6 — Android:** Kotlin, on-device MediaPipe and native GPU
   rendering using equivalent pose/rig/math tests. No desktop alternative.

**Current practical blocker:** The first PR #12 macOS Xcode CI attempt
failed when an x86_64 iOS Simulator link was attempted against arm64-only
MediaPipe binary artifacts. Inspect the latest CI before acting; use a
supported arm64 simulator runner or a valid iOS device build/test target.
Do not hide this by claiming compilation succeeded or by stripping the
SDK. The next coding priority is a **green real iOS build**, then a
**physical iPhone camera/landmark smoke test**.

## 5. Testing and evidence requirements

For changes to iOS code:
- Run/check `Mobile/iOS/Scripts/fetch_model.sh` (model SHA-256 and byte
  size), `xcodegen generate --spec Mobile/iOS/project.yml` in the
  project directory, and an actual `xcodebuild` in a macOS environment
  whenever tooling allows.
- Use an architecture supported by the pinned MediaPipe XCFramework.
  Do not claim iPhone runtime success from simulator linking alone.
- Add focused XCTest tests for framing, confidence, mirroring, source-frame
  ordering, geometry, kinematic invariants and recovery logic.
- Preserve off-main camera/inference work and avoid redrawing the entire
  SwiftUI app at high capture FPS; measure, don't guess.
- Test on a physical phone for camera preview orientation, live overlay
  alignment, single-person tracking, background/resume, permissions,
  occlusion, app offline behavior, sustained FPS and thermal throttling.
- Targets for later real-device acceptance, **not current results**:
  >=30 displayed FPS and p95 movement-to-display <=150 ms on a named
  iPhone. A proposed visible-landmark reprojection p90 <=3% of source
  width is not evidence of internal-bone accuracy.
- Distinguish **source present**, **syntax parsed**, **Xcode compiled**,
  **simulator unit tests passed**, **physical iPhone validated**, and
  **full anatomical model verified**. These claims are NOT interchangeable.
- If a tool/environment is unavailable, be explicit about the blocker
  and still leave reproducible source, commands and tests.

## 6. Coding agent workflow / definition of done

1. Identify the **smallest active mobile milestone** the task advances.
2. Inspect relevant source, upstream API, dependency versions, branch
   dependencies, and current CI **before modifying code**.
3. Implement the end-to-end vertical slice rather than another isolated
   diagram. Keep changes bounded to `Mobile/iOS/`, mobile docs and
   directly relevant CI unless migration work is explicitly requested.
4. Add deterministic checks and, when available, real Xcode build/phone
   evidence. Do not insert unverified placeholder configs or fake
   anatomical measurements to satisfy a test.
5. Update the active mobile roadmap/status and iOS README when behavior,
   setup, dependencies, risk or acceptance gates change.
6. Open a reviewable PR with the correct base branch and describe exactly
   what ran, what passed/failed, what remains unverified and why.
7. Do not merge failing/unfinished work merely to show progress. Do not
   automatically merge unfinished Draft PRs or rewrite desktop history.

**A feature is done only when the actual relevant platform gate passes.**
A beautiful 2D stick-figure demo does not complete the 3D anatomy MVP;
a green static-code check does not complete a usable iPhone app.

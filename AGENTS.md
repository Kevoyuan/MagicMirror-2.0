# AGENTS.md — MagicMirror 2.0 coding contract

> **Authoritative platform revision:** 2026-11-09 (W1 continuation). The user explicitly
> switched to **Web open source first**, kept the native iOS code but
> **paused all new native iOS development**, and canceled Android.
> This replaces the previous iOS-only operating contract in AGENTS.md.

## 1. Product direction (must follow)

MagicMirror is a **browser-based, open-source educational anatomy mirror**.
The user starts on a camera-first responsive Web page, grants a single
browser camera permission, and sees a semi-transparent, illustrative 3D
reference follow confidently observed body landmarks. No separate
computer process, Unity/Python runtime, cloud inference API, account,
manual wearable/calibration workflow or paid App Store installation
is needed for the browser prototype.

**Active Web source of truth, in order:**
1. `Docs/ADR-003_WEB_OPEN_SOURCE_FIRST.md` — current platform decision.
2. `Docs/WEB_MVP_ROADMAP.md` — the **only active release roadmap**.
3. `Docs/WEB_ARCHITECTURE.md` — current runtime and boundaries.
4. `Web/README.md`, `Web/src/`, `Web/package.json`.
5. `DESIGN.md` — Leonardo visual direction.

**Frozen research:** `Mobile/iOS/` (SwiftUI/Metal, tests, CI, commercial
gates and all associated draft PRs) is PRESERVED, not deleted or a
new feature target. Draft PRs #49–#53 remain on hold; do not silently
merge, rebase, close or port them merely to claim progress. The
Unity/Python reference research is also preserved. **No native Android
project at all.** Resume iOS only if the owner explicitly requests it.

## 2. Honest Web MVP baseline

- TypeScript + Vite, Three.js, MediaPipe Tasks Vision Web.
- One `getUserMedia` source owner, no audio, no server-side inference;
  show camera permission/denial/availability states and stop real tracks
  on background/close. Browser camera needs HTTPS or localhost.
- PoseLandmarker VIDEO estimates up to 33 landmarks for **one person**.
  It is synchronous on Web and currently deliberately throttled.
  Use frame timestamps, confident joints and bounded freshness; drop
  insufficient/unknown observations rather than inventing bones.
- Overlay is a **three-dimensional GPU-meshed PROCEDURAL PROXY** placed
  using screen-space 2D landmark/crop/mirroring math, not measured
  internal bones, camera extrinsics, clinical data or a verified
  Z-Anatomy atlas. Present the label clearly at all times.
- Mirror front-camera image and overlay together; preserve video
  `object-fit:cover` cropping and measured source dimensions.
- If WebGL, MediaPipe, model, permissions or tracking fail, show
  truthful user-facing status and fade/hide uncertain geometry.
- Preserve the Leonardo da Vinci sketchbook aesthetic: slim header,
  **camera is the main area**, compact parchment controls, no
  decorative dashboard. Only actual Proxy/Whole/Arms/Legs/Opacity/
  Pause/Camera features are enabled; unbuilt layers/sections are
  explicitly disabled or informational.
- Input video/pose data is not stored or uploaded by MagicMirror
  source. MediaPipe SDK **may send usage/performance metrics** per
  its own privacy notice; this requires separate public release
  privacy and consent audit. Do not claim zero network calls.

## 3. License boundaries

`Web/LICENSE` grants MIT rights only over newly authored `Web/`
application code. The historical iOS/Unity/Python code and Google
PoseLandmarker model **weights** do not become MIT by association.
The SDK's Apache-2.0 license does not grant rights in separately
hosted model weights. A specific rights/redistribution/privacy review
is required before a real public hosted site is shipped. Keep
`Web/release-clearance.json` unapproved until that evidence exists.
`npm run build:code` is a source test artifact; `npm run build`
is a human-release-gated product build.

Z-Anatomy/BodyParts3D assets are **not in Web W0**. Converting meshes
to GLB/OBJ or opening app source does not override third-party NC
rights. Before W2, verify **every original included mesh**, license,
attribution, modifications and CC BY-SA derivative distribution;
build an independently reviewed cohesive rig and camera registration.
A separate public CC BY-SA package is possible only with compatible
actual rights; do not pretend this solves all legal issues.

## 4. W1 development contract — owner tested first Web build (2026-11-09)

The owner reports having **tested the Web MVP**, but did not supply the
browser/device, screenshots, measured tracking success, performance,
camera facing, or error logs. Treat this as a useful hands-on smoke-test
report, **not verified cross-browser acceptance or full W0 completion**.

Prioritize implementation, tests, and documentation over repeated plans.
The owner's request to "continue all features" means work through the
active Web backlog **in order**, as far as evidence and rights permit,
without falsely claiming it is all finished. Implement release-independent
capabilities now; never invent legal clearances or 3D atlas assets.

**W1 execution order:**
1. Reliable capture lifecycle: one active session, stop ended/interrupted
   tracks, ignore results from stale/replaced cameras, handle user gesture
   and permission failures, recover via a new user action.
2. Prefer off-main-thread MediaPipe VIDEO inference using a worker with
   transferable ImageBitmap and a strict latest-only, one-in-flight
   frame budget; **gracefully fall back** to throttled synchronous
   main-thread inference on unsupported Worker/OffscreenCanvas browsers.
   If worker throws, fail closed/hide its geometry rather than reuse old
   results; fallback must be safe.
3. Add actual local per-frame inference time, output cadence, dropped
   samples and capture-to-overlay delivery (not mislabeled screen FPS,
   camera hardware latency or personally measured anatomy).
4. Keep a real Three.js GPU model for the procedural learning proxy,
   but no unreviewed Z-Anatomy meshes. Organ/section-layer toggles only
   become actionable when actual independently cleared assets exist.
5. Synthetic tests for ordering/session-stale/stalled/partial pose and
   crop/flip; Web CI must compile source and the worker entry point.
6. Optional *explicit user-action* export may save a photo locally,
   with clear consent, no automatic recording/upload, and no misleading
   medical/X-ray labels. Never capture or persist by default.

**W2–W4 constraints:** real whole-atlas mesh rights evidence and
reviewed coherent rig, independent camera registration, layer/section
rendering and open-source publishing are separate gated milestones.
If not genuinely ready, keep them disabled and list the blocker.

**Product invariant:** The user-facing result must remain "3D educational
reference based on observed surface pose", not their actual bones.
A worker improves responsiveness; it does not fix image-to-rig 3D
camera calibration.

## 5. Engineering and test workflow

1. Inspect repository branches/active PRs and current CI; choose the
   smallest Web milestone. Do not re-activate old mobile milestones.
2. Implement a working vertical slice in `Web/`, Web-specific docs
   and Web CI. Do not modify `Mobile/iOS` except on explicit request.
3. Prefer small pure-tested geometry/confidence/state logic separate
   from webcam, MediaPipe and Three.js side effects.
4. Run (or CI-check) `cd Web && npm install && npm run typecheck &&
   npm test && npm run build:code` (code-only; no legal release claim).
5. Actually run browser webcam/WebGL on a desktop and mobile Safari
   before claiming camera UX, measured latency or mobile quality.
   iPhone Simulator/native build is irrelevant to Web acceptance.
6. Document exact pass/fail gates, limitations, rights and privacy.
   Maintain the Web roadmap and README; open a reviewable PR.
7. No silent draft merges or removal of historical source. No fake
   model rights review or Release booleans to make CI green.

**Done means implemented + test evidence + real-browser functional
verification + required source rights for any published release.**
Build success alone is NOT release, hardware success or anatomical
precision.

## 6. W2 local-only anatomy study workflow (2026-11-09)

The Web interface now supports **user-selected LOCAL .fbx and .glb
inspection** in a separate Three.js model study dialog with OrbitControls,
mesh part picking, wireframe, transparency, and model-axis clipping. This
is a static viewer, **not** an installed Z-Anatomy layer or rigged AR model.

- No FBX, GLB, or derivative third-party assets may be committed,
  downloaded automatically, staged or deployed without a separate
  verified redistribution/license review. The importer operates
  solely on a user-selected browser File's in-memory ArrayBuffer.
- The local model belongs to its original author. An MIT code license
  does not relicense files the user selects.
- The model is **NOT** retargeted to human pose; a raw original source
  may have no authored skinning. Display actual mesh, triangle,
  skinned-mesh and skeleton joint counts without inventing weights.
- Keep import ≤75MB and ≤2M triangles, limit texture URLs via a
  local-only loading manager, clear/stop GPU rendering on close and
  avoid remote background asset fetch. On desktop-heavy FBX prefer
  offline optimization before mobile viewing.
- Slice planes are oriented to **source/model axes**; do not call
  them medically validated body planes. The W2 real anatomy overlay
  remains blocked until actual mesh-by-mesh license, rigging,
  camera calibration and correct real-device performance evidence.

## 7. W4 original educational segment notes (2026-11-09)

The Web GPU **proxy** now accepts clicks on *only visible* segments
via a deterministic tested screen-space distance threshold. Short
original bilingual descriptions may name generic humerus, radius/
ulna, femur or tibia/fibula regions, but must explicitly explain
that the visual segment is **not** the user's measured bone or a
Z-Anatomy mesh. Never infer medical conditions. Dismiss detail
when tracking/camera state invalidates the observed segment.
Do not silently promote proxy educational annotations to
reviewed per-mesh true atlas selection or copied textbook content.

## 8. W1b adaptive proxy pose smoothing (2026-11-09)

Confidence-preserving, time-aware smoothing is allowed for the
**visual procedural reference only**. It must never extrapolate hidden
joints, turn a low-visibility MediaPipe point into a visible
anatomical prediction, hallucinate real bone locations or claim
medical calibration. The W1b source module
`Web/src/smoothing.ts` resets when the capture session is stopped,
on lost pose or long time gaps, hides single-frame implausible
jumps, and does not retain any pose history beyond the in-memory
latest joint positions. The Layers folio can disable smoothing
for developer comparison; tests must establish nonprediction.

## 9. Web locale switch and contribution consistency (2026-11-09)

The Web header now provides a compact **中文 / EN** button, using
original, locally bundled translations from `Web/src/i18n.ts`.
Never use third-party translation services or send camera/pose
text to a cloud endpoint. Keep status, permission errors, privacy
copy, camera controls and learning cards aligned across locales.
Do **not** translate arbitrary user-provided model filenames,
mesh source names or authorship; preserve exact provenance.
The switch must never change media sessions, tracking identity,
model binaries or active privacy controls.

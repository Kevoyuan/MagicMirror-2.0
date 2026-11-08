# AGENTS.md — MagicMirror 2.0 coding contract

> **Authoritative platform revision:** 2026-11-08. The user explicitly
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

## 4. Engineering and test workflow

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

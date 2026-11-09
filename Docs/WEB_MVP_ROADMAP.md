# MagicMirror Web — only active release roadmap

**Decision:** 2026-11-08 · Web first/open source.
**iOS:** frozen; no active native feature or release milestones.
**Android:** canceled. **Unity/Python:** research only.
**Source of truth:** ADR-003 and Web Architecture.

## W0 · First usable browser mirror (IN PROGRESS)

- [x] Add self-contained `Web/` Vite + TypeScript + Three.js/Mediapipe project.
- [x] Require user click + browser camera permission; on-device pose only.
- [x] Partial arm/leg confidence gating, honest lost/occlusion states.
- [x] Transparent Three.js 3D **proxy**, same `object-fit:cover`
      coordinate transform and front-camera mirror semantics.
- [x] Camera-first Leonardo layout, focus, opacity, camera switch,
      overlay pause, contextual privacy/asset and disabled layer info.
- [x] Web UI Leonardo v2 source refinement: safe-area header, on-demand
      opacity/diagnostics/study explanation, 44px controls, responsive
      mobile parchment sheets and proxy-first honest layer content.
- [x] Add bilingual disclosure copy and synthetic localization test coverage.
- [ ] Verify real Safari/Chrome layout, text zoom, keyboard/dialog focus,
      70% camera-stage composition target and overlapping status/notes.
- [x] Keep third-party mesh/model binaries out of Git; stage pinned
      developer model and package WASM with hash/byte checks.
- [x] Author synthetic pose/crop tests and GitHub Web CI source build.
- [x] Initial Web MVP PR #54 merged to main with green source/WASM/model staging CI.
- [~] Owner reports a manual Web MVP test (2026-11-09); device/browser and outcome metrics were not supplied. Do not infer a pass for specific interactions.
- [ ] Record real desktop browser and mobile Safari camera smoke test details;
      observe actual tracking, mirroring, occlusion, orientation,
      battery/thermal, usable overlay rate and recovery.
- [ ] Independently verify Google PoseLandmarker **model weight**
      redistribution rights and SDK metrics privacy before deployment.
- [ ] Choose legitimate public static host/domain and HTTPS;
      deploy only after `release-clearance` reviewed.

**W0 definition of done:** working real camera Web app with
documented physical-browser evidence and real asset/distribution
rights. Typechecking alone is not a shipped MVP.

## W1 · Measured real-time browser reliability

- [x] Implement a Worker-first MediaPipe VIDEO pipeline (transferable
  ImageBitmap), with one in-flight frame and main-thread fallback.
  **Source/tests pass; actual browser worker availability remains unverified.**
- [x] Instrument measured output rate, MediaPipe inference p50/p95,
  request-to-result p95; reject stale camera-session results and cap
  oldest in-flight frame. These are **not** actual display FPS,
  image-sensor latency or confirmed camera/atlas registration.
- [x] Explicit, click-only local PNG snapshot with object-fit/crop/
  mirror mapping and nonmedical reference watermark.
- [ ] Measure media capture-to-rendered-display on real hardware
  (Worker alone does not ensure source video/overlay pixel locking).
- Test laptop webcams, midrange Android Chrome (browser testing only,
  **no Android native app**), and iPhone Safari portrait/landscape.
- Test front/rear mirror, video crop, partial frame visibility,
  pause, background, permission revocation and recovery.

## W2 · Genuine reviewed anatomical skeleton

- Review every included **original** Z-Anatomy/BodyParts3D mesh for
  license/author/version; NC/unknown cannot enter the app.
- Preserve approved source geometry and license metadata; build a
  coherent <=256-joint mobile-friendly skeleton rig, not one bone per
  original fragment. Hand-author real vertex weights.
- Ship a separately licensed CC BY-SA derivative only where rights
  and distribution terms are actually compatible; retain source,
  author, change/attribution evidence.
- Convert to optimized WebGL assets, test GPU memory and semantic
  region selection. True anatomical atlas remains DISABLED until
  real geometry, motion, rights and camera gates pass.

### W2a · Local-only anatomical research viewer (SOURCE IMPLEMENTED; QA OPEN)

- [x] Let users choose their own `.fbx` or self-contained `.glb` in
  browser with no automatic upload, extraction to a server, or
  inclusion in the public release.
- [x] Separate, clearly labelled **static** Three.js atlas inspection
  from the working procedural camera-following proxy.
- [x] Orbit rotate/zoom, source mesh name on click, wireframe,
  transparency and mathematically real X/Y/Z **model-coordinate**
  clipping planes (not validated human anatomical sections).
- [x] Show real mesh/triangle/skinned mesh/joint counts; reject
  >75MB original files and >2M triangle models before GPU integration.
- [x] Route external texture/resource URLs from local FBX/GLB to a
  local placeholder to avoid unexpected resource network requests.
- [ ] Verify actual pinned Z-Anatomy source FBX renders on desktop
  and measure memory, load duration, orientation and material status.
- [ ] Verify mobile Safari handling or document a desktop-only limit.
- [ ] Verify substantive per-original-mesh rights, authored weights,
  mapping and calibrated true motion overlay before enabling
  **real** anatomical layer controls.

## W3 · Body-to-camera 3D registration

- Human-reviewed anatomical rest anchors/length constraints, stable
  3D camera/body hypotheses, reprojection bounds and side identification.
- Real motion following, occlusion, orientation handling and
  transparent layering; under uncertainty hide, never fake X-ray.
- Independently test against real browser frames and named devices;
  no clinical or measured-bone claims.

### W4a · Interactive reference field notes (SOURCE IMPLEMENTED)

- [x] Tap any actually rendered, confidence-gated limb/torso
  **procedural proxy segment** to see an original short educational
  note with Chinese and English anatomical region labels.
- [x] Disclose that a MediaPipe surface segment does **not** show
  measured bones, actual clavicles/vertebrae/ribs or individual organs.
- [x] Hide notes when real pose tracking is lost, camera is stopped,
  user dismisses them, or stale observations invalidate the overlay.
- [x] Pure synthetic screen-space hit-testing tests; no 3D atlas
  mesh is implied by touching a generated cylinder.
- [ ] Verify actual touch hit targets, clipping and readability on
  mobile Safari/desktop Chrome with a person in camera.
- [ ] Expand to REAL per-part bone/organ teaching notes only after
  human anatomical source review and true atlas rig/selection.

## W4 · Learning, contributors and public release

- Source-backed anatomy notes, genuine layer visibility and real
  clipping planes only once inspected reviewed models exist.
- EN/ZH localization, accessibility and privacy controls; license
  and attribution dialogs derived from real component manifests.
- Privacy disclosure of SDK metrics, actual deployment rights,
  model/system release notices, open-source contribution guide,
  browser performance budgets and static deployment.
- Reconsider a commercial iOS client only after an explicit owner
  reactivation decision. No parallel native backlog in W0–W4.

## W1b · Visual temporal stability (SOURCE IMPLEMENTED; real QA open)

- [x] Adaptive low-latency smoothing of the *visible procedural
  proxy only*, never MediaPipe raw identity/rights evidence.
- [x] Hard reset on disappearance, long observation gap, camera stop,
  out-of-order timestamps; reject implausible single-joint
  teleport without fabricating the missing joint.
- [x] Optional Layers folio checkbox lets a developer compare
  raw observations to stable display.
- [x] Pure tests for small motion, telemetry ordering, impossible
  movement, missing joints, reacquisition and dropout.
- [ ] Validate real apparent jitter and moving-person lag against
  raw unfiltered landmarks on desktop/iPhone browser. No camera-to-
  display latency improvement has been measured by CI.

## W4b · Native bilingual Web UI (SOURCE IMPLEMENTED; visual QA open)

- [x] Small **中文 / EN** switch in the camera-first header.
- [x] Local, no-network dictionary translating core static controls,
  guide/privacy/source content, actual camera statuses and
  educational note details; existing user pose data never leaves
  the browser for translation.
- [x] Pure bilingual language tests; no machine-translated anatomical
  claims, no guessed 3D measurement.
- [ ] Review every long dialogue paragraph, accessibility name and
  dynamic local model-study error in both locales on real mobile and
  desktop browsers; not all literal copy has been QA-approved.

## W2b · Local source-part hierarchy and inventory (SOURCE IMPLEMENTED)

- [x] Search original mesh names and hierarchical paths of the
  *locally selected* FBX or GLB, with 60 initial results and
  bounded "show more" pagination.
- [x] Hide/show individual parts, isolate a source mesh, restore
  visibility preferences and focus/reset the orbit camera. The
  visual labels come from source names, not inferred anatomy.
- [x] Select source meshes by clicking rendered geometry and
  synchronize the source-name/triangle display with list controls.
- [x] Compute SHA-256 of the selected **original model bytes**,
  and export a local JSON inventory of source file identity,
  all real source mesh hierarchy paths and triangle/skinning
  counts. Each license/rights field is explicitly **unreviewed**;
  no author authorization is fabricated.
- [x] Reject malformed/too-large inputs, excessive triangle
  or mesh budgets; invalidate stale local import on dialog close.
- [x] Synthetic tests for source tree/filter/pagination, isolated
  part visibility restoration, JSON source identity and default
  rights status.
- [ ] Confirm real Z-Anatomy `SkeletalSystem100.fbx` import
  fidelity, memory, names, part focusing and clipping against
  desktop browser; assess mobile Safari budget separately.
- [ ] Carry out full human source-by-source copyright/license
  evidence review; create a **real** authored mobile rig and
  camera registration before enabling live anatomy overlays.

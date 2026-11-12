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

## W2c · Source rig quality sampling & authored animation (SOURCE IMPLEMENTED)

- [x] Inspect actual imported `SkinnedMesh`, skeleton joint UUIDs,
  authored `skinWeight`/`skinIndex` data, and model-authored
  `AnimationClip` objects. Do **not** create missing Z-Anatomy
  weights or claim this is a complete anatomical rig.
- [x] Bound vertex-weight sampling per mesh; report actual
  missing/unweighted/invalid joint references and suspicious
  influence sums, marked clearly as **sampled only**.
- [x] Preview independently authored FBX/GLB clips with user-click
  Play/Pause, no autoplay and no MediaPipe body-pose retargeting.
  Ignore malformed or extreme source clips and cap list to 40
  previewable candidates.
- [x] Include sampled diagnostics in the user-initiated
  local JSON inventory while leaving the full rights status
  `NOT_REVIEWED` and all original per-mesh license fields blank.
- [x] Pure tests for valid/malformed weighted vertices and bounded
  animation sanity, strict TS + CI build.
- [ ] Verify actual animated, rigged GLB/FBX playback and joint
  deformations in desktop Chrome and iPhone Safari; source test
  does not prove WebGL skinning runtime correctness.
- [ ] Review original Z-Anatomy FBX's real missing weights and
  author an independent cohesive rig using Blender before any
  live human-motion retargeting; add camera-space calibration,
  semantic source-part mapping, occlusion and per-part rights.

## W2d · Manual original-mesh ↔ MediaPipe surface-segment draft

- [x] Define the 12 actually observed MediaPipe limb/torso
  segment pairs; do not equate the reference surface graph
  with a true skeletal/bone hierarchy.
- [x] Add a manual (unassigned by default) pose-segment dropdown
  for each original mesh in the local source browser. Multiple
  source components may reference one segment.
- [x] Explicitly save/load local SHA-256 and byte-size-bound
  JSON drafts; validate exact source mesh count, path, name,
  triangle count, unique source indices, supported segment
  and non-approved rights/retargeting/calibration flags.
- [x] Reject model mismatches and import all assignments
  atomically (no partial corruption); never persist mappings
  without the user's explicit download.
- [x] Strict TS + synthetic Vitest invalid/replay/tamper
  tests; no third-party models committed or newly hosted.
- [ ] Run manual import/export, source model swap, browser
  camera and animation tests on actual Chrome/Safari.
- [ ] Build a separately reviewed true anatomical rig,
  rest-pose anchors, camera/model-space registration and
  real-time skeletal retargeting before any true atlas overlay.

## W2e · Original-source mesh point selection (SOURCE IMPLEMENTED)

- [x] Let users explicitly choose **start/end** model-local
  sample points on the SAME visible original mesh by 3D
  raycasting, only after a manual W2d surface-segment
  assignment. Warn when a mesh is hidden/occluded or
  its authored animation is still playing.
- [x] Keep user coordinates in original source-root local
  space, not normalized renderer/view/camera space; do
  not call arbitrary clicks verified anatomical joints.
- [x] Show per-source point A/B and complete-pair progress.
  Clear when the mesh's surface mapping changes, model
  is replaced or the mapping draft is imported afresh.
- [x] SHA-256 + original mesh metadata + exact current
  pose-segment assignment-locked user-triggered local
  JSON export/import. Reject forged approval flags,
  invalid/overlapping/non-finite points, source mismatch
  and duplicates with all-or-nothing import.
- [x] Strict TS, pure synthetic endpoint validation,
  anti-tamper tests and Web source build in CI.
- [ ] Run original pinned Z-Anatomy desktop FBX and
  known rigged GLB through actual raycast anchor picks.
  Evaluate model root origin, FBX units/orientation,
  accuracy and mobile Safari memory/performance.
- [ ] Author a real, coherent anatomical rig/rest
  hierarchy, explicit geometry-to-joint association,
  physical camera extrinsics and retargeting acceptance.
  Neither W2d nor W2e enables true live model AR.

## W2f · Single source-mesh rigid pivot preview (SOURCE IMPLEMENTED; real browser QA OPEN)

- [x] Restrict to **one user-selected non-skinned original
  mesh** with exact W2d original-mesh mapping and two
  distinct W2e user-chosen A/B local model points.
- [x] User-driven start, choose **source-model X/Y/Z**
  rotation axis, bounded ±90° angle slider, and
  **Restore original pose** (no autoplay, live tracking,
  camera input, saved geometry, or model redistribution).
- [x] Use immutable source original root/parent/world
  matrix baselines; each angle applies a fresh pivot
  delta around manually selected A, preserving geometry
  and making reset exact. Move the B reference marker
  along with the rigid source part.
- [x] Fail closed for `SkinnedMesh`, authored
  `AnimationClip` models, invisible or unselected
  parts, missing/overlapping endpoints, or invalid
  transform data. Invalidate preview when W2d mapping,
  W2e anchors, model source or study modal changes.
- [x] Pure deterministic unit tests for pivot invariance,
  transformed parent frames, source-geometry identity,
  reset, extreme angles and no accumulated drift.
- [ ] Real local Z-Anatomy FBX / known rigged GLB
  physical-browser WebGL and camera-space validation
  on desktop Chrome and mobile Safari.
- [ ] Distinct future work: actual whole-rig skeleton
  hierarchy authoring, joint limits, mesh/skin weights,
  MediaPipe **3D** pose calibration, multi-joint
  retargeting and exact source-frame synchronized AR,
  with independent per-original-mesh rights evidence.


## W2g · Bounded manually-authored virtual source-mesh hierarchy (SOURCE IMPLEMENTED)

- [x] Build a strict model-root-space transform graph for
  **2–12** explicitly selected non-skinned source meshes with
  user-selected parent references and distinct original A/B points.
- [x] Reject cycles, duplicates, unselected parents, malformed
  source points/angles and excessive inputs before changing display.
- [x] Propagate parent transforms to child source parts while
  computing all matrices from immutable rest transforms.
  Warn when an authored parent/child endpoint gap exceeds
  20% of the parent's source-space segment length.
- [x] Render independent golden wireframe **ghost** geometry,
  preserving the original source meshes, their exact matrices,
  skin weights, materials and underlying shared geometry.
- [x] Source browser provides Add/Remove, manual parent
  editor, start/stop, per-node X/Y/Z ±90° angle controls
  and reset all angles. Valid source mapping/anchors required.
- [x] Existing generated local model and privacy/release rights
  gates remain unchanged. No third-party geometry added to Git.
- [x] Pure tests for multi-generation movement, parent-first
  ordering, cycles, malformed source graphs, singular matrices
  and no accumulated drift. Web source CI typecheck/unit/build.
- [ ] Hardware verification of actual model FBX/GLB geometry,
  ghost rendering, mobile GPU memory and touch targets.
- [ ] Author a reviewed 3D human bone hierarchy and
  anatomical rest joints, genuine per-mesh rigging,
  MediaPipe world-frame/camera calibration and physical
  body motion retargeting; these remain separately blocked.


## W2h · One-click original 3D self-contained tutorial (SOURCE IMPLEMENTED)

- [x] Create a 3-piece nonmedical bar/box GLB *entirely
  in the browser* from authored MagicMirror geometry,
  with no external source files or model-rights ambiguity.
- [x] Use the real existing local GLB loader, original
  mesh names/positions, SHA-256 and user-only study viewer.
- [x] Explicitly label the synthetic source as **NOT
  Z-Anatomy, NOT a human bone, NOT camera retargeting**.
- [x] Preconfigure original source-anchored W2d mapping
  reference, W2e A/B positions and W2g three-node
  virtual parent chain for a working tutorial.
- [x] Existing camera/real model release/privacy
  gates remain fail-closed; no original anatomy assets
  are added to Git, model uploads or analytics.
- [x] Synthetic tests cover authored original names,
  unique geometry anchors, 3-level graph and gap bounds.
- [ ] Run the full GLTFExporter→GLTFLoader→WebGL
  desktop Chrome and iPhone Safari interaction path
  on actual browsers; compile/unit tests alone do
  not establish runtime or mobile touch success.


## W2i · Source-hash-bound offline angle timeline (SOURCE IMPLEMENTED)

- [x] Deterministic, bounded original-root virtual
  chain angle keyframes (1–32, 0–10 seconds,
  per-node source axis and ±90° angles).
- [x] Human-keyframe capture, delete, scrub,
  play/pause/loop, clear and one-click local-only
  JSON export/import with **no webcam frames**.
- [x] Explicit source SHA/size/count plus exact
  manual node hierarchy, source-root A/B anchors
  and fixed axes; strict false rights/retargeting
  claims, unknown fields and invalid data rejected.
- [x] Atomic THREE.js batch source ghost
  transforms per frame; no cumulative drift
  or changes to imported model geometry.
- [x] Seed three synthetic frames in the ORIGINAL
  three-box onboarding demo so new users can
  immediately try deterministic virtual movement.
- [x] Pause requestAnimationFrame on source
  change, hidden tab, model study close or
  user stop; source or graph edit invalidates
  stale keyframe draft.
- [x] Synthetic tests for interpolation, boundaries,
  altered model, parent/point/axis mismatch,
  duplicate times and forged license claims.
- [ ] Confirm Chromium and Safari real-frame
  playback, touch smoothness, GPU budget and
  source GLB chain orientation on real devices.
- [ ] Review anatomical original sources,
  author 3D joint/rest hierarchy, skinning
  weights, camera/world landmark registration,
  pose retargeting and privacy/rights signoff
  before advertising true anatomical AR.


## W2j · Original-demo browser integration smoke

- [x] Add real Chromium browser tests for UI navigation
  without camera permission, EN locale switch and close.
- [x] Exercise the original generated, self-contained
  3-box GLB through real GLTFExporter/GLTFLoader,
  Chromium WebGL, source-part list, bounded manual
  chain and local keyframe loop controls.
- [x] Download source-SHA-bound timeline JSON, verify
  rights status remains NOT_REVIEWED, reject a forged
  source SHA, and re-import valid local data without
  changing original geometry or camera state.
- [x] Install Playwright only for opt-in smoke; preserve
  fast source CI and existing default-denied public
  deployment. Use the same `Web-first MVP` workflow,
  with manual dispatch or a `browser-smoke` PR branch,
  no additional workflow.
- [x] Verified the exact opt-in PR workflow on GitHub-hosted
  Chromium/WebGL: **3/3 Playwright E2E tests passed**,
  including real generated GLB/WebGL, live timeline
  controls, bad-source rejection and good JSON reimport.
  Evidence: https://github.com/Kevoyuan/MagicMirror-2.0/actions/runs/42651083351 .
  Ordinary Web pushes still skip Chromium installation;
  browser-smoke PR branches and manual dispatch opt in.
- [ ] Independently test actual camera permission,
  iPhone Safari portrait/landscape, real Z-Anatomy
  source FBX import/units, skinning, performance,
  privacy and component copyright in physical devices.
  Headless CI is not hardware acceptance.

## W2k · Two-engine original-demo browser integration (BROWSER CI PASS)

- [x] Reuse real W2j browser E2E in **desktop Chromium**
  and **mobile/touch-enabled iPhone 13 Linux WebKit emulation**.
- [x] Both browser engines run the actual source code-generated
  original GLB exporter/loader/WebGL pipeline, user chain
  controls, local frame replay, source SHA JSON rejection
  and safe reimport. No camera usage or external anatomy assets.
- [x] Pin GitHub's opt-in browser job to Ubuntu 24.04 and
  install both Playwright engines only when manually
  dispatched or a `browser-smoke` feature PR requests
  the heavy check; ordinary source CI remains fast.
- [x] **6/6 real browser E2E PASS** (3 desktop Chromium,
  3 Linux WebKit with iPhone-size viewport/touch)
  https://github.com/Kevoyuan/MagicMirror-2.0/actions/runs/42652358053 .
- [ ] Physical iPhone Safari (camera permission, WebGL on
  actual Apple GPU, viewport/orientation, thermal/GPU
  performance, local large FBX import and source assets),
  plus legal/privacy approval, remains independently blocked.


> Merge note: developed as "W2j" on a parallel branch; renamed to W2l on merge
> because mainline W2j/W2k are the opt-in browser smoke milestones.

## W2l · One-file local study session (SOURCE IMPLEMENTED; real browser QA OPEN)

- [x] Bundle the four separate user-authored drafts (W2d mapping,
  W2e source A/B points, W2g virtual chain, W2i keyframes) into ONE
  explicitly downloaded, ORIGINAL-model-SHA-bound local JSON.
- [x] Reuse the existing strict draft parsers: exact source SHA/size/
  mesh identity, original mesh names/paths/triangles, manual segment
  assignment, chain-versus-anchor A/B equality, parent graph/axis
  and every keyframe time/angle.
- [x] All-or-nothing restore: forged approval/camera/medical fields,
  unknown keys, cycles, single/oversized chains, duplicate parts,
  mismatched anchors and extreme angles leave live state untouched.
- [x] Viewer-side fail-closed check for hidden, skinned or animated
  source meshes; no automatic ghost preview, camera or replay start.
- [x] Bounded pure deterministic matrix-replay diagnostic at frames
  and interpolation midpoints, explicitly NOT calibration evidence.
- [x] EN/ZH session controls and status copy; synthetic Vitest
  round-trip, tamper, ordering, no-drift and locale tests; strict
  TS + Web CI source build.
- [ ] Verify real FBX/GLB one-file export/import, DOM touch targets
  and study restore on desktop Chrome and iPhone Safari.
- [ ] Real per-original-mesh rights review, reviewed anatomical rest
  rig, camera registration and retargeting remain blocked before any
  true atlas overlay or public release.


## W1c · Worker fail-closed lifecycle (SOURCE IMPLEMENTED; real browser QA OPEN)

- [x] Extract `Web/src/inference-result.ts`, a PURE worker-message gate:
  `accept` / `ignore` / `fatal` from closed, ready, recovering, mode,
  workerAlive, in-flight frame id and camera session, plus strict
  validation of timings, dimensions, inference cost and <=33 finite
  landmarks. No DOM, Worker, MediaPipe or camera side effects.
- [x] Invalidate the in-flight frame id and session synchronously on
  worker crash, stall, malformed result, `close()` and boot abort;
  terminate the worker and clear its 2s stall deadline.
- [x] Ignore late worker results/fatals/errors after recovery instead
  of drawing a reused pose or firing a second fatal; settle (not reset)
  the latest-only gate so frame ids stay monotonic on the fallback.
- [x] Re-check frame/session/mode identity after async `createImageBitmap`;
  close bitmaps whose frame was abandoned; propagate boot rejection
  when the camera session is closed.
- [x] Synthetic Vitest coverage for the pure gate (8 cases) and the
  fake-Worker / fake-MediaPipe lifecycle (7 cases); Web CI asserts
  that `vite build` emits a `pose.worker-*.js` chunk containing
  `detectForVideo`.
- [ ] Verify real Chrome/Safari WASM + transferable ImageBitmap worker
  boot, crash/stall recovery, fallback cadence, foreground/background
  camera sessions and measured delivery latency on physical devices.
- [ ] Keep `releaseApproved: false`; model/rights review, anatomy rig,
  camera extrinsics and cross-browser acceptance stay separate gates.


## W3a · Live pose-driven ORIGINAL articulated rig (SOURCE + LOCAL BROWSER E2E PASS)

**Status: experimental 2.5D / screen-aligned articulation milestone.**
Not anatomical AR, not camera-space 3D registration, not real skeletal
mesh rigging. Every visible mesh is generated by MagicMirror code.

- [x] Add `Web/src/live-rig/pose-to-rig.ts`, a PURE 33-landmark →
  display-space rig engine: session/frame/freshness gate, mirror and
  object-fit:cover mapping, confidence hiding, parent-relative forearm
  angle, ±π wrapping, bounded stabilization, discontinuity hiding,
  anatomical left/right (11/13/15 and 12/14/16) that never swap on flip.
- [x] `Web/src/live-rig/original-rig.ts`: original procedural
  `CylinderGeometry`/`SphereGeometry`/`BoxGeometry` rig with a REAL
  shoulderPivot → elbowPivot → forearm hierarchy, absolute transforms,
  shared immutable geometry/materials, deterministic hidden rest pose,
  independent (unparented) forearm when the shoulder is not visible,
  explicit `hide()`/`dispose()`.
- [x] `Web/src/live-rig/rig-controller.ts` + `OverlayRenderHost` in
  `Web/src/scene.ts`: reuse the existing WebGLRenderer/Scene/
  OrthographicCamera. NO second camera stream, renderer or RAF loop.
  `main.ts` remains orchestration-only; `inference.ts` is unchanged.
- [x] Layers UI gains `Reference Proxy` (DEFAULT) and
  `Live Original Rig (Experimental)` (opt-in radio), an honest dynamic
  status line and a collapsed limitation disclosure. All new copy is
  original 简体中文 / EN; no translation service.
- [x] Preserve camera start/stop/flip, mirror, cover crop, partial-body
  tracking, confidence hiding, worker fallback, overlay pause, opacity,
  local-only PNG capture, latency metrics and privacy behavior. Opening
  the local FBX/GLB study dialog still stops the camera; imported models
  are NEVER live-retargeted. No production pose-injection backdoor.
- [x] Synthetic Vitest: `pose-to-rig.test.ts` (31),
  `motion-coherence.test.ts` (5 — two consecutive moving frames → tracker
  → Three.js world joints), `original-rig.test.ts` (12),
  `rig-controller.test.ts` (9 — includes session A→B stale clearing and
  late-A-cannot-remove-B) and the W3a bilingual cases in `i18n.test.ts`.
  Whole `npm test` suite: **151/151 passed**; `npm run typecheck` clean.
- [x] Review fixes: coherent filtered-pose contract (stabilization applies
  to JOINT POSITIONS, not angles in isolation; every frame field is derived
  from one filtered joint set; bounded lag ≤ 0.25 × shortest segment);
  controller fail-closed session contract (A→B clears stale A geometry,
  late A cannot remove B); hierarchy metadata consistency (rejected parent
  → `hierarchyAttached: false`, `parentRelativeRadians: null`).
- [x] Opt-in `tests/browser/live-original-rig.spec.ts` (3 tests × 2 engines):
  deterministic numerical fixture (wrist tip continuity, mirror, partial arm,
  shoulder-less independent forearm, legs rejection, stale rejection),
  opt-in/EN-ZH/camera-off/local-study isolation, no injection hooks,
  a single stage canvas, and a shared WebGL host integration test that
  mounts through the real `ProxySkeletonRenderer` and verifies coherent
  world joints across two consecutive frames. **12/12 local Playwright E2E
  passed** (6 Chromium desktop + 6 iPhone-sized WebKit ENGINE emulation).
  No camera, restricted binary or third-party mesh is loaded.
- [ ] GitHub-hosted opt-in browser CI evidence for this exact W3a
  revision is pending PR verification; local macOS WebKit is NOT
  physical iPhone Safari, Apple GPU, camera permission or thermal QA.
- [ ] True camera-space 3D registration / calibrated extrinsics,
  reviewed anatomical rest rig, real skeletal skinning and weights,
  Z-Anatomy/BodyParts3D mesh-by-mesh rights, PoseLandmarker weight
  redistribution review and MediaPipe SDK metrics privacy sign-off
  all remain separately blocked. `releaseApproved` stays FALSE.
- [ ] Exact next engineering milestone: a separately rights-cleared,
  reviewed anatomical rest rig with verified camera registration —
  NOT implied by this screen-aligned original demonstration.

## W3b · Model-estimated world pose consistency (SOURCE IMPLEMENTED; DEVICE QA OPEN)

- [x] Thread MediaPipe 33-point hip-relative `worldLandmarks` through
  existing Worker/main inference as optional per-frame numeric data.
  The original image-space pose and W3a rig remain unchanged.
- [x] Reject malformed present worker-world coordinate arrays and
  mismatched/nonfinite payloads in the existing fail-closed worker gate.
- [x] Pure `Web/src/world-pose.ts`: paired confidence-gated points,
  actual cover-crop/front mirror, in-plane weighted similarity fit,
  degenerate/missing/outlier reporting and deterministic tests.
- [x] Add compact EN/ZH diagnostic-only consistency indicator under the
  existing collapsed camera diagnostics.
- [ ] Verify real worldLandmark delivery and meaningful output on
  physical Chrome/iPhone Safari hardware.
- [ ] Follow-up: calibrated camera intrinsics/extrinsics, depth-aware 3D
  reprojection validation and a reviewed, legal anatomical rest rig.
  W3b's 2D fit is NOT camera calibration, real bone length or 3D AR.
- [ ] Asset rights, model weight redistribution and SDK privacy review
  remain separate public-release blockers.

## W3c · Explicit perspective reprojection and simulated camera self-check (SOURCE IMPLEMENTED)

- [x] Pure, strict camera intrinsics and world-to-camera rotation/translation
  hypotheses with +Z-forward pinhole projection and correct cover/mirror display.
- [x] Frame/session matching, right-handed rigid matrix and positive-depth gates,
  >=6 matched points, nondegenerate observation spread, weighted RMSE/p95 and
  inlier ratio; any malformed or behind-camera candidate is rejected.
- [x] All results enforce `cameraCalibrationApproved: false` and
  `anatomyOverlayApproved: false` — mathematical consistency NEVER unlocks a
  third-party anatomical mesh or 3D AR claims.
- [x] Add a camera-free, bilingual, accessible synthetic geometry self-check
  inside the existing folded diagnostics, and fix the previously overlapping
  W3b metrics by using one readable panel.
- [x] Add numerical and browser emulation regression tests using only authored
  fixtures; no production pose injection and no third-party assets.
- [ ] Source CI / opt-in Chromium + WebKit hosted browser verification (see PR).
- [ ] Real camera intrinsic/extrinsic measurements, verified calibration target,
  true 3D registration and model rights remain separate W3d+ gates.
  See [W3C_CAMERA_REPROJECTION.md](W3C_CAMERA_REPROJECTION.md).

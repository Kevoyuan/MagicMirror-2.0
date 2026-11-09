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

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

## 10. W2b source-part explorer & rights-evidence boundary (2026-11-09)

The Web-local anatomy study now supports **original-source mesh**
list/search, source hierarchy breadcrumbs, user-controlled
per-mesh hide/show, temporary isolate, camera focus and whole-model
view reset. A list entry represents an actual parsed FBX/GLB mesh;
**never invent bone names or infer medical organ layers from the
source hierarchy**. Keep filtering/pagination deterministic and
bounded to protect mobile DOM; render untrusted source names with
`textContent`, not `innerHTML`.

Import is still **user initiated and local only**. Source file size
is limited to 75 MB; more than 2M triangles or 5,000 mesh objects
requires separate offline simplification. Pending asynchronous
imports are invalidated when the dialog closes. Preserve
independent show/hide preferences when exiting isolate mode.

A separate explicit **source inventory JSON** exports
SHA-256 of the selected original *bytes*, mesh paths and triangle
counts, original file size and actual skinned/joint counts.
All generated per-mesh `commercialReuseReviewed` values must
remain **false**, `licenseEvidence` null, and overall
`rightsStatus` **NOT_REVIEWED**. The metadata is a starting
point for substantive human license/author audit, not a commercial
authorization. Do not auto-import its flags as legal signoff or
upload the JSON. No model geometry is included in the inventory.

## 11. W2c actual source rig inspection and animation preview (2026-11-09)

In the private, user-selected **FBX/GLB static research viewer**,
it is permitted to inspect **actual authored** Three.js
`SkinnedMesh`, joint hierarchy, `skinIndex`/`skinWeight`
attributes and built-in `AnimationClip` data. **No automatic
weight generation, bone/organ classification or MediaPipe
retargeting is implemented by this.**

`Web/src/rig-diagnostics.ts` performs **bounded sampling** of
actual imported weights and joint references, reporting missing
weight attributes, unweighted/invalid sampled vertices, joint
indices outside the authored skeleton and suspicious sample weight
sums. It is a research diagnostic, not a complete binding,
clinical, anatomical, provenance or commercial authorization
pass. Do not invent rig data for raw Z-Anatomy FBX.

User-selected model animations can preview in the **separate
static-model study viewer** via Three.js AnimationMixer. Do not
autoplay clips when importing models, visiting the page or
granting camera permission. Pause when closing the study modal,
discard old actions when replacing imported files, and never
confuse authored source-file clips with real-time body tracking.

Optional rig-sample diagnostics in the **user-exported** JSON
must remain explicitly `samplingOnly: true` with overall
`rightsStatus: NOT_REVIEWED`, even if the imported GLB has
well-formed weights or animations. Public model distribution and
true body-to-camera skeletal AR remain separate human-reviewed
milestones; no Android/native iOS resumption.

## 12. W2d original-mesh to observed pose segment DRAFT mapping (2026-11-09)

The static local anatomy viewer now has a manually edited
mesh-to-MediaPipe surface reference segment table. Each source
mesh is identified by its exact original-array `sourceIndex`,
source name/path/triangle count and the original FBX/GLB
`SHA-256` + byte size, **not** by a guessed bone label.
A reviewer can map multiple actual source meshes to one of
the 12 *existing observed surface pose segments*. Import must
reject unknown/mismatched SHA, missing parts, original name/path
changes, duplicate entries, unsupported segments, fake rights
review metadata, and unknown schema fields, then apply the
validated draft **atomically**. User-triggered export remains
local JSON without source mesh geometry or camera data.

All mapping state is **USER_DRAFT_UNCALIBRATED**; original
coordinate axes, rest pose, true 3D joint anchors, mesh skinning,
per-mesh source rights, calibrated camera extrinsics, and
motion retargeting remain unverified. Never interpret these
assignments as proof that Z-Anatomy bones will follow a person.
Keep the public distribution release gate FALSE. Neither this
draft nor a source name authorizes public model publication.

Before W2e, build a separate explicit rest-pose/anchor review
and independent error-bounded simulation. No direct live-atlas
AR activation without human anatomical rig and permission gates.

## 13. W2e local source-model 3D point drafts (2026-11-09)

In Folio II, after the user maps an ORIGINAL source mesh to
one of the 12 MediaPipe SURFACE segments, the user may explicitly
select a **start** and **end** point on that same visible mesh via
Three.js raycasting. Record the hit coordinates in the original
loaded root object's local coordinate frame, **not** normalized
viewport, not phone camera coordinates, and not a measured
human bone/joint position. This does NOT by itself create a
valid articulated skeletal rig, verified anatomical rest
pose, vertex weights or physical 3D/body calibration.

`Web/src/atlas-anchors.ts` is the gate for its explicit
locally exported/imported JSON. Require exact original model
SHA-256/byte size/mesh IDs/paths/triangle counts and **current
user-provided** pose-segment mapping. Every exported entry
must say `USER_SELECTED_UNCALIBRATED`, with
`calibrationStatus=MANUAL_POINTS_NOT_CALIBRATED`,
`sourceCoordinateFrame=ORIGINAL_ROOT_LOCAL_UNVERIFIED`,
`retargetingStatus=NOT_READY` and
`commercialReuseStatus=NOT_REVIEWED`. Reject forged
approval fields/overlapping or non-finite endpoints and
import only after the ENTIRE file validates. Invalidate
points when its mapping is changed, original model is
replaced, or the entire mapping JSON is replaced.

Require user interaction before each sample; only actual
raycast source mesh hits may set a point, and a mesh hit
on a **different** source object must be ignored. Animations
should be paused before authoring these reference points.
The original source coordinate system and actual anatomical
rest pose are UNVERIFIED, including any potential
animation deformation at sample time. No automatic upload,
persistent camera data, source mesh redistribution,
live overlay activation or iOS/Android work.

Next: validate real body-to-mesh camera frame and joint
hierarchy with **known original source anatomy**, then
implement a bounded replay/simulation rather than
claiming actual calibrated 3D human anatomy.

## 14. W2f reversible ONE-mesh rigid source-preview only (2026-11-09)

Continue the **Web-first open-source** product, keeping iOS
frozen and Android canceled. After a real user selects a
NON-SKINNED original mesh, manually assigns a W2d MediaPipe
surface reference segment, and selects distinct W2e source
A/B points, enable an **explicit click-only local experiment**:
rotate this one original mesh rigidly around A by at most
±90 degrees about an **original-model-root X/Y/Z axis**.
B is a reference direction/endpoint and marker, NOT an
anatomically verified skeletal joint. A/B are not camera,
world-measured human or medically meaningful coordinates.

`Web/src/rigid-preview.ts` is the pure, testable matrix
foundation: `P_parent^-1 * R_root * D_pivot * R_root^-1
* M_mesh_original_world`. Each slider update MUST start
from an immutable original mesh matrix/world transform,
not compound on the already-previewed result. Restore
the original matrix AND `matrixAutoUpdate` state on
reset, cancel, model change, hide or modal closure.
Never rewrite the original imported geometry or disk file.

W2f is **only for exactly ONE plain Mesh at a time**.
Reject any selected `SkinnedMesh`, **any model with
authored animation clips**, missing/overlapping anchors,
nonfinite/oversized angle, hidden mesh, or missing source
model; never blend the preview with an `AnimationMixer`.
No camera input, online access, skinning/weight generation,
joint hierarchy, multi-part skeletal parenting, medical
measurements, body-pose retargeting or atlas public release
is authorized by this feature. Keep all real bone/asset
rights gates fail-closed.

Synthetic TS/Vitest matrix identity, arbitrary transformed
source-parent frame, rotation pivot and no-accumulation
tests must pass. A green CI **does not replace** real
Chrome/Safari source model import, WebGL interaction or
physical 3D calibration.


## 15. W2g original-source virtual hierarchy research (2026-11-09)

**Active platform is Web, iOS code remains frozen, Android canceled.**
A W2g virtual joint graph is an explicitly user-authored study of
2–12 original, separately mapped NON-SKINNED source meshes with
two distinct W2e points per mesh. Each node records an ORIGINAL
source mesh ID, optional manual parent source mesh ID, an unverified
source-root point A/B, a source X/Y/Z axis, and a bounded ±90° angle.
Graph validation MUST reject cycles, duplicate parts, unselected
parents, invalid points/axes, oversized inputs and unbounded angles.

Parent-child transforms MUST follow the documented pure kinematic
formula using immutable original source-root coordinates, not
camera frames. W2g renders **independent THREE.js ghost Mesh objects**
sharing the source geometry without changing original mesh transform,
hierarchy, material, visibility, vertices, skinning or authored
animations. Do NOT dispose shared geometry when clearing ghosts.
The local original FBX/GLB remains untouched; preview is memory-only.
Ghosts must disappear after modal close, source change, mapping
or point changes, and should be reset on source-visibility edits.
If the source includes authored animation clips or any selected
part is SkinnedMesh, fail closed and keep the original model
viewer available.

Do not infer the parent from bone names or treat manual source
mesh hierarchy as a validated anatomical skeletal rig.
A large start-to-parent-end distance is a STUDY warning,
not proof of anatomical attachment. This is neither
3D body calibration nor MediaPipe retargeting, X-ray,
patient anatomy, redistributed Z-Anatomy geometry nor
commercial rights authorization. Continue blocking public
release until per-mesh rights and Google model-weight
privacy/redistribution evidence and actual physical device QA.


## 16. Original, zero-download Web movement tutorial (2026-11-09)

A user-triggered **original three-box movement fixture** is
permitted in the private Web Folio II. It must be generated
from MIT-licensed MagicMirror code, with NO actual human
bones, external Z-Anatomy/BodyParts3D geometry, model
downloads, image recording or camera input. The generated
self-contained local GLB must pass the SAME file/SHA/mesh
import pipeline and real names as user-selected files.
The authored fixture owns its source-local A/B points,
three original mesh names and simple virtual parent links,
but is not evidence of anatomical joint hierarchy,
skeletal skinning, 3D camera calibration or commercial
redistribution rights for ANY third-party source.

Synthetic fixture metadata may prefill W2d/W2e
mappings/points solely for this example; no unreviewed
anatomy file is included and no user-created mapping
is silently uploaded or persisted. The tutorial
must be opt-in via a direct button, explain the
three **boxes** are not bones, and leave public
anatomy/model release approval locked.


## 17. W2i deterministic source-angle keyframe study (2026-11-09)

Only the PRIVATE Web Folio II virtual source chain is allowed
to capture local angle keyframes. W2i frames contain bounded
`timeMs` (0–10,000), at most 32 deliberately user-authored
frames and 2–12 explicit source mesh IDs with source X/Y/Z
axis and degrees ±90. `Web/src/study-timeline.ts` checks
strictly ascending unique times, exact authored graph
signature (source part ID, manual parent, original model
A/B, axis), and original source FBX/GLB SHA-256, file byte
size and mesh count. Enforce all-or-nothing import, reject
unknown authorization, camera/medical rights flags and
invalid/extreme angles. No image, imported geometry
or live camera pose is recorded or bundled in the JSON.

Interpolation must remain **deterministic linear angle
interpolation** with per-node axis fixed across frames.
Apply all source chain nodes in ONE batch renderer update
per animation frame, never 12 separate render passes.
Pause on background, dialog close, source/mapping/anchor
edits and user Stop. Changing selected graph parent or
axis INVALIDATES existing keyframes, not silently
retarget them to a new source. Release any pending
requestAnimationFrame. A synthetic 3-bar fixture may
include original authored test keyframes (not human
recordings), opt-in only. Keep camera/clinical
retargeting and per-mesh third-party licensing
completely separate and fail closed.


## 18. W2j original-demo opt-in browser smoke (2026-11-09)

Ordinary CI **remains fast** and does NOT run Chromium. For a developer
browser check, run `cd Web && npm run test:browser` after installing
Playwright's Chromium browser, or trigger the existing
`Web-first MVP` workflow via GitHub's **Run workflow** menu.
Opt-in PR branches containing `browser-smoke` also run the
separate Chromium job in that SAME workflow.

`Web/tests/browser/original-demo.spec.ts` opens the actual Vite
page in headless Chromium and exercises only original, browser-
generated MIT-labeled three-box GLB, real GLTFExporter/GLTFLoader,
Three.js WebGL, static reference chain UI, short angle replay
and local SHA-bound timeline JSON export/re-import. It tests
refusal of a forged SHA on import while retaining prior frames.
It must NOT click Start Camera, record camera content,
download or bundle actual Z-Anatomy assets, fetch Google
PoseLandmarker weights, trigger analytics or claim public
model distribution authorization. Failure screenshots/traces
can only contain this original generated study geometry;
do NOT use these test artifacts for sensitive camera files.
Browser E2E is a stronger runtime integration test than Vitest
but its GitHub hosted Chromium software rasterizer cannot
substitute for actual iPhone Safari/desktop camera,
thermal/latency, accessibility or source-anatomy validation.

W2j acceptance evidence: the opt-in pull-request Chromium job
completed with **3/3 Playwright tests passing** on GitHub-hosted
Ubuntu 24.04 with software WebGL on 2026-11-09:
https://github.com/Kevoyuan/MagicMirror-2.0/actions/runs/42651083351 .
Use this as an integration confidence signal **only**; none of
the restricted release, physical iPhone Safari, real camera or
original anatomical asset gates are changed or cleared.

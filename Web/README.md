# MagicMirror Web — open-source research MVP

**Active product platform (2026-11-08).** New `Web/` code is MIT-licensed.
The native SwiftUI/Metal iOS source remains in the repository **frozen**,
and Android is not planned. The early Web MVP draws a real Three.js **3D
procedural cylinder/sphere proxy** on top of browser camera video aligned
to the corresponding 2D MediaPipe image landmarks. This is **not**
a Z-Anatomy anatomical atlas, calibrated camera depth or person-specific
skeletal reconstruction.

## Run locally

Use Node.js 22+, current Chrome/Edge/Safari browser, local camera and WebGL.

```bash
cd Web
npm install
npm run stage:assets   # developer-time download of pinned .task and copying pinned npm WASM assets
npm run dev
# Visit http://127.0.0.1:5173/
```

Allow camera access when prompted. The browser uses the rear camera where
available (`facingMode: environment`), with a manual flip button; desktop
webcams work as a best-effort fallback. Camera access on public sites
requires **HTTPS**, while local loopback localhost is exempt.

The `stage:assets` command verifies that the separately hosted Google
PoseLandmarker Lite task is exactly **5,777,746 bytes** with SHA-256
`59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a`
and places it into `Web/public/models/`. Matching WASM assets are copied
from pinned `@mediapipe/tasks-vision@1.2.2` into
`Web/public/wasm/`. All downloaded binaries are gitignored, not
automatically checked into the open-source repository. No Python,
Unity, native app or backend is needed in the browser.

If `npm run stage:assets` fails, review upstream package/model URLs
and hashes instead of weakening verification. The `latest` download
URL is mutable; changed model bytes fail the developer staging script.

## Web UI design — Leonardo notebook v2.0 (source implementation)

The active [Web design contract](../DESIGN.md) supersedes the archived
SwiftUI-only visual handoff. The live camera remains the primary view;
no dashboard or account layer has been introduced.

- The mobile header keeps the brand, language toggle and real pose status
  on one compact row while respecting browser safe-area insets.
- Whole / Arms / Legs remain directly reachable; **Opacity** uses a native
  collapsible `<details>` control. The four existing actions retain
  keyboard focus and 44px minimum targets.
- Local inference diagnostics are available on demand, not constantly
  drawn over the live camera. Their numbers are process/output timings,
  not display FPS, medical measurements or sensor latency.
- A visible proxy limb can show an original educational note. The note
  initially shows a short title; **Read anatomy note** expands its
  explanation. The card and active camera guidance are not displayed
  on top of one another.
- The Anatomy / Privacy dialogs and static FBX/GLB study viewer render
  as scrollable parchment bottom sheets on narrow touch viewports,
  retaining native `<dialog>` close and Escape behavior.
- The layer folio now displays the **working proxy** and local file
  action before the longer rights explanation. Genuine multi-system
  AR layers stay unavailable until licensed, rigged and registered.
- English and Simplified Chinese disclosure labels are built from local
  `Web/src/i18n.ts`; user-provided source mesh filenames are never
  translated or uploaded.

**UI acceptance still open:** check real Chrome / Safari desktop and
iPhone Safari safe areas, screen reader and keyboard flow, browser zoom,
camera layer alignment, overlay-note interactions and 70% camera-stage
composition target on a representative portrait phone. CI source build
does not establish real-device UX or asset publication rights.

## Honest implemented features

- Browser `getUserMedia` with an explicit click/permission flow,
  camera flip, stop tracks, stop on tab background, and restart.
- Worker-first MediaPipe Tasks Vision `VIDEO` inference with
  transferable ImageBitmap and one-in-flight, ≥75ms sampling gate.
  Unsupported Worker/OffscreenCanvas browsers fall back to throttled
  synchronous main-thread inference. A worker helps UI responsiveness;
  it does not prove frame-perfect camera alignment. The source compiles
  in CI; cross-browser runtime confirmation is still needed.
- Partial arms/legs can render when confident even if full body is
  outside the frame; avoid filling low-confidence or missing joints.
- Three.js WebGL volumetric proxy (not an anatomical mesh) follows
  `object-fit: cover` projection and selfie mirror transformations.
- Whole / Arms / Legs focus, overlay-only pause, opacity, status,
  optional **explicit** locally downloaded PNG photo (with a visible
  nonmedical label), and a disclosure-only layer catalogue.
  App source never automatically records/saves/uploads images.
  Anatomy systems remain
  **disabled/not available** until real legal/rig/alignment acceptance.
- Measured pose output frequency, inference duration p95 and
  local capture-request-to-result delivery p95; **not** screen FPS,
  motion-to-photon latency or camera-based bone measurements.
- Local code does not upload or *automatically* save camera images or pose history.
  Google's MediaPipe SDK may send **performance/utilization metrics**.
  Review the package privacy notice and applicable user consent duties.

Tests use synthetic landmarks: `npm test` and
`npm run typecheck`. The CI-only `npm run build:code` bundles Web
source **without** requiring actual Google task/WASM binary or validating
rights; that output is **not a functioning release without staged assets**.

## Public release is not authorized yet

`npm run build` intentionally runs BOTH `check:assets` and a separate
**fail-closed** `check:release`. The committed
`Web/release-clearance.json` is `releaseApproved: false`.
Obtain a qualified review of the actual Google task **model weights**
redistribution rights (distinct from Apache-2.0 SDK), SDK dependency
notices, browser metrics/privacy consent and accurate site statements.
Only then document real legal evidence and approve public deployment.

**No Z-Anatomy FBX, BodyParts3D mesh or altered skeleton files are
distributed by this MVP.** CC BY-SA permission for particular reviewed
components does not authorize NC/unknown parts. Opening the repository
does not automatically license or grant model redistribution rights.
A future separate `Assets/` release may share reviewed derivatives
under CC BY-SA on their own terms.

## Architecture

```text
Browser camera <video> / CSS object-fit: cover
        | source frame, timestamp, videoWidth/Height
        v
 MediaPipe VIDEO / on-device single-person 33 landmarks
        | confidence > threshold; no stale/spurious joints
        v
 screen-space cover/mirror mapping  → Three.js translucent 3D proxy
        |                                  |
        +--------------------------> transparent WebGL <canvas>
                                      over same HTMLVideoElement
                                      → Leonardo folio controls
```

The live video may advance while synchronous pose inference runs, so
this is **not** guaranteed pixel-exact video ↔ 3D overlay association
and the overlay is **not camera-calibrated 3D anatomy**. Real model rig,
body-to-camera alignment, latency, occlusion and physical phone tests
remain future milestones.

See [architecture](../Docs/WEB_ARCHITECTURE.md),
[active roadmap](../Docs/WEB_MVP_ROADMAP.md),
[platform ADR](../Docs/ADR-003_WEB_OPEN_SOURCE_FIRST.md).

## Open-source license

`Web/LICENSE` (MIT) applies to newly authored Web app source only.
Google MediaPipe SDK (Apache-2.0), task weights and any later anatomy
data have their own terms. Existing `Mobile/iOS/`, `Unity/`,
`Tools/` and historical research are **not** relicensed by this file.

## W1 controls and verification (2026-11-09)

The owner reported testing the initial Web MVP; no specific camera
device/browser logs or measured acceptance were supplied. New W1 code
adds `LivePoseInference`, `pose.worker.ts`, latest-only frame
ordering/freshness checks, worker start/stop cancellation, track-ended
recovery and local telemetry. Test with desktop Chrome and iPhone
Safari; watch for Worker fallback, permission denial, camera flip,
landscape rotation, background/restore and clipping.

The **Save image / 保存画面** button creates a PNG of the visible,
mirrored/cropped camera and the current Three.js proxy, marked
"Illustrative 3D proxy / NOT X-ray". It is opt-in and stored only
when a user explicitly downloads it. Do not use these images for
medical decisions. No remote snapshot or recording API exists.

## W2a: Explore a LOCAL Z-Anatomy FBX or GLB (2026-11-09)

Click **解剖图层 → 导入本地 FBX / GLB 解剖模型**.
Choose a file already on *your* computer (for example, the
source-pinned `SkeletalSystem100.fbx` fetched separately from its
original rights-holder). This model is **not** uploaded or
automatically distributed. A separate static 3D viewer opens while
the camera is stopped:

- Drag to rotate, scroll/pinch to zoom, tap a mesh to inspect its
  actual source hierarchy/name; the mesh/triangle count is measured.
- Show/hide wireframe, vary opacity and move a true GPU clipping plane
  along **X/Y/Z of the original model frame**. The labels are
  visual study controls, *not verified medical anatomical planes*.
- Look at the report's **SkinnedMesh** and actual authored joint
  counts. An unrigged Z-Anatomy source may show zero. It cannot
  follow your body in this state.

File bounds: 1–75MB, FBX or self-contained GLB, ≤2M triangles.
A very large FBX may hang a slow phone while parsing; desktop Chrome
is recommended for first investigation. Textures requiring external
files are intentionally replaced with a local placeholder instead
of silently making network requests.

**Licensing:** you choose your own copy of an anatomy file.
The project does not provide, automatically download, bundle, share,
sublicense or publish that file. A personal local inspection does
not grant redistribution rights; an actual public anatomy overlay
remains gated by per-component source licenses, human-reviewed
joint hierarchy, real rig/weights, camera/pose registration,
occlusion and mobile performance.

## Interactive anatomy notes

When the live educational **3D proxy** is visible, click/tap a
rendered arm, forearm, thigh, shin or torso reference segment to
open a compact Leonardo field-note card. It contains Chinese
and English *region* labels and a short factual anatomy note.
Close with × or allow tracking loss to hide the note. No
landmark or bone dimension is saved; these labels **do not**
represent scanned, diagnosed or personally measured bones.

Local FBX/GLB study mesh picking remains a different feature:
it shows the **actual mesh name** from the user-provided file,
not validated anatomical metadata. Truly animated, layered
Z-Anatomy remains a subsequent rights- and rig-gated milestone.

## Visual stability mode

Layers → **稳定显示示意骨架** is ON by default for the procedural
reference overlay. It adaptively smooths observed high-confidence
joints but deliberately drops missing/low-confidence landmarks
rather than guessing where a user's real bone might be.
Disable it for a direct visual comparison with raw MediaPipe pose
observations. Large one-frame teleports are hidden before reacquire.
Neither mode is a clinical measurement or calibrated 3D tracking.

## Chinese and English controls

The compact **EN / 中文** button in the top row switches the Web
mirror's core controls, feedback, privacy notes and interactive
educational cards using local UI strings, with no translation
server or camera data upload. The visible model source filenames
and mesh names remain unchanged. Some long-form/debug messages
still require manual translation QA before public release.

## W2b: Browse, isolate and export ORIGINAL anatomy source parts

Inside **解剖图层 / Anatomy layers → 导入本地 FBX / GLB**,
select a locally stored model. After import, the **Original meshes
and hierarchy / 原始部件与层级** panel shows each *actual* imported
mesh, its original hierarchy path and its triangle count.

- Search the imported source file's own mesh names and parent
  hierarchy paths. Initially show up to 60 matching meshes;
  **Show more** pages through matching parts without rendering
  thousands of DOM rows at once.
- Click a mesh name to inspect/highlight it; toggle its checkbox
  to hide or show, use **◎** to isolate the part, and **⌕** to
  focus the orbit camera on its actual geometry.
- **Exit isolate** restores per-part visibility preferences.
  **Show all** enables all source meshes; **Reset view**
  restores the whole-model camera without changing the model.
- **Export source inventory JSON** is an explicit local download,
  with original selected model file SHA-256, byte size and all
  imported mesh hierarchy/triangle/skinning statistics. It
  contains **no geometry**, and every mesh's rights remain
  `commercialReuseReviewed: false`,
  `licenseEvidence: null`, with overall
  `rightsStatus: NOT_REVIEWED`.

This inventory is useful to start a real human provenance,
copyright and authoring/rigging audit. It **does not grant
commercial rights** or clear a source FBX for redistribution.
The software neither hosts nor auto-downloads local models.
A signed, reviewed 3D anatomy overlay remains later work.

Current file limits: ≤75 MB, ≤2 million triangles and ≤5,000
source meshes. Desktop browsers are recommended for original
large FBX study; no actual Z-Anatomy import/device FPS
performance is claimed until separately measured.

## W2c: Test authored bone weights and file-contained animation locally

Inside the **local-only anatomy study** dialog, the
**Rig and authored animation diagnostics / 绑定与动画诊断**
panel reports the actual imported model's SkinnedMesh and
joint count. If the model contains weight attributes, it
**samples** vertices (does not exhaustively audit all vertices)
for missing weights, invalid weight values, out-of-range joint
references, and suspicious influence sums.

With a rigged model containing **its own authored animation**,
choose an animation from the file and press Play/Pause. This
plays only the source model's authored clips in the separate
static inspector; it does **not** reflect your body motion.
Imported models with no valid clips display a disabled player.
No animation autoplays by opening or granting camera access.

The local **Export source inventory JSON** also records the
rig-sample diagnostic, explicitly `samplingOnly: true`,
and overall original-mesh rights remain `NOT_REVIEWED`.
For an original unrigged Z-Anatomy skeleton FBX the
expected diagnostics may show *zero* authored skinned meshes
and *no* compatible clips: **this does not mean the camera
prototype is rigged or a medical observation**.

Actual GPU skin deformations and clip playback still need
physical browser validation. A real tracked anatomical
skeleton requires an independently authored cohesive rig,
pose-to-joint retargeter, anatomical camera registration,
per-part rights signoff and measured performance.

## W2d: Manually map original source meshes to pose segments

In **Anatomy layers → Load local FBX / GLB → Original meshes and
hierarchy**, each imported source mesh row now has a dropdown:
**Unassigned** (default), or one of the **12 visible
MediaPipe surface-reference segments** (upper arms, forearms,
thighs, shins, torso/shoulder/hip spans). This is a manual
study draft; several source parts may share a segment.

Choose mappings explicitly, then click **Export mapping draft**
to save local JSON. Later, after choosing the *identical*
original model, use **Import local mapping JSON**. The importer
checks original source SHA-256, file size, actual mesh list
count, original source names, hierarchy paths, triangle counts,
valid segments, duplicates and forged approval fields.
A failure leaves existing assignments unchanged. The local
mapping can be cleared at any time.

The JSON includes **no original vertices, no camera images, no
source assets, and no redistribution/license grant**.
Every entry is `USER_DRAFT_UNCALIBRATED`; overall model-space,
retargeting and commercial clearance remain
`UNVERIFIED / NOT_READY / NOT_REVIEWED`. This is a foundation
for proper rig authoring, not an active real-time Z-Anatomy
skeleton overlay and not validated physical anatomy.

## W2e: Click actual source-model reference points

**Local model study → Source-part list → choose a real mesh and
its manual surface segment → Mark point A / Mark point B.**
For each endpoint, click the **SAME visible source mesh**
in the separate 3D study canvas. Isolate the part if
other meshes hide it. The viewer saves the user's own
clicked **original model-root local 3D coordinates**,
not coordinates from the person's camera image.

The control shows how many source parts have both
distinct points, and how many are still incomplete.
**Export point draft** produces explicit local JSON;
**Import point JSON** only accepts matching original
source SHA-256, size, source mesh IDs/paths/triangles
and the currently manually chosen pose segment.
A mapping edit, mapping re-import or new original
model invalidates earlier points.

These are user-selected source-model **reference
points only**. No actual anatomical rest pose,
skinned joint transform, MediaPipe-to-bone live
retargeting, camera extrinsics, calibrated slice,
model redistribution or medical validation is
implied. Pause authored animation before picking;
positions on an already-deformed paused model
are not necessarily rest coordinates. The JSON
includes no source geometry or camera images
and explicitly marks calibration and rights
as **NOT READY / NOT REVIEWED**.

The real original Z-Anatomy FBX and mobile Safari
performance still require physical browser QA.

## W2f: Reversible local single-part motion experiment

Inside the PRIVATE **Anatomy study** viewer:

1. Import a user-owned original FBX/GLB. Select a
   visible **ordinary non-skinned mesh** and manually
   assign it to a MediaPipe 2D surface-reference
   segment in the source parts list.
2. Mark two different original-root points A and B
   on that SAME part (W2e). **A** acts as the pivot;
   **B** is a movement reference (not a biological joint).
3. Click **Start local rigid preview** in the new
   **Single-mesh rigid rotation** panel. Choose a
   **SOURCE X/Y/Z axis** and move the ±90° slider.
   Only that source mesh rotates; a B marker follows
   its synthetic rigid movement.
4. Click **Restore original pose**, select a
   different mesh or close the viewer to reset the
   original matrix exactly. No animated or changed
   source FBX/GLB is exported.

This experiment does **not** support an already skinned
mesh or a model containing authored animation clips;
such files should continue to use the separate
authored-animation player. There is **no live
MediaPipe-to-mesh retargeting**, whole-skeleton rig,
physiological range-of-motion calibration, camera
registration or model redistribution grant.

The W2f code has synthetic pure matrix tests and
source compilation checks. Real original FBX on
desktop/iPhone browsers, GPU latency, exact
reference orientation and multi-bone rig quality
require actual hardware and human anatomy review.


## W2g: Study a manual multi-mesh movement chain (not actual anatomy AR)

In the PRIVATE source-model study dialog, import your own FBX/GLB,
select a **plain** original mesh, map it to a MediaPipe
surface-reference segment and click A/B on that actual
mesh. Repeat for at least two and at most twelve parts.

Select each source mesh and click **Add selected mesh**
in the **Multi-mesh virtual chain** panel. For a child,
choose another selected mesh as its **manual parent**.
The app rejects cycles and invalid/unaligned identities;
far-apart endpoints are reported as a geometric warning.
Click **Preview virtual chain**, then click a node
in the small chain list and use the X/Y/Z ±90° slider.
Child **golden wireframe ghost geometry** follows the parent
while original FBX/GLB mesh geometry and transforms stay
unchanged. **Zero all angles**, Stop, a source/mapping
change or closing the dialog ends the study. Nothing is
uploaded, saved automatically or rendered over the live
camera as actual internal anatomy.

Source models with authored animation clips or selected
SkinnedMesh are not eligible; use the separate authored
animation inspector. This does not create a rig,
generate skinning or reconstruct a patient skeleton.
Real hardware/Safari tests, actual source permissions,
rest-pose semantics and camera space are still open.


## One-click ORIGINAL demo (no Z-Anatomy source needed)

Open **Anatomy layers → Local FBX/GLB viewer** and
choose **Try an ORIGINAL 3-part 3D demo**. MagicMirror
generates three simple box-like parts in this browser
and imports its own tiny self-contained GLB. It
prefills a three-part tutorial-only source mesh
mapping, reference A/B points and an example
parent/child chain, then shows the gold wireframe
ghost pose. Click node chips to select one segment,
adjust model-space X/Y/Z angle, Zero all or Stop.
You can still inspect the original mesh list and
try local JSON source inventory export.

This generated scene consists of **three simple
rectangular bars**, NOT bones or organs, NOT a
clinical atlas, NOT Z-Anatomy, and NOT a webcam
or true pose retargeting feature. No third-party
FBX is automatically downloaded or distributed.
Full GLB export/import and WebGL interaction
must still be verified in real Chrome/Safari.


## W2i local keyframe editor and loop

Start a W2g virtual 2–12 source-mesh chain. In
**Local angle keyframes & loop replay** choose
a time on the 0–6s slider (up to 10s for
imported drafts), set per-node angles in the
virtual chain panel, then click **Capture
current angles**. Capture another pose at a
different time. **Loop playback** interpolates
the TEST ANGLES only, **Pause** stops,
and dragging the timeline scrubs a static
virtual pose. Frame chips jump to authored
positions. You can delete a frame, clear
them all, or explicitly download/reimport
a model-hash-bound JSON draft.

The original three-box demo already includes
three synthetic training frames at 0s,
1.5s and 3.0s. It never captures camera
frames. All source file SHA/size, original
mesh identity, parent chain, A/B points
and rotation axes must match to import
old keyframes. Import rejects any false
medical/camera or rights signoff. Editing
the parent structure or an axis invalidates
the old frames; hidden tabs/closing the
viewer pause replay.

This is **NOT** live MediaPipe motion
retargeting, a human joint motion log,
a licensed bone or a medical scan.
Run a real browser interaction test
before considering it hardware verified.


## W2j: Optional real Chromium browser integration test

For an actual desktop-browser runtime smoke of
the ORIGINAL three-box tutorial (no webcam, no
external anatomical geometry or Google task
model weights):

```bash
cd Web
npm install --legacy-peer-deps
npx playwright install chromium webkit
npm run test:browser
```

Playwright opens a local Vite server; it checks
the exact production study UI, GLB exporter/loader,
software WebGL, virtual multi-part chain and
keyframe replay, explicit local SHA-bound JSON
download, forged-source rejection and valid
re-import. Tests never press the webcam button.

Ordinary GitHub Web CI still does only the
fast TS/Vitest/build/release-denial checks.
Run `Web-first MVP` manually via GitHub Actions
or open a PR branch containing `browser-smoke`
to opt into the heavier Chromium job in the
**same workflow**. Browser smoke is not a
publicly deployable release, not Z-Anatomy
usage permission and **not physical iPhone Safari
or real camera acceptance**.

Browser CI pins **Ubuntu 24.04** for Playwright's supported Chromium
runtime; ordinary source checks continue on the current GitHub
default runner. The browser smoke is specifically software WebGL,
not an iPhone/physical GPU performance or medical anatomy acceptance.

**First verified browser smoke (2026-11-09):** all **3/3**
Playwright tests passed on GitHub-hosted Ubuntu 24.04
Chromium with software WebGL and no webcam permission:
https://github.com/Kevoyuan/MagicMirror-2.0/actions/runs/42651083351 .
This is real browser execution of the original generated GLB,
not a confirmation of Safari/iPhone or original Z-Anatomy FBX behavior.

### W2k: Original-demo mobile-browser engine coverage

The opt-in suite now runs **six** real browser checks:
three on desktop Chromium and the same three on
Linux WebKit using an **iPhone 13 viewport and touch
emulation**. GitHub-hosted Ubuntu 24.04 verified
**6/6 passed** for the original generated GLB,
model-space ghost chain, timeline replay and
source-locked local JSON on 2026-11-09:
https://github.com/Kevoyuan/MagicMirror-2.0/actions/runs/42652358053 .

This is meaningful desktop/mobile browser-engine
integration confidence, but **not** a physical
iPhone Safari camera/WebGL performance result.
Real Z-Anatomy licensing, original FBX import,
medical/camera calibration and public release
review are not cleared by these tests.


## W2l: save and restore one local study session

Instead of downloading and re-importing the separate mapping,
endpoint and keyframe JSON files in the right order, open
**Anatomy layers → Local FBX/GLB viewer** and use
**Local study session · one-file atomic restore**.
**Export study session** writes ONE local JSON containing the
current manual mapping, source A/B points, virtual chain and
angle keyframes (or an early mapping-only state). It contains
no model geometry, camera image, authored clip, author license
or rights approval.

**Import study session JSON** first verifies the exact original
file SHA-256, byte size and mesh count, every original mesh
name/path/triangle count, each manual segment and A/B point,
the parent chain, axes and all frame times. It also refuses
hidden, skinned or animated source parts. ONLY if the whole
file passes does it replace the in-memory study state in one
step; a rejected file changes nothing. Import does not touch
the webcam, does not auto-start the ghost preview or replay,
and does not save anything by itself. Click **Preview virtual
chain** again to see ghosts.

A short **synthetic matrix replay** line reports whether repeated
source-root transform recomputation is bit-identical with zero
drift across keyframes and interpolation midpoints. This is a
numerical reproducibility check ONLY — not camera/body
calibration, anatomy accuracy, WebGL or real-device validation.
Real Chrome/Safari import, touch targets and GPU behaviour are
still unverified; true atlas overlay, per-mesh rights review
and public release stay blocked.


## W1c: a failed worker never reuses an old pose

The camera pipeline now has a small pure gate
(`src/inference-result.ts`) between the MediaPipe worker and the
renderer. It accepts a result ONLY when the worker is alive, the
frame is still the one in flight, the camera session still matches
and all timings, dimensions, inference cost and up to 33 landmark
numbers are finite and plausible.

On a worker crash, a 2s inference stall, a malformed CURRENT result
or a user stop, the engine immediately invalidates that in-flight
frame, terminates the worker and hides the stale reference. A late
`result`, `fatal` or `error` that arrives afterwards is ignored —
it can neither draw a reused pose nor kill the throttled main-thread
fallback that is already recovering. Bitmaps created while the
worker died are closed, and frame ids stay monotonic across the
fallback so the viewer does not mistake new frames for old ones.
A failure of main-thread inference itself still calls `onFatal`.

`src/inference-result.test.ts` and `src/inference.test.ts` cover
these paths with fake Worker / fake ImageBitmap / mocked MediaPipe
only, and Web CI checks that `vite build` produces the
`pose.worker-*.js` chunk. These are synthetic state-machine tests:
real Chrome/Safari WASM loading, ImageBitmap transfer, worker crash
recovery, GPU behaviour and measured latency on physical devices
remain unverified. The public release gate stays FALSE.


## W3a: opt-in LIVE ORIGINAL articulated rig (experimental 2.5D)

Open **Anatomy layers** and you will find a new **Live overlay mode**
radio group. **Reference Proxy** is the DEFAULT and remains the
independent-line-segment skeleton from W0. Selecting
**Live Original Rig (Experimental)** switches the same camera overlay to
a completely ORIGINAL, procedurally generated Three.js articulated
demonstration: a visible shoulder → upper arm → elbow pivot → attached
forearm chain for each observed arm, plus an optional shoulder-to-shoulder
torso reference. No FBX/GLB, Z-Anatomy/BodyParts3D mesh, Google weight,
camera image or personal data is used to build it.

What actually works:

- One camera stream and ONE existing WebGL overlay context are reused.
  There is no second renderer, canvas or always-running render loop.
- Live 33-landmark observations are projected into the same
  object-fit:cover, mirrored DISPLAY-PIXEL space as the proxy. The
  forearm is a CHILD of the upper-arm pivot, so the elbow stays coherent
  when the arm bends; every frame writes absolute transforms from
  immutable authored geometry (no cumulative drift).
- Partial body is fine: only confidently visible shoulder/elbow/wrist
  segments are drawn. A forearm with no visible shoulder is shown as an
  INDEPENDENT segment; no hidden joint is invented. Whole/Arms work;
  Legs deliberately shows nothing because no original leg chain exists.
- Stale, out-of-order, old-session, nonfinite or discontinuous frames
  hide the rig instead of freezing or reusing a previous pose. Camera
  stop/restart, flip, background tab, worker fallback, overlay pause,
  focus/stabilization/opacity changes all reset only the relevant state.
- All existing behavior stays available: camera start/stop/flip, mirror,
  partial-body tracking, confidence hiding, overlay pause, local-only
  explicit PNG capture, latency diagnostics and privacy behavior.
  New status/label copy is written locally in both 简体中文 and EN.
- The local FBX/GLB study dialog is unchanged and still STOPS the
  camera. Imported models are static research objects and are NEVER
  live-retargeted by this experimental mode.

What this is NOT: anatomical AR, a person's real bones, calibrated
camera-space 3D registration, depth measurement, skinning/skin weights,
inverse kinematics, clinical geometry, or redistribution approval for
any third-party anatomy asset or PoseLandmarker weight. MediaPipe `z`
is only checked for finiteness; it is never treated as camera depth.
The rig is explicitly labelled "Experimental · Uncalibrated".

Two ORIGINAL, camera-free UI screenshots of the explicit opt-in are kept
in `Docs/images/` for reviewers. They show only the locally generated
Leonardo interface, with the camera OFF, no pose data and no third-party
content; they are NOT evidence of live tracking or device acceptance.

| Locale | Screenshot |
| --- | --- |
| 简体中文 | `Docs/images/w3a-live-original-rig-mode-zh.png` |
| English | `Docs/images/w3a-live-original-rig-mode-en.png` |

### Verification

```bash
cd Web
npm install
npm run typecheck           # clean
npm test                    # 151/151 Vitest tests pass
npm run build:code          # source build only; NOT a public release
npm run stage:assets && npm run check:assets
npm run test:browser        # opt-in; needs Playwright Chromium + WebKit
```

`tests/browser/live-original-rig.spec.ts` is part of the existing
opt-in browser suite (manual dispatch or a `browser-smoke` PR branch).
It uses deterministic numerical 33-point fixtures through test-only
source imports inside `page.evaluate`; the production build has NO pose
injection hook. Camera stays off and no restricted binary is loaded.
Locally **12/12 passed**: 6 desktop Chromium + 6 iPhone-sized WebKit
ENGINE emulation checks, including the three preserved W2 tests on each
engine. The third W3a test mounts the rig through the REAL
`ProxySkeletonRenderer` (shared WebGL host) and verifies coherent world
joints across two consecutive frames. WebKit emulation is NOT physical
iPhone Safari, Apple GPU, camera permission or thermal acceptance.

`releaseApproved` remains FALSE. Real-browser webcam validation on
physical devices, per-mesh rights review, MediaPipe weight
redistribution clearance, SDK metrics privacy review, a reviewed
anatomical rest rig, real skeletal skinning and camera-space 3D
registration all remain separate blocked milestones. The exact next
engineering milestone is a rights-cleared, reviewed anatomical rest rig
with verified camera registration — not an extension of this
screen-aligned original demonstration.

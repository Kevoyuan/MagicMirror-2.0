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

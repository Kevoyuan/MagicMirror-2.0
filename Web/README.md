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

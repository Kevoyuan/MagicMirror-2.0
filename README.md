# MagicMirror 2.0

**Open-source Web Anatomy Mirror · Leonardo's anatomical field notebook**

**New direction (November 8, 2026): Web first, open-source.** The native
SwiftUI/Metal iOS project remains preserved but paused; Android
development is canceled. Browser-based camera tracking and live 3D
educational visualizations are now the active MVP.

Open the page → allow the camera → point at one person → see a
semi-transparent **Three.js 3D illustrative reference skeleton** follow
confidently observed body parts. This is an educational demonstration,
**not an X-ray, actual view of internal bones, calibrated bone scan or
clinical diagnosis**.

[Web MVP instructions](Web/README.md) ·
[Active roadmap](Docs/WEB_MVP_ROADMAP.md) ·
[Web architecture](Docs/WEB_ARCHITECTURE.md) ·
[Platform decision](Docs/ADR-003_WEB_OPEN_SOURCE_FIRST.md) ·
[Leonardo design](DESIGN.md)

## Start the Web MVP locally

Requires Node.js 22+, a webcam, WebGL and a browser served from
`localhost` (public deployments require HTTPS).

```bash
cd Web
npm install
npm run stage:assets
npm run dev
# Open http://127.0.0.1:5173/
```

`npm run stage:assets` copies the pinned MediaPipe WASM files and
retrieves a **SHA256-verified** developer-time PoseLandmarker task model.
Third-party binaries are intentionally excluded from Git. This
developer workflow is not proof that hosting those weights publicly
is permitted: see [rights & privacy](Docs/WEB_LICENSE_AND_PRIVACY.md).

**Implemented in Web source (W0–W3a):** camera start/stop/flip,
single-person pose inference in a **Web Worker** with a fail-closed
main-thread fallback (W1/W1c), partial-body confidence gates, the
translucent Three.js procedural proxy, video cover crop and front
mirror projection, Whole/Arms/Legs controls, opacity, overlay pause,
one-shot local PNG capture, latency diagnostics, the Leonardo paper
dock, bilingual 中文/EN copy, a local-only static FBX/GLB study
viewer with one-file study sessions (W2), opt-in Chromium/WebKit
browser smoke tests, and — new in W3a — an **explicit opt-in
"Live Original Rig (Experimental)"** Layers mode that drives a
completely ORIGINAL screen-aligned articulated Three.js demonstration
chain from live pose observations using the SAME single camera and
overlay WebGL context. `Reference Proxy` remains the default.

**W3a is NOT:** anatomical AR, real bones, camera-space 3D
registration, depth measurement, skeletal skinning or medical
imaging. It is an experimental 2.5D/screen-aligned articulation
milestone with honest bilingual limitation copy. See
[Web README](Web/README.md#w3a-opt-in-live-original-articulated-rig-experimental-25d).

**Not yet completed/verified:** real-browser webcam testing on
physical devices (headless Chromium/WebKit ENGINE emulation is not
iPhone Safari or Apple GPU acceptance), exact camera↔overlay frame
lock, medically reviewed anatomical skeleton, genuine Z-Anatomy
assets/rights, real skeletal mesh rigging and skin weights, physical
3D camera registration, section layers, hosted public release or
independent Google model weight redistribution clearance.

### Web CI versus a public release

```bash
cd Web
npm run typecheck
npm test
npm run build:code  # CI source compile only; assets may be absent
npm run build       # intentionally BLOCKED until model/privacy rights clear
```

The default `Web/release-clearance.json` remains explicitly
unapproved. Do **not** deploy an incomplete `build:code` artifact as
a functioning site. Public release must confirm third-party binary
distribution rights, SDK metrics/privacy disclosure, and HTTPS camera
behavior first.

## Repository and platform boundaries

| Source | Current status | Licensing |
| --- | --- | --- |
| `Web/` | **Active open-source product/MVP** | New Web source: MIT (`Web/LICENSE`) |
| `Mobile/iOS/` | Frozen; preserve existing code and Draft PRs #49–#53 | Historical rights retained; not auto-relicensed |
| `Unity/`, `Tools/` | Archived algorithm/rig/testing research | Historical rights retained |
| Z-Anatomy/BodyParts3D models | **Not bundled in Web W0** | Mesh-specific attribution/CC terms and NC exclusions still apply |
| Google MediaPipe Tasks + pose task | SDK used by Web; weights developer-staged locally | SDK and weight-license checks separate |

The core challenge remains: making a **genuinely reviewed, articulated
3D anatomical model** move with human body observations. W3a's original
procedural demonstration proves that a bounded parent-relative chain can
follow observations, but it does not supply a reviewed anatomical rest
rig, skin weights or camera extrinsics. Replacing iOS with Web simplifies
access and contribution, not the legal, kinematic or camera-registration
science.

### History (preserved, not active)

Earlier iOS milestones established a native AVFoundation, MediaPipe
and Metal prototype; iOS arm64 Simulator code builds were previously
recorded, but real iPhone camera behavior and a reviewed Z-Anatomy
full skeleton were never signed off. Those sources remain available
for future deliberate reactivation:
[iOS archive](Mobile/iOS/README.md) ·
[Paused mobile roadmap](Docs/MOBILE_NATIVE_ROADMAP.md) ·
[Archived iOS decision](Docs/ADR-002_MOBILE_NATIVE_OFFLINE_FIRST.md).

**Contributions:** start with `Web/`, respect the exact source and
license boundaries, and never commit unreviewed Z-Anatomy meshes,
unknown model weights, camera frames or personal data.

**W3b in development:** The Web branch also adds a local, optional
model-estimated world-landmark 2D consistency diagnostic. This does
not turn the screen-aligned W3a original demonstration into calibrated
anatomy AR or approve third-party model redistribution.

**W3c work (Web):** Added a camera-free, deterministic, original-geometry
perspective projection self-check inside the folded diagnostics UI.
Even zero synthetic reprojection error is NOT real camera calibration,
measured bones, authorized anatomical overlays or a public release.

**Current W3d1 engineering step:** a local, opt-in, strictly validated
camera evidence JSON viewer independently checks declared 3D target
points against held-out original-image 2D points. This is not a
camera solver, verified real-world measurement or real anatomy AR.
Critical-path blockers are detailed in
[the execution gates](Docs/EXECUTION_GATES.md).

**W2m source-only improvement:** the local anatomical model inspector
now exports and audits an exact-source-bound per-mesh rights worksheet,
flagging noncommercial (NC), ShareAlike and missing-evidence items
without automatically clearing copyright or enabling real anatomy
retargeting. See [license research](Docs/W2M_ANATOMY_RIGHTS.md).

**New W2n1 engineering demonstration:** the local anatomy study
dialog can generate an entirely ORIGINAL 19-joint SkinnedMesh
with real authored vertex weights and elbow/knee animation.
It exercises the real GLB skinning pipeline but is an abstract
mannequin, **not real anatomy or calibrated motion AR**.
See [the W2n1 limitations](Docs/W2N1_CANONICAL_SKINNED_FIXTURE.md).

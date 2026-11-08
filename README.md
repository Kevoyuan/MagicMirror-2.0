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

**Available in Web source W0:** camera start/stop/flip, local
single-person pose inference, partial arms/legs confidence gates,
translucent Three.js GPU 3D procedural proxy, video crop and front
mirror projection, Whole/Arms/Legs controls, opacity, overlay-only
pause, Leonardo paper dock, permission/recovery/layer/help states,
and synthetic geometry tests.

**Not yet completed/verified:** real-browser webcam testing on
multiple devices, Web Worker inference, exact camera↔overlay frame
lock, medically reviewed anatomical skeleton, genuine Z-Anatomy
assets/rights, articulated skinning/rig, physical 3D registration,
section layers, hosted public release or independent Google model
weight redistribution clearance.

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
3D anatomical model** move with human body observations. Replacing
iOS with Web simplifies access and contribution, not the legal,
kinematic or camera-registration science.

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

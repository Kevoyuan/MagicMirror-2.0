# MagicMirror 2.0 — DESIGN.md

**Version:** 2.0 — Web Leonardo camera-first design (2026-11-09)  
**Active product:** Browser-first, open-source educational anatomy mirror  
**Visual direction:** B · Leonardo Anatomy Notebook, refined for responsive Web  
**Status:** UI source implementation on a design PR; actual camera/Safari visual acceptance and public model/SDK rights review remain outstanding  
**Source of truth:** `AGENTS.md`, `Docs/ADR-003_WEB_OPEN_SOURCE_FIRST.md`, `Docs/WEB_MVP_ROADMAP.md`; Web runtime under `Web/src/`  
**Frozen references:** `Mobile/iOS/` and former iOS UX/architecture documents are preserved but not under active feature development. No native Android work.

## Active Web design · the moving anatomical folio

The main user job is to **start a private browser camera, observe only confidently detected body regions, and study the illustrative reference skeleton**. The experience must clearly distinguish a procedural GPU proxy from any separately licensed static anatomy model imported by the user.

A simple mental model:

```text
Leonardo Mirror (live, default)
├── Slender brand · EN/中文 · real tracking status
├── Full-bleed camera + truthful 3D procedural proxy
│   ├── One-shot local PNG (explicit action only)
│   ├── Optional, collapsible processing diagnostics
│   └── Tap visible proxy part → short study card → expand details
├── Compact parchment folio
│   ├── Whole / Arms / Legs (directly reachable)
│   ├── Reference opacity (collapsed until requested)
│   ├── Pause overlay / Flip camera / Stop / Layers
│   └── Always-visible reference / nonmedical disclosure
└── On-demand dialogs
    ├── Anatomy layers and rights: actual Proxy first; unavailable systems locked
    ├── Local FBX / GLB research: static inspector, no pose binding
    └── Privacy and provenance
```

### Product and ethical boundaries

- Live camera is the focal surface; no landing-page gallery, account, multi-tab dashboard, backend inference, forced tutorials, or decorative camera filter.
- The ordinary RGB camera does **not** measure actual bones. No X-ray, person-specific reconstruction, clinical diagnosis or calibrated anatomical section claims.
- A visible arm or leg can support partial reference tracking; do not demand full-body framing to start. Hide uncertain segments instead of predicting missing joints.
- Only the actual **procedural proxy** can be presented as live camera-tracked today. Imported FBX/GLB models are user-chosen, local-only, static research models; source model axes are not validated anatomical planes.
- No model rights are granted merely by MIT-licensing the new Web code. Public deployment remains subject to verified task-weight redistribution, SDK privacy, mesh-by-mesh rights and honest attribution.
- Unavailable Z-Anatomy bones, muscles, organs and true cross-sections are informational states, not active colored toggles.

### Responsive spatial hierarchy

| Zone | Design rule | Technical owner |
| --- | --- | --- |
| Header | One tight row, status legible, language button at least 44px; camera safe area respected | `Web/src/style.css` `.topbar`, `#language-toggle` |
| Live stage | Largest uninterrupted view, webcam crop/mirror matched with 3D overlay | `.camera-stage`, video, `#skeleton` |
| Stage utilities | Snapshot explicit; callback/latency diagnostics collapsed by default | `#snapshot`, `.diagnostics-disclosure` |
| Learning card | Compact visible segment title, details on demand, never simultaneously cover tracking guidance | `#part-note`, `.part-note-more` |
| Bottom folio | Whole/Arms/Legs direct; opacity expandable; action row 44px+; reference disclosure persistent | `.control-folio`, `.opacity-disclosure` |
| Anatomy / Privacy dialogs | Centered parchment study on desktop; scrollable bottom sheet on narrow phones | `dialog.folio-dialog` |
| Static model viewer | Independent, local-only, clearly labelled as nonanimated research; no hidden upload | `dialog.atlas-dialog` |

**Camera-stage objective:** on a representative portrait browser with ordinary text size, aim for approximately **70% or more of the visible layout area devoted to the stage** (not necessarily an unobscured pixel rectangle: translucencies and safe-area changes vary). Do not hard-code the ratio, or compromise 44px touch targets. At very short viewport heights, vertical scrolling is allowed instead of clipping or shrinking essential controls.

### Leonardo design system · Web token ownership

The Web styling uses coherent, restrained values rather than a parchment-themed decorative wallpaper:
- **Paper:** `--mm-paper #E5DAC1` / `--mm-paper-light #F4EAD4` for the folio and explanatory surfaces.
- **Ink:** `--mm-ink #25352E` for readable paragraph text, with `--mm-sepia #8B7658` for rules or noncritical metadata.
- **Verdigris:** `--mm-verdigris #345B50` for actual actions and selection.
- **Video scrim:** `--mm-camera-scrim #152820E8` for readable information over moving footage.
- **Type pairing:** restrained Georgia/system serif for the short *Folio* and *Anatomia* signature; system sans for buttons, guidance, accessibility and long passages.
- **Rhythm:** 4px baseline, 8/12/16/24px main spacing; 44×44px minimum activation targets; avoid low-contrast, tiny interactive numerals.

`Web/src/style.css` is the **runtime visual-token owner**. These values are a design contract and should be maintained there rather than copied into a second runtime stylesheet. Decorative registration corners and Latin folio labels must not imply pose calibration.

### Progressive disclosure · always tell the truth

1. **Default camera:** focus selector, four essential actions, one-line nonmedical disclosure. No always-visible opacity slider or long performance-readout panel.
2. **Opacity:** native `<details>` foldout presents the same working reference transparency slider. The closed state still remains keyboard/screen-reader discoverable.
3. **Diagnostics:** optional `<details>` exposes measured **local processing** indicators, never mislabelled as true display FPS or camera motion-to-photon latency.
4. **Proxy study note:** when a real visible segment is tapped, show its title and source-safe subtitle. Longer learning copy appears after an explicit expansion, with the nonmedical limitation visible in the full text. A note and framing guidance must not cover each other.
5. **Anatomy layers:** show **Proxy available** and local model entry before the long licensing explanation; use a disclosure after the genuine controls. Planned systems remain locked/unavailable.
6. **Local model study:** never substitute its static viewer for live AR, never silently upload, and always label model-axis clipping rather than medically registered transverse/sagittal/coronal planes.

### Locale and accessibility

- Chinese and English are supported directly from `Web/src/i18n.ts`. Decorative Italian/Latin marks are intentionally untranslated; user-facing action labels, errors, foldouts and privacy disclosures must be translated.
- Preserve exact original filenames, mesh hierarchy node names and provenance; don't send them to a translation API or generate guessed anatomical labels.
- Use semantic native `button`, `fieldset`, `input`, `summary`, and `dialog` elements. No fake clickable `div`. All interactive surfaces must reach 44px where feasible, have a visible focus outline and be keyboard usable.
- `dialog` must be dismissible via the existing close button and Escape; mobile bottom sheets stay scrollable and honor safe-area insets.
- Respect `prefers-reduced-motion`, high contrast, and browser text zoom. At large zoom or short viewports, prioritize scrolling over missing controls.
- The camera and WebGL canvas should not trigger noisy frame-by-frame screen-reader announcements. Dynamic status text should describe state changes, not expose internal inference timing as health data.

### Review acceptance matrix — Web only

| View / state | Check on real browser | Owner |
| --- | --- | --- |
| 390×844 portrait / mobile Safari | Camera stage dominates; header safe; focus and main actions reachable | Web UI |
| 320px narrow / 200% text zoom | Labels, buttons and privacy copy accessible without horizontal loss | Web UI |
| Desktop Chrome / Safari | Centered anatomy folio; working camera/video/Three.js overlay crop and mirror | Web + runtime |
| Start/deny/restart/background | Correct permissions, one source stream, no leaked tracks or stale proxy | Web runtime |
| Partial pose / lost pose | Only visible segments; concise guidance, note automatically clears if stale | Web runtime |
| Local anatomy viewer | Explicit import, static model, honest metrics and coordinate-axis cut, no outbound file upload | Web + rights |
| Keyboard / screen reader | Logical Tab order, focus rings, summary expand/collapse, dialog close, errors | Web UI |
| Release | Independently reviewed Google weights, SDK disclosures, relevant anatomy licenses | Owner/legal |

**Verification semantics:** `npm run typecheck`, `npm test` and `npm run build:code` establish source quality only. They do **not** prove camera behavior on an iPhone or authorize a public deployment. The full rights-gated `npm run build` must stay blocked until real evidence exists.

---

## Archived native iOS design notes (historical, NOT active)

Everything below this heading is preserved for potential future resumption of SwiftUI development. Its old platform/version labels, 34pt native header numbers, UIKit/Metal descriptions and mobile roadmap references do **not** override the active Web design above.

## 1. Product contract and design intent

**MagicMirror shows an automatically aligned, translucent, educational reference skeleton on a live image of one person and makes the structure follow their movement.**

The user should be able to open the installed phone app, allow camera use once, aim the **rear camera** at someone with shoulders and hips visible, and see the illustrative skeleton appear without an account, cloud processing, desktop companion, physical marker or manual calibration wizard.

The app is **not** an X-ray, personal internal-bone scan, posture diagnosis, clinical measurement tool or fictional-character filter. The initial on-device experience uses an **illustrative volumetric proxy**, not the yet-unshipped fully reviewed Z-Anatomy model.

The essential UX loop is:

**Open → aim at one person → acquire automatically → see reference skeleton follow → optionally adjust focus/opacity or pause overlay → recover automatically when tracking returns.**

### Non-negotiable design consequences

1. **Camera is the main surface.** Do not make a dashboard or gallery the product's default entry.
2. **Do not require a second screen before tracking.** The current one-screen model is intentional.
3. **Never present uncertain anatomy with false certainty.** UI status must match the actual pose/camera lifecycle, and uncertain or stale geometry must fade or disappear.
4. **Never mistake a proxy for a verified atlas.** Always-visible copy must identify reference/proxy status until a reviewed anatomical model is truly shipping.
5. **Phone-only, offline-first.** No webview, login, desktop/server dependency or Unity/Python runtime in the installed iPhone product.
6. **Native behavior wins.** SwiftUI controls, safe areas, SF Symbols, VoiceOver, Dynamic Type, Reduce Motion and standard permission handling.

## 2. Current product truth: implementation inspected

The following is **present in main at the time of authoring**, not an endorsement that it works on hardware.

| Current surface/system | Evidence | Design implication |
| --- | --- | --- |
| One-screen iOS app | Mobile/iOS/MagicMirror/App/MagicMirrorApp.swift and MirrorScreen.swift | Improve the existing live camera screen; **do not introduce an unsupported three-tab app shell**. |
| Full-bleed rear-camera image | Camera/CameraPreview.swift and Camera/CameraPosePipeline.swift | Maintain full-frame stage and preserve aspect-fill / source geometry. |
| Native on-device pose tracking | CameraPosePipeline.swift with MediaPipe Tasks Vision LIVE_STREAM | Explain searching/tracking states; do not show synthetic landmarks before detection. |
| Single person, 33 estimated landmarks | Tracking/PoseGeometry.swift | Only show overlays with sufficient observed shoulders/hips and confidence. |
| Semi-transparent volumetric proxy via Metal | Rendering/MetalSkeletonOverlay.swift and VolumetricBoneMesh.swift | Treat the proxy as educational material and never label it a real bone mesh. |
| Focus selection | AnatomyFocus: Whole / Arms / Legs | Preserve these actual focus modes; do not invent a bone/muscle/organ switch. |
| Opacity control | MirrorViewModel.opacity, current range 0.15…0.90 | A lower-priority, accessible adjustment, not the dominant screen element. |
| Pause behavior | MirrorViewModel.togglePause() clears snapshot while camera continues | Label clearly as **Pause overlay**; it does NOT freeze the video or stop camera capture. |
| Tracking and permission phases | idle, permissionRequested, searching, tracking, permissionDenied, unavailable | Design explicit user-facing messages and recovery. |
| Research atlas model contract | Anatomy/VerifiedAnatomyAtlas.swift and AnatomyAtlasManifest.swift | Asset-validation machinery exists; approved full anatomy has NOT been shipped or tested. |

The current source uses a dark color scheme, cyan accent, a top status pill, a lower guidance panel, a three-segment focus picker, a visible opacity slider, a pause button, and a nonmedical disclaimer.

**Validation boundary:** Arm64 Simulator build-for-testing is documented as passing; real rear camera, true moving-person overlay registration, actual anatomy atlas, iPhone performance/thermal, accessibility and TestFlight remain unverified. An open draft PR may contain further camera-fit experiments; those changes are not treated as merged main.

## 3. Confirmed visual identity — B · Leonardo Anatomy Notebook

**Owner decision:** Replace the former provisional A · Instrument Mirror recommendation with **B · Anatomical Field Guide, refined into a Leonardo da Vinci anatomy sketchbook**.

The screen should feel like an illustrated anatomical research notebook brought to life by a real-time camera: muted parchment, sepia ink, copperplate rules, verdigris-green selections, extremely restrained handwritten-style labels, and scientifically reviewed anatomy illustrations.

**The camera, not paper decoration, is the hero.** The earlier B concept used a large top banner and overgrown parchment panel; both must shrink. Keep the live person and reference skeleton visible. Use thin margin marks, very light paper texture, and small contextual annotations only when they communicate a useful fact. No decorative medical measurements.

### Chosen composition

- **Top:** one slender manuscript-style brand/status row, visually about **34 pt of content strip**, excluding the actual iOS safe area; interactive hit targets remain **44 pt minimum**.
- **Center:** full-bleed live camera with translucent reference anatomy. Aim for about **70% or more visible camera region** in the collapsed default layout on a representative portrait iPhone, **not** a hard-coded screen height. Dynamic Type and safe areas take priority.
- **Bottom:** compact parchment control dock with existing Whole / Arms / Legs focus, overlay pause, transparency control and persistent educational disclaimer. Complex anatomy controls expand only on demand.
- **Layers:** a compact "图层 / Layers" entry opens a native bottom sheet. Do not turn the entire camera into a parchment page.
- **Annotations:** short editorial notes can appear in a contextual sheet after true reviewed anatomy is available. Long explanatory copy must never block first-run camera detection.

### Rejected design directions

- **A · Instrument Mirror:** retained as a lesson in uncluttered camera-first hierarchy, but **not** the active visual identity.
- **C · Motion Observatory:** technical HUD/grid styling is reserved for optional diagnostics, not normal users; it falsely suggests clinical precision.

This is a visual design decision, not proof that the SwiftUI prototype or a reviewed multi-system 3D renderer has been built.

## 4. Information architecture: keep the product small

### Shipping/current concept

~~~text
MagicMirror (one immersive screen)
├── Camera preview (rear camera, one capture owner)
├── Reference overlay (pose-gated Metal rendering)
├── Tracking/status and contextual framing guidance
├── Focus: Whole | Arms | Legs
├── Opacity adjustment
├── Pause overlay / Resume overlay
└── Persistent illustrative / nonmedical explanation
~~~

No home dashboard, login, profile, settings tab, anatomy library, save gallery or camera flip is currently implemented. **Do not add any of these merely to make the UI look more like a generic app.**


### Owner-selected future concept: Z-Anatomy-style anatomy layers

MagicMirror should explore **system-based visibility and combinations**, while keeping Whole / Arms / Legs as a separate **body-region focus** control. The proposed layers are **骨骼 (skeleton), 肌肉 (muscles), 内脏 (organs), 血管 (vessels), 神经 (nerves), 关节与韧带 (joints/ligaments)**. These are *proposed UI categories*, not a verified inventory of independent, redistribution-cleared, rigged mobile meshes.

- **Collapsed:** one small Layers entry at the bottom with the active layer name, retaining maximum camera height.
- **Expanded:** native parchment bottom sheet with labelled rows, show/hide, an accessible Solo choice and individual opacity **only if** independently rendered layer geometry is really implemented.
- **Unavailable:** production controls must remain disabled or absent and say why; a visual HTML demonstration must be identified as a **concept**.
- **Advanced section planes:** a separate native sheet may eventually offer **横断面 / axial**, **矢状面 / sagittal**, and **冠状面 / coronal** controls. True slices require validated 3D mesh clipping/capping, coordinate registration, coherent licensed anatomy and actual rendering; moving a decorative guideline over a photograph is not slicing.
- **Scientific boundary:** MediaPipe body landmarks do not reveal actual inner tissue. Regions without reliable pose evidence should be hidden instead of extrapolated confidently.
- **Asset gate:** Z-Anatomy/BodyParts3D source licenses, individual system inventory, mapping, rigging and mobile GPU constraints require real review before any layer is described as supported.

### Optional future interaction, NOT in current design acceptance

When reviewed atlas assets, educational content and dedicated scope exist, introduce a contextual anatomy detail **sheet** from selecting a verified region. A camera-free atlas might follow as a separate approved feature. Neither should block the first automatic live-overlay experience.

## 5. Screen anatomy and spatial hierarchy

### S01 — Live Mirror / the main and only required screen

**Content priority (highest first):**

1. Live person and automatically aligned visual skeleton.
2. Recognition state and immediate framing/recovery guidance.
3. Clear, persistent “illustrative reference” disclosure.
4. Focus control.
5. Pause/resume overlay.
6. Optional opacity fine-tuning.

**Vertical composition for portrait iPhone:**

~~~text
╭──────────────────────────────────╮
│  iOS safe area                    │
│  MAGICMIRROR     [Searching …]   │  quiet, high-contrast header
│  Reference anatomy / on-device   │
│                                   │
│                                   │
│       LIVE CAMERA CANVAS          │
│                                   │
│      translucent proxy            │  dominant content; no fake HUD
│      follows observed pose        │
│                                   │
│   [Contextual hint, only needed]  │
│                                   │
│ ┌───────────────────────────────┐ │
│ │ Whole    Arms     Legs        │ │
│ │ [Opacity control, optional]   │ │  safe-area-anchored control dock
│ │ Reference proxy  [Pause]      │ │
│ └───────────────────────────────┘ │
│    iOS home indicator safe area   │
╰──────────────────────────────────╯
~~~

The schematic is illustrative, not a verified device screenshot.

### Header behavior

- Left: a thin manuscript-style MagicMirror label, without a tall title block; keep the readable status at right.
- Right: **one textual status pill**, not a stack of floating diagnostics.
- Do not display TRACKING just because a camera session is running; it means a current usable pose is present.
- In paused state, say “OVERLAY PAUSED”, not SEARCHING or TRACKING.
- Keep header inside top safe area. Camera/image may extend behind it; controls may not.
- Status background must be sufficiently opaque to read against any real camera scene.

### Stage / overlay behavior

- Live camera covers the screen while UI remains in safe-area bounds.
- Preserve exact source-to-preview aspect-fill, portrait rotation and anatomical left/right mapping.
- Metal overlay is noninteractive by default; it must not intercept underlying SwiftUI control taps.
- The reference mesh should read as translucent and volumetric, not as an opaque fictional costume.
- Do not overlay invented bone labels, rulers, angle readings, clinical risk scores or body measurements.
- If the renderer has only the procedural mesh, show **Reference proxy** explicitly; reserve **Reviewed anatomy** for validated licensed atlas assets and real rig behavior.

### Guidance behavior

- Searching: brief actionable message (“Point at one person. Keep shoulders and hips in view.”).
- Permission denied: clear reason + native button to open iOS Settings.
- Interrupted/unavailable: neutral, specific explanation + recovery where possible.
- Tracking success: hide the large guidance panel so the subject remains visible.
- Tracking loss: fade overlay promptly, then present guidance; no stale skeleton on top of a new person.
- Never show a large, always-present instructional card over the center of a successfully tracked body.

### Bottom control dock

- Anchor above the home indicator/safe area, use a constrained max width on large iPhones.
- Keep Whole / Arms / Legs as a native segmented Picker.
- Present **Pause overlay / Resume overlay** as a distinct 44 pt minimum control.
- Treat opacity as a secondary adjustment: initial release may keep visible slider, but production variant should evaluate a compact “Opacity” disclosure to preserve camera stage.
- Show the nonmedical/reference note persistently, including while successfully tracking. The wording can be compact but must remain readable and VoiceOver-accessible.
- Avoid multiple stacked translucent cards and ambiguous icon-only actions. The selected Leonardo direction uses a compact parchment-like dock; a future Layers button opens an on-demand sheet rather than permanently expanding the dock.

## 6. Design tokens and component contract — Leonardo direction

These are **proposed tokens**, not a claim that they are already declared in source. **The selected Leonardo palette below supersedes the earlier dark/cyan Instrument Mirror proposal for future UI work.** The existing Metal proxy appearance need not change during an unrelated UI redesign.


### 6.1 Color — paper, sepia, verdigris

| Token | Proposed value | Meaning |
| --- | --- | --- |
| parchment | #F3EBDD | Notebook drawer, notes, expanded surfaces |
| agedPaper | #DFD1B9 | Dividers, insets, quiet rules |
| sepiaInk | #332D27 | Primary text over paper |
| mutedInk | #74685A | Secondary annotations |
| copper | #A67952 | Delicate manuscript rule accents |
| verdigris | #38675D | Selected action, accessible primary accent |
| viewfinderScrim | #151916 | Small dark backing behind camera status text |
| viewfinderText | #FBF8F1 | Status text over the live camera |
| proxyIce | #D1F0FF | Existing illustrative proxy color family |

Later layer legend colors can distinguish bone ivory, muscle terracotta, vessel burgundy, nerve ochre, organ mauve and ligament sage. These are **legend suggestions**, not evidence of available anatomy meshes. Use text and toggles, never color alone. Do not apply a sepia filter to camera pixels. Make narrow controls readable on bright footage; the currently forced dark app appearance can be revised only with proper native contrast checks.


### 6.2 Type

- Native San Francisco system styles for all interactive labels, controls and explanatory body copy; short notebook headings may use a restrained historical serif or italic if font rights are verified.
- Screen/brand: a single compact header row; avoid giant titles or decorative lettering across live video.
- Status: subheadline/caption with readable casing; no all-caps accessibility-only phrasing.
- Secondary copy: subheadline/body; long permission and recovery instructions must wrap.
- Numeric opacity: monospacedDigit for percentage only.
- Dynamic Type governs interactive copy and panels. Do **not** use fixed heights that clip text.
- Support English in current code, with copy and widths prepared for Simplified Chinese localization; do not hard-code a Latin anatomy term as the only label.

### 6.3 Spatial and touch scale

- Base spacing grid: 4 pt; common distances 8, 12, 16, 20, 24 and 32 pt. The thin 34 pt header refers to its visual content strip, **not** iPhone safe area or touch target size.
- Horizontal controls inset: nominal 16–20 pt, adjusted for device size and safe area.
- Dock vertical padding: about 12–16 pt, subject to Dynamic Type.
- Button/selectable target: at least **44 × 44 pt**.
- Control radius: approximately 12–16 pt; prominent dock 20–24 pt when needed.
- Respect top camera housing, Dynamic Island, rounded edges and bottom home indicator.
- A compact device should never require clipping or overlaying the subject just to fit ornament.

### 6.4 Icons

Use SF Symbols for native chrome: viewfinder (search), pause.fill / play.fill (overlay state), slider.horizontal.3 (optional opacity disclosure), camera.fill (permission concept), exclamationmark.triangle (recoverable error).

Icon meanings must be backed by visible labels or accessibility labels. Do not mix emoji and SF Symbols as functional icons.

### 6.5 Motion and feedback

- No pulsing status animation on every camera frame.
- Status transitions: brief native crossfade, e.g. 150–220 ms as an initial design target, measured and tuned later.
- Guide appears/disappears without bouncing over a tracked subject.
- No continuous haptics while tracking; optional haptic feedback only on explicit user action and not required for comprehension.
- Follow Reduce Motion, avoiding nonessential moving HUDs.
- Tracking/mesh smoothing belongs to the pose/render pipeline, not a decorative SwiftUI animation.

## 7. State and copy specification

The UI must distinguish camera lifecycle, pose confidence and user-controlled overlay pause. **Paused overlay still leaves the camera preview running in the current code.**

| State | Status | Primary guidance | Action / visual behavior |
| --- | --- | --- | --- |
| Idle / first load | PREPARING | “Allow camera access to show a reference skeleton.” | Permission path; no pretend detection |
| Permission requested | CAMERA ACCESS | “MagicMirror processes camera images on this iPhone.” | System permission controls; no extra fake modal |
| Searching (including dropped pose) | SEARCHING | “Point at one person. Keep shoulders and hips in view.” | Live camera visible; no stale geometry |
| Tracking | TRACKING | No persistent large prompt | Current pose-gated reference proxy only |
| User paused | OVERLAY PAUSED | “Overlay paused. Camera preview is still active.” | Mesh hidden; Resume overlay available |
| Permission denied/restricted | CAMERA BLOCKED | “Enable Camera access in iOS Settings to use MagicMirror.” | Open Settings; no broken or misleading camera preview |
| Camera interrupted | CAMERA INTERRUPTED | “Camera temporarily unavailable. Tracking will resume when possible.” | Hide overlay, show recoverable state |
| Unavailable / fatal | CAMERA UNAVAILABLE | Brief cause, avoid raw developer error strings in production | Explicit retry when safe, otherwise clear next step |

**Localized copy seeds (English → Simplified Chinese)**

- “Reference proxy, not your real bones” → “参考骨架模型，并非您的真实骨骼”
- “Point at one person” → “请将镜头对准一位人物”
- “Keep shoulders and hips in view” → “请让肩膀和髋部进入画面”
- “Pause overlay” → “暂停叠加显示”
- “Resume overlay” → “恢复叠加显示”
- “Skeleton opacity” → “骨架透明度”
- “Whole / Arms / Legs” → “全身 / 手臂 / 腿部”
- “Illustrative reference, not medical imaging” → “仅供解剖学习参考，并非医学影像”

**Copy requirements:** No “X-ray”, “scan your bones”, “real skeleton inside you”, “measured bone positions”, “medical grade”, or “perfect 3D tracking”. Never use a specific tracking confidence percentage unless its definition is real, understandable, and validated.

## 8. Component breakdown and SwiftUI ownership

Design target components (not all currently separated into code):

| View/component | Responsibility | Data dependency |
| --- | --- | --- |
| MirrorScreen | Composes the current one-screen immersive experience | Stable phase + selected control state |
| CameraPreview | Presents the sole native capture session's live preview | Camera pipeline session, not a second camera |
| MetalSkeletonOverlay | Pose-gated GPU geometry overlay | Latest eligible PoseSnapshot, focus and opacity |
| MirrorTopBar | Brand, trustworthy tracking/paused status | Lightweight phase and isPaused |
| MirrorGuidance | Permission/framing/recovery instructions | Phase and eligibility |
| MirrorControlDock | Existing focus/pause/opacity controls; future compact Layers entry | Focus, opacity, isPaused |
| AnatomyLayersSheet (future) | Approved layer visibility, Solo, per-layer legend/opacity | Licensed asset availability and independent render state |
| AnatomySectionSheet (future) | Axial/sagittal/coronal clipping controls | Validated 3D mesh sectioning state |
| AnatomyNoteSheet (future) | Reviewed structure information in manuscript style | Actual selected anatomy and provenance |
| ReferenceDisclosure | Always-reachable nonmedical/reference notice | Actual asset class (proxy vs reviewed) |
| MirrorViewModel | Owns screen-visible state and lifecycle | Camera pipeline callbacks; temporal expiry |

Implementation rules:

- Keep **MirrorViewModel** on MainActor and use iOS 17+ **@Observable** with view-owned **@State** (as currently implemented).
- Keep high-frequency capture/inference and vertex processing off the main thread where appropriate.
- Extract frequently changing overlay input from static header/dock invalidation: views should read only state they use.
- Preserve the one-camera AVFoundation capture owner and same-capture-frame timestamp/geometry gate. Do not introduce ARKit as a second simultaneous camera.
- Never replace stale pose with the latest unrelated preview frame and claim exact synchronization.
- Prefer native Button, Picker, Slider and system presentation; no custom gesture-only substitute for essential actions.
- Do not disable standard iOS accessibility or adopt decorative Liquid Glass unless a future approved direction explicitly asks for it.
- UI redesign must not alter landmark indexing, left/right anatomical identity, camera intrinsics, native pose filtering or mesh math as an incidental change.
- Any future anatomy model selection must be gated by independently approved asset licenses, real hierarchy/rig validation and calibrated projection.

## 9. Accessibility and responsive behavior

### Minimum baseline

- All functional controls have 44 pt minimum touch area and VoiceOver names.
- Tracking and pause status are understandable without color; avoid announcing each pose frame to accessibility APIs.
- Status changes announced selectively, not at camera FPS.
- Focus Picker labels remain comprehensible in English and Chinese.
- Slider supports system accessibility adjustments and its current percentage is exposed meaningfully.
- On larger Dynamic Type sizes, place secondary controls into an expandable sheet if needed; maintain persistent disclaimer and recovery actions.
- If dark translucent panels fail contrast on bright camera footage, increase scrim opacity rather than dimming camera image globally.
- Honor Reduce Transparency / Increase Contrast / Reduce Motion where practical.

### Proposed review sizes and scenarios

Test at representative **compact iPhone**, **standard iPhone** and **large iPhone** portrait sizes. Capture both dark-room and bright-window camera scenes; simulate Dynamic Type accessibility sizes and VoiceOver. Avoid hard-coding precise screen dimensions or reading a global screen size when a view's actual geometry is available.

Camera loss, denial, no subject, partial subject, human leaves frame, app background/resume, overlay paused, long localized text and repeated tracking acquisition must each have a legible visual state.

**Do not claim these tests have been executed merely because this document describes them.**

## 10. Privacy, scientific honesty and licensing

- Camera processing is designed to remain on the iPhone with the bundled MediaPipe model; no mandatory network or account.
- Current source does not save, record or upload frames. Do not add capture, telemetry, social sharing or persistent pose history as a design-only side effect.
- Camera permissions should be contextual and reversible via iOS Settings.
- Explain the reference/illustrative nature in the default live screen; user must not need to hunt through a hidden legal page.
- Current volumetric proxy is visually 3D but is created from estimated body-surface landmarks and illustrative depth. It is **not verified personal anatomy**.
- Full Z-Anatomy / BodyParts3D-derived atlas must clear per-asset license, attribution, mesh mapping and hardware validation before UI presents it as reviewed anatomy.
- Any future “muscle”, “organ” or “bone detail” control must be disabled/absent until the underlying licensed, scientifically reviewed rendering exists.

## 11. Prioritized design implementation plan

### D0 — Leonardo design exploration and prototype (concept stage)

- Document current live-screen behavior and truthfully label source vs aspirations.
- Three directions were compared and **the owner selected B / Leonardo Anatomy Notebook** with substantially increased live camera space.
- Create iPhone-sized static screen concepts for: searching, tracking, paused, permission denied and camera interrupted.
- HTML prototypes for live view, searching/paused/permission states, layers and section controls have been explored in the conversation. These are **static/illustrative UI concepts**, not evidence of real-time native 3D anatomy or a shipped iPhone app.

**Exit:** Clear design sign-off, readable component specification and no claims about unavailable anatomy assets.

### D1 — Native SwiftUI screen refinement

- Preserve existing camera/Metal pipeline.
- Split header, guidance, disclosure and control dock into small view components where appropriate.
- Improve safe-area placement, frame occlusion, touch targets, focus and opacity hierarchy.
- Make “Pause overlay” behavior and tracking state unambiguous.
- Add accessibility labels and localized copy resources.
- Verify no new dependency on camera FPS causes unnecessary top-level SwiftUI invalidations.

**Exit:** Existing one-screen workflow remains working, with no regression in source-frame tracking or lifecycle behavior; simulator/UI checks where available and physical hardware gates still required.

### D2 — Real device validation, not optional for release

- On named physical iPhone(s), check onboarding/permission, rear-camera composition, pose/preview registration, recovery, brightness, readable controls, background/resume.
- Test VoiceOver, Dynamic Type, Reduce Motion and text scale.
- Profile displayed FPS, movement-to-display latency, battery and thermal over sustained use as defined in active mobile roadmap.
- Report actual evidence and limitations, not estimates as measured performance.

### D3 — Review-gated anatomy extension

- After verified coherent licensed 3D atlas exists, update disclosure from proxy to appropriately labeled reviewed reference.
- Add anatomy-level information affordances only if it helps the core camera interaction and the model can support true hit targets.
- Consider a contextual native sheet rather than turning the app into a navigation-heavy learning portal prematurely.

### D4 — Approved multi-system layer and section explorer (later)
- Review actual Z-Anatomy model grouping and redistribution permissions before introducing layer choices in production.
- Support independently composited bone/muscle/organ/vessel/nerve/ligament meshes only after approved mobile asset/rig and GPU validation.
- Only introduce real anatomical planes when the native renderer can actually clip/cap coherent 3D meshes. The HTML mock has no such capability.
- Layer drawer remains opt-in and must not interfere with the core camera experience.


## 12. Design acceptance checklist

### Core outcome

- [ ] Camera is visually dominant; a person remains visible through the UI.
- [ ] Normal path stays launch → camera permission → automatic tracking → reference overlay.
- [ ] No extra onboarding step, account, calibration wizard or secondary camera is required.
- [ ] Proxy is called proxy everywhere; educational/nonmedical disclaimer remains reachable and persistent.
- [ ] Lost/uncertain pose removes inaccurate geometry and gives practical guidance.

### Interface quality

- [ ] Actual iPhone UI reflects **B / Leonardo notebook**, not the previous A recommendation.
- [ ] Top banner is slim and the collapsed view dedicates about 70%+ of usable composition to the camera where feasible (while respecting safe areas and Dynamic Type).
- [ ] Expanded anatomy layer sheet is on demand; non-shipping systems are never falsely interactive.
- [ ] Any production section-plane controls perform actual validated 3D slicing, not a cosmetic mock.
- [ ] Header, guidance, focus controls, opacity and pause remain readable across tested camera backgrounds.
- [ ] Every target is at least 44 pt; compact and large iPhones have no clipped safe-area content.
- [ ] Whole/Arms/Legs map to **existing** AnatomyFocus cases.
- [ ] Pause control does not imply the video is frozen.
- [ ] VoiceOver/Dynamic Type, Reduce Motion and relevant accessibility settings have been checked.
- [ ] Any design-specific transitions do not add latency to the video/pose pipeline.

### Engineering integrity

- [ ] One camera stream and frame identity preserved.
- [ ] No Python/Unity/cloud runtime was introduced.
- [ ] Simulator compilation, unit-test execution and physical-camera validity are reported separately.
- [ ] Any anatomy asset mode is gated by actual reviewed inventory and attribution.
- [ ] No desktop archived roadmap is used as the active delivery plan.
- [ ] Native screenshots and measured behavior come from actual iOS Simulator/device testing, not a browser composition.

## 13. Confirmed design direction and remaining decisions

**Confirmed by the owner:** B · Leonardo Anatomy Notebook; minimize the tall header and give more space to the live camera; add a compact Layers entry and future anatomy-system and section-plane explorer.

**Still open / requires implementation and evidence:** opacity disclosure density; exact Z-Anatomy licensed system inventory; actual independent GPU layer visibility/opacity; true 3D slice clipping; bilingual/accessibility checks; partial-body pose handling on merged native code; hardware FPS, latency, camera/mesh registration and thermal testing. The HTML prototype is not validation of any of these.

## 14. Design references and hierarchy of authority

**Active product requirements (highest priority):**
- AGENTS.md
- Docs/ADR-002_MOBILE_NATIVE_OFFLINE_FIRST.md
- Docs/MOBILE_NATIVE_ROADMAP.md
- Mobile/iOS/README.md

**Native implementation inspected:**
- Mobile/iOS/MagicMirror/App/MagicMirrorApp.swift
- Mobile/iOS/MagicMirror/App/MirrorScreen.swift
- Mobile/iOS/MagicMirror/App/MirrorViewModel.swift
- Mobile/iOS/MagicMirror/Camera/CameraPosePipeline.swift
- Mobile/iOS/MagicMirror/Camera/CameraPreview.swift
- Mobile/iOS/MagicMirror/Tracking/PoseGeometry.swift
- Mobile/iOS/MagicMirror/Rendering/MetalSkeletonOverlay.swift
- Mobile/iOS/MagicMirror/Rendering/VolumetricBoneMesh.swift
- Mobile/iOS/project.yml

**Risk and future asset references:**
- Docs/IOS_ANATOMY_ATLAS_INTEGRATION.md
- Docs/MOBILE_ATLAS_PACKAGE.md
- Docs/ASSETS_AND_LICENSES.md
- Docs/IOS_TESTFLIGHT_READINESS.md
- Docs/IOS_CAMERA_PROJECTION_AND_REPROJECTION.md

**Archived, not active mobile instructions:** Docs/PRODUCT_VISION.md, Docs/ARCHITECTURE.md and Docs/ROADMAP.md describe earlier desktop research and cannot override the mobile-first decision.

---

**Handoff rule:** Follow the owner-selected Leonardo Anatomy Notebook style for new UI; do not revert to the earlier A baseline. Keep **implemented source**, **compiled source**, **HTML-only design interactions**, **physical-device verification**, and **future licensed anatomical systems** distinct.
## Implementation progress — native camera-first layers (2026-11-07)

A new SwiftUI implementation now follows the selected Leonardo notebook
composition at **source** level: single-row header with 44-pt diagnostic
touch target, parchment-inspired compact dock, collapsible opacity,
separate Whole/Arms/Legs region focus, and a native Layers information
sheet. Only the procedural reference proxy is currently available. The
six planned anatomy system categories and three section planes are
explicitly unavailable; no fake Solo/slicing interaction was added.

The implementation still needs physical-device visual review (small
screens, safe areas, VoiceOver, Dynamic Type, contrast over camera footage)
and may be refined after that evidence. This update does **not** approve a
bundled anatomical model or certify the UI as production-ready.

## Whole-app native UX continuation (2026-11-07)

The single-camera app now has a second optional native folio, **Field Notes**,
with **Use**, **Privacy** and **About** pages for short camera instructions,
privacy explanations, illustrative model limitations and optional local
pose-delivery diagnostics. This information does not block automatic camera
start. The original **Layers** folio still separates Systems from Sections,
and remains honest about unavailable multi-system meshes and slicing.

For consistent failure feedback, **MirrorPresentationState** maps camera
permission/lifecycle, actual current pose coverage and overlay pause into
one tested visible state, prioritizing blocked/interrupted camera over
old Pause preferences. The UI source and unit tests still require physical
iPhone visual/accessibility QA; simulator compilation is not real-device proof.

The native architecture also isolates per-frame Metal rendering into a
dedicated SwiftUI view while keeping the existing AVFoundation preview
owner stable. The camera status chrome reads a low-frequency coverage
classification; actual FPS and power improvements remain unmeasured.

A full screen-by-screen inventory, UX journeys and QA matrix live in
[Docs/IOS_UI_USER_JOURNEYS.md](Docs/IOS_UI_USER_JOURNEYS.md). This document
remains the root visual direction authority.


## Bilingual layout and runtime token contract (2026-11-07)

**Language policy:** The native iPhone interface follows the system language:
English is the development fallback and Simplified Chinese (`zh-Hans`) is
translated. Shipping string ownership is
`Mobile/iOS/Resources/{en,zh-Hans}.lproj/Localizable.strings`, using
native SwiftUI `LocalizedStringKey` for titles from display enums,
camera state copy, accessibility labels, and explanatory sheets.
Do not use a manual in-app language switch or extra login/onboarding screen.

**Layout contract:** The normal portrait header fits brand, help and tracking
status in one thin row; compact-width fallback reduces only the *brand mark*
to “MM”, not the status or touch target. In accessibility text sizes the status
wraps into a second row instead of clipping the primary action. The partial
pose status is visible in the header without a permanent large guidance card
blocking the tracked person. These are source-level design changes requiring
real iPhone screenshots at each supported Dynamic Type size.

**Color ownership:** `LeonardoPalette.swift` is the canonical SwiftUI theme
source, derived from this DESIGN.md. `copperInk` (approximately `#82583A`)
is intentionally darker than decorative `copper` on parchment for small
labels. Keep renderer geometry tints independent of UI colors. On the
nominal opaque parchment background, design contrast estimates are about
11.5:1 for primary ink and 4.6:1 for muted ink; these are not proof of
contrast against moving camera footage.

**Brand exception:** short manuscript labels such as *Anatomia* and *Folio*
can be kept as a deliberate bilingual-independent editorial signature;
action labels, recovery copy and educational content must localize.
If a localized string changes the available width, do not truncate the
user's action or the medical limitation; expand the sheet or choose the
adaptive control arrangement instead.

**Verification:** Check English and Chinese across Mirror, Anatomy Folio
and Field Notes on a compact and large iPhone, with VoiceOver and
accessibility Dynamic Type. Confirm that XcodeGen includes both `.lproj`
resources. Static source parity and Simulator compilation are necessary
but not substitutes for a real iPhone localization/contrast inspection.

## Web-first Leonardo local research folio (2026-11-09)

The active Web interface includes a separate **Folio II** modal
for *user-chosen local* static anatomy study. It is intentionally
distinct from the live camera/procedural mirror:
- Opens via Layers → local FBX/GLB viewer, leaving the camera stopped.
- Provides static Three.js orbit, actual imported mesh metadata,
  part-name inspection, opacity, wireframe and model-axis clipping.
- The camera remains the main default Web screen. Do not inflate
  the banner/dock or introduce a distracting dashboard.
- Unreviewed static models and model-space slices are **not**
  marketed as real-time anatomical reconstruction, licensed
  bundled anatomy layers or clinically calibrated body sections.

## Web active study notes (2026-11-09)

**Folio III / quick learning:** tapping a *visible* real-time
procedural segment opens a restrained parchment card with
Chinese + English anatomical region, concise original educational
commentary and permanent 'not actual bone imaging' qualification.
Keep the camera dominant and fade/hide cards when observation is
lost. The local static FBX/GLB source mesh inspector remains a
separate Folio II and does not constitute real-time rigged anatomy.

## Web bilingual header (2026-11-09)

Add exactly one small, keyboard-accessible **EN / 中文** control
without increasing top-banner height. It changes UI labels and
educational copy only, not the original imported anatomy mesh
names, provenance, tracking session or camera frame. On mobile
maintain the camera as the dominant surface; verify narrow
portrait iPhone layouts and screen reader labels in both languages.

## Folio II · Original part browser (2026-11-09)

Within the *separate* local anatomy study dialog, place a compact
search field above a **bounded mesh source hierarchy list**:
source group breadcrumbs, part name and real triangle count,
plus small visibility, isolate and focus controls. Show
60 matches initially to avoid overwhelming a mobile layout.
Use selected gold accent for actual source geometry and keep
the anatomical model viewport larger than its metadata panel.
An optional local JSON source inventory download must be
explicitly user-triggered and labelled *not a rights review*.
This is a private model study surface, not a live camera overlay
or real Z-Anatomy anatomical slice mode.

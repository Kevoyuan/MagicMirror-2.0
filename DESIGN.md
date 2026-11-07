# MagicMirror 2.0 — DESIGN.md

**Version:** 1.0 design foundation (2026-11-07)  
**Status:** Proposed visual direction and implementation specification; not a claim of device-verified behavior  
**Product:** Native iPhone anatomy AR mirror, iOS 17+  
**Repository:** https://github.com/Kevoyuan/MagicMirror-2.0  
**Applies to:** Mobile/iOS/MagicMirror/ — iOS UI and user-facing real-time rendering only  
**Authority:** This file owns interaction and visual design. AGENTS.md, ADR-002, the active mobile roadmap, privacy/asset reviews, and code own product/engineering truth.

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

## 3. Three genuinely different visual directions

Huashu-style design exploration and gstack design consultation are applied here as **concept directions**, not as screenshots or device-validated mockups.

### A — Instrument Mirror (RECOMMENDED)

**World:** A precision optical instrument that happens to reveal educational anatomy.  
**Layout:** Full-screen live image; small restrained top brand/status; subject-centered visualization; bottom-edge compact control dock; no bulky cards over the person.  
**Type:** Native SF Pro with strong legibility and quiet numeric opacity readout.  
**Color:** Near-black neutral surfaces, ice-blue proxy geometry, single aquatic-cyan interactive tint.  
**Motion:** Status crossfade and brief acquisition confirmation; anatomy movement itself is the animation.  
**Strength:** Faithful to the existing SwiftUI/Metal implementation; fastest path to a credible first-run experience.  
**Risk:** Dark chrome and translucent geometry need contrast testing in bright environments.

### B — Anatomical Field Guide

**World:** A museum-quality, contemporary reference atlas.  
**Layout:** Live camera occupies a contained upper region with a light editorial lower learning panel; prominent anatomy labels and explanatory copy.  
**Type:** System reading styles plus restrained editorial display typography.  
**Color:** Warm ivory, graphite, muted teal, engraved bone-colored annotations.  
**Motion:** Learning cards and sectional reveals; minimal on the live image.  
**Strength:** Clear educational context and excellent long-form reading potential.  
**Risk:** Reduced live camera area and intrusive UI undermine the one-screen, camera-first promise.

### C — Motion Observatory

**World:** A field instrument for visual motion study.  
**Layout:** Full-bleed image, framed alignment marks, compact bottom control rail, visible pose confidence and diagnostics in a developer mode.  
**Type:** Dense system labels and tabular numeric feedback.  
**Color:** Charcoal, high-visibility lime, neutral white.  
**Motion:** Tracking acquisition and subtle timing/pose traces.  
**Strength:** Powerful for later lab/testing functionality.  
**Risk:** Looks like a posture-scoring product, invites unsupported precision claims and adds cognitive load.

### Direction decision

Use **A — Instrument Mirror** as the **provisional implementation baseline** for this document. It preserves the established dark/cyan visual identity and the current single-screen journey while improving control hierarchy, wording and accessibility. Selection remains revisable after real iPhone prototypes and owner approval.

**Do not combine all three aesthetics.** Later educational detail surfaces may inherit the same system, not import B's typography as a second product identity.

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

- Left: compact MAGICMIRROR wordmark and optional short on-device reference subtitle.
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
- Avoid multiple stacked translucent cards and ambiguous icon-only actions.

## 6. Design tokens and component contract

These are **proposed tokens**, not a claim that they are already declared in source.

### 6.1 Color

The live camera is visually unpredictable. Use **solid or reliably darkened surfaces** behind essential text; never assume white labels contrast directly against video.

| Token | Proposed dark value | Role |
| --- | --- | --- |
| canvasFallback | #071013 | Used only before/without camera pixels |
| chromeSurface | #102125 | Opaque or nearly opaque control dock |
| chromeElevated | #1C3539 | Selected/expanded control background |
| borderSubtle | #39575B | Separators and state boundaries |
| textPrimary | #F7FBFB | Primary text on dark chrome |
| textSecondary | #C4D4D6 | Secondary text on dark chrome |
| actionTint | #5CE0DD | One interactive accent |
| proxyBone | #D1F0FF | Existing proxy's icy color family |
| success | system green | Confirmed operable state, not pose accuracy |
| caution | system orange | Framing, recovery or uncertainty |
| failure | system red | Permission or camera failure |

The existing render mesh derives its tint from separate Metal color values; **do not silently replace Metal geometry color with the UI tint**. Proxy color and interaction tint have separate semantics.

Do not use green to imply tracking is medically correct. Status must have a text label and SF Symbol, never color alone. Material/gradient scrims are allowed only where they solve real camera-content legibility.

A future light-appearance interface should use a separately validated semantic palette. The **current** live mirror is dark-first and explicitly forced to dark in MagicMirrorApp.swift; this spec does not claim system-wide light-mode support today.

### 6.2 Type

- Native San Francisco system styles for all app UI.
- Screen/brand: title3 or headline as appropriate; avoid giant marketing copy across live video.
- Status: subheadline/caption with readable casing; no all-caps accessibility-only phrasing.
- Secondary copy: subheadline/body; long permission and recovery instructions must wrap.
- Numeric opacity: monospacedDigit for percentage only.
- Dynamic Type governs interactive copy and panels. Do **not** use fixed heights that clip text.
- Support English in current code, with copy and widths prepared for Simplified Chinese localization; do not hard-code a Latin anatomy term as the only label.

### 6.3 Spatial and touch scale

- Base spacing grid: 4 pt; common distances 8, 12, 16, 20, 24 and 32 pt.
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
| MirrorControlDock | Focus, pause/resume, opacity disclosure | Focus, opacity, isPaused |
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

### D0 — Design audit and prototype (this document)

- Document current live-screen behavior and truthfully label source vs aspirations.
- Compare three real visual directions and approve one baseline.
- Create iPhone-sized static screen concepts for: searching, tracking, paused, permission denied and camera interrupted.
- Build an interactive visual prototype **only after design direction approval**; a browser prototype is not evidence of native camera success.

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

### D4 — Android adaptation (later)

- Preserve the same product language and UX principles, but use native Android conventions; do not pixel-copy iOS controls into Jetpack Compose.
- Match landmark, 3D pose and fail-closed behavior with platform parity tests.

## 12. Design acceptance checklist

### Core outcome

- [ ] Camera is visually dominant; a person remains visible through the UI.
- [ ] Normal path stays launch → camera permission → automatic tracking → reference overlay.
- [ ] No extra onboarding step, account, calibration wizard or secondary camera is required.
- [ ] Proxy is called proxy everywhere; educational/nonmedical disclaimer remains reachable and persistent.
- [ ] Lost/uncertain pose removes inaccurate geometry and gives practical guidance.

### Interface quality

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

## 13. Design decisions still open

1. **Visual approval:** Proceed with A — Instrument Mirror or revisit B/C after mockups?
2. **Opacity hierarchy:** Visible slider in first version or a compact disclosure, based on real-device usability.
3. **Camera permission recovery:** Should an explicit manual Retry button accompany the Settings deep link for recoverable interruptions?
4. **Reference disclaimer wording:** Select short text balancing permanent clarity and screen space, then validate Chinese/English.
5. **Target device range / performance:** Confirm real physical device findings before finalizing size and frame pacing assumptions.
6. **Reviewed full atlas:** No appearance or anatomy-detail workflow approval until underlying assets, licensing, projection and physical evidence are complete.

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

**Handoff rule:** Design improvements must remain faithful to the phone-only reference-anatomy mirror and clearly distinguish **implemented source**, **compiled source**, **real-device verified behavior**, and **future reviewed anatomical rendering**. Update this DESIGN.md when the design direction is approved or current mobile functionality materially changes.
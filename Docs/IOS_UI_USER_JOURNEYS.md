# MagicMirror 2.0 — iPhone UX Screen and User Journey Handoff

**Date:** 2026-11-07  
**Style:** B — Leonardo Anatomy Notebook, selected by the product owner  
**Platform:** iPhone / native SwiftUI / iOS 17+ only  
**Authority:** Root DESIGN.md, AGENTS.md and the current iOS code  
**Status:** Design implementation and specification; no claim of real-iPhone validation or licensed multi-system anatomy

## 1. Whole-app information architecture

MagicMirror is a camera-first app, not a multi-tab educational dashboard.

- **Live Mirror (default):** one rear camera, on-device pose inference, translucent educational reference, recognition/framing status, region selector, opacity and Pause overlay.
- **Anatomy Folio (sheet):** Systems and Sections pages. Only the illustrative reference proxy is available in the current build; the rest remain clearly planned and read-only.
- **Field Notes (sheet):** Use, Privacy and About pages. Includes four practical starting steps, permission and local processing explanations, educational limits and an optional local diagnostics toggle.
- **Camera states:** Preparing, Camera Access, Searching, Partial, Tracking, Paused, Camera Off and Interrupted. Each state has user-facing copy and recovery behavior; there is no fake tracking animation.

There is no account, onboarding wizard, feed, cloud sync, photo gallery, forced tutorial or desktop companion. Optional sheets can be dismissed to the live camera.

## 2. Main camera user flow

1. Launch directly into the live mirror (no extra tap before camera start). Request iOS Camera permission if necessary.
2. Aim the rear camera at one person. A visible arm or shoulder span can begin partial tracking. Full torso registration requires a reliable shoulder/hip anchor.
3. Automatically show only confidence-gated visible anatomy segments. If tracking is lost, remove stale proxy geometry and provide concise framing guidance.
4. Switch Whole, Arms or Legs to change the body region. This is distinct from selecting an anatomy system.
5. Tap Opacity to reveal the 15–90% slider, or Pause to hide the overlay while leaving the camera preview active.
6. Open Layers for the anatomy catalogue, or Field Notes to learn safe operation, privacy and limitations.

## 3. Visual design rules

- Live camera fills the background; never apply an artificial sepia color filter to source video.
- One very thin manuscript-style brand/status row stays within the safe area. Its visual strip can look about 34 pt tall, but all interactive hit targets must be at least 44 pt.
- A compact parchment dock sits at the bottom: paper #F3EBDD, deep sepia #332D27, copper #A67952, verdigris #38675D.
- Sparse manuscript dividers, folio numbers and restrained serif titles evoke Leonardo; buttons and body copy use scalable, clear native system styles.
- Target 70% or more visible camera composition in the collapsed/default state, but prioritize legibility, camera content, accessibility font sizes and safe areas over a rigid ratio.
- Complex controls live in native sheets rather than continuously covering the person.

## 4. Native UI component inventory

| Component | Responsibility | Current status |
| --- | --- | --- |
| MirrorScreen | Camera-first composition and actions | SwiftUI source |
| LeonardoPalette / ManuscriptRule | Shared semantic visual primitives | SwiftUI source |
| MirrorPresentationState | Deterministic phase/coverage/paused presentation | Swift source and XCTest source |
| AnatomyLayersSheet | Systems/Sections folio with honest availability | SwiftUI source; real anatomical layers are not activated |
| MirrorGuideSheet | Use/Privacy/About notes and diagnostics toggle | SwiftUI source |
| MirrorViewModel | Live session lifecycle and current observation | Existing implementation |
| MetalSkeletonOverlay | Current reference and validated future anatomy | Existing source; device acceptance incomplete |

## 5. Future anatomy UI (not yet functionally available)

- Anatomy-system selection may eventually combine skeletal, muscle, organ, vessel, nerve, and joints/ligaments groups, with independent visibility, Solo and opacity.
- Exact layer inventory must come from truly reviewed, independently licensed and rigged model assets; mockups are not evidence of shipping features.
- Axial, sagittal and coronal section controls require real 3D clipping/capping and verified model/camera registration. A decorative line over a preview is not an anatomical cross-section.
- A future contextual anatomy note can show reviewed anatomical nomenclature and provenance without claiming knowledge of the user's internal anatomy.
- Keep the one-screen live mirror as the default even if additional educational tools eventually ship.

## 6. Accessibility and failure-state QA

- Compact and large portrait iPhones: header, status, help button and dock do not clip.
- Dynamic Type: action controls stack when needed, sheets scroll and descriptions wrap.
- VoiceOver: meaningful labels for buttons, segmented Picker, Slider, Toggle and unavailable systems. Avoid announcing landmark updates at camera frame rate.
- Reduce Motion: opening opacity controls needs no animation; native sheet interactions remain simple.
- Bright/dark camera scenes: small reliable dark status scrim; clear contrast on all paper controls.
- Camera denied: Camera Off with system Settings recovery; denied permission must outrank the user's previous Pause setting.
- Camera interrupted or backgrounded: no stale bones, false Tracking label or unsupported status certainty.
- Local diagnostics: pose callback delivery cadence only, not verified display FPS or true movement-to-display latency.
- Privacy and medical honesty: no automatic camera recording, uploads or claims of personal X-ray or diagnosis.

**Technical validation required before release:** Xcode simulator build, execution of relevant tests, actual iPhone camera and layout checks, VoiceOver and Dynamic Type on device, source-frame association and latency measurements, sustained battery/thermal tests, licensed asset review and TestFlight/privacy compliance.

## 7. Handoff principles

The design Agent may refine SwiftUI screen composition, copy, accessibility and sheet UX without modifying MediaPipe tracking, Metal shaders or anatomical rig calibration. The coding Agent must not enable unsupported Z-Anatomy layers merely because they appear in the folio. Every future view must describe its user goal, state and failure behavior, underlying capability, accessibility contract and reproducible validation.

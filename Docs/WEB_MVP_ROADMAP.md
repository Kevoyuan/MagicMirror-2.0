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
- [ ] Verify full Web CI results on final PR head and fix failures.
- [ ] Run a real desktop browser and mobile Safari camera smoke test;
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

- Move blocking synchronous pose inference to an appropriate
  browser-worker pipeline with verified frame transfer and fallback.
- Instrument capture timestamp to inference to drawn overlay to
  actual display, with bounded drop-old backlog; do not label
  callback rate as FPS.
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

## W3 · Body-to-camera 3D registration

- Human-reviewed anatomical rest anchors/length constraints, stable
  3D camera/body hypotheses, reprojection bounds and side identification.
- Real motion following, occlusion, orientation handling and
  transparent layering; under uncertainty hide, never fake X-ray.
- Independently test against real browser frames and named devices;
  no clinical or measured-bone claims.

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

# ADR-003 — Web open source first; freeze native iOS development

**Accepted:** 2026-11-08 (explicit owner decision)
**Supersedes:** ADR-002 as the *active shipping and development priority*.
**Retains:** ADR-001's MediaPipe-only inference direction and ADR-002's
nonmedical, local video processing and fail-closed anatomy quality rules.

## Decision

1. Make the **Web browser** the only actively developed MVP client.
   A shareable open-source site is the first public product goal.
2. `Web/` uses TypeScript + Vite + MediaPipe Tasks Vision Web +
   Three.js. Browser-based camera/pose inference; no separate Python
   sidecar, Unity runtime, cloud inference API, login, or proprietary
   client requirement.
3. Preserve `Mobile/iOS/` SwiftUI/Metal history **unchanged and
   frozen**. No Android work. The current unmerged iOS Draft PRs
   #49–#53 remain historical/on-hold references, **not Web release
   dependencies**. Do not merge them merely to close milestones.
4. Start with an honest GPU 3D **procedural reference proxy**;
   genuine articulated Z-Anatomy/BodyParts3D requires per-component
   rights, documented attribution/share-alike, authored geometry
   rig/skinning, independent body/camera registration and actual
   performance review. No unreviewed FBX ships with the Web MVP.
5. License **only new Web code** under MIT, while keeping anatomy assets
   and model binaries under their own real licenses. Review authorship
   before relicensing the entire mixed-history repository.
6. Public Web deployment remains blocked until the particular Google
   `.task` weights, third-party SDK notices and metrics/privacy
   responsibilities are cleared. A code-only CI build is not a
   releaseable, fully functioning web product.

## Why

The Web offers a no-install test surface, transparent reproducible
research and easier community contribution, with lower App Store
distribution overhead. The expensive problems—real anatomy rigging,
source-specific licensing, correct body/camera alignment—exist on
**both** platforms. Pausing native iOS reduces parallel complexity.

## Consequences / constraints

- `Docs/WEB_MVP_ROADMAP.md` and `Docs/WEB_ARCHITECTURE.md` are
  authoritative. `DESIGN.md` owns active Leonardo visual language
  adapted for responsive browsers, without desktop dashboards.
- `Docs/MOBILE_NATIVE_ROADMAP.md` and ADR-002 are **paused historical
  references**, not current release checklists.
- MediaPipe Web `detectForVideo` is synchronous; M0 throttles it on
  the main thread, discloses its limitations, and does not claim
  validated 30 FPS / exact frame lock. A dedicated worker is next.
- An ordinary RGB camera cannot inspect the user's bones. Don't
  claim X-ray, diagnostic, personalized anatomy or medical accuracy.
- Browser camera access needs HTTPS/localhost; stop tracks on
  background/page exit, no frame persistence or uploads by this app.
- Don't introduce Android, or resurrect the Unity/Python product
  runtime. The `Tools/` and `Unity/` trees remain optional research.
- Public deployment and asset release need separately documented legal
  evidence; a Creative Commons label alone is not a blanket grant
  over third-party NC meshes, SDK models or unauthorized DRM.

## Acceptance

W0 accepted only when code typechecks, synthetic pose/mirroring tests
pass, Web source builds in CI and a real browser camera/WebGL run
is **manually** verified with documented screenshots/FPS/recovery.
CI source compilation alone does not claim device camera success.

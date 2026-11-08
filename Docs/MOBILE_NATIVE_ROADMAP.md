# MagicMirror iOS — exclusive product delivery roadmap (updated 2026-11-07)

**User promise:** launch a phone app, point one phone camera at a person,
see a semi-transparent standard *reference* skeleton automatically follow
their movement. Entirely on device: no computer, Unity, Python service,
cloud AI, account or wearable. A native iOS SwiftUI/MediaPipe **prototype**
now exists and has passed arm64 Simulator compilation; real iPhone operation,
3D anatomical mesh and mobile release readiness are **not yet validated**.

**Authority:** ADR-002_MOBILE_NATIVE_OFFLINE_FIRST.md records the accepted
**iPhone/iOS-only** product scope. Android development was canceled by the owner on 2026-11-07; it is not a deferred milestone. This is the sole active product delivery
roadmap. Docs/ROADMAP.md is archived desktop engineering history. We are
not planning or shipping Windows/macOS versions, and Unity or Python will
not be required in the installed iOS runtime.

## Current source implementation (2026-11-07)

- **Mobile-0/1, source stage:** SwiftUI/AVFoundation rear camera,
  MediaPipe Tasks LIVE_STREAM, timestamp-bound 33 image/world landmarks;
  arm64 Xcode simulator source compilation, no physical iPhone validation.
- **Mobile-2, source stage:** connected translucent Metal 3D **proxy**
  with bounded estimated depth, opacity/focus controls, temporal
  smoothing and original procedural rib/pelvis/cranial silhouettes. This
  is **not actual human anatomy**, a licensed Z-Anatomy atlas or calibrated
  camera-space reconstruction.
- **Mobile-3, preparatory source stage:** native reviewed-atlas manifest
  schema, offline USDZ SHA-256 gate, explicit human-license/anchor review,
  stable reference capture and pure relative 3D joint rotation requests
  in `Mobile/iOS/MagicMirror/Anatomy/`. **The actual atlas USDZ, rig
  binding, licensing and visual runtime are still absent.** See
  `Docs/IOS_ANATOMY_ATLAS_INTEGRATION.md`.
- **Mobile-3/4, hierarchical rig kernel source stage:** reviewed
  `AnatomyAtlasManifest` parent hierarchy plus a frozen
  `BodySimilarityRegistration` now produce rigid, bone-length-preserving
  atlas-space pose frames with parent-propagated joints. Compile-checked
  synthetic XCTest sources cover attachment, low-confidence data and
  scale mismatch. **Not yet wired to a human-reviewed 3D atlas, skinning,
  physical camera extrinsics or real iPhone renderer.** See
  `Docs/IOS_HIERARCHICAL_ATLAS_RIG.md`.
- **Mobile-4, camera-to-rig projection contract:** pure Swift maps
  approved, parent-connected atlas rest vertices through the exact
  source-frame camera model **only after independent camera review
  and a passing P90 reprojection gate**. Synthetic tests are authored;
  no live reviewed Z-Anatomy mesh has been bound to this path, and no
  physical iPhone camera fit has been measured.
- **Mobile-4, preparatory source stage:** implemented optional real
  AVFoundation per-frame camera intrinsics, timestamp-bound calibration,
  explicit 3D pinhole projection, and source-landmark P90 reprojection
  tests. A genuine estimated camera/body extrinsic transform, actual
  approved USDZ bone projection and visual registration remain pending.
  See `Docs/IOS_CAMERA_PROJECTION_AND_REPROJECTION.md`.
- **Mobile-5:** real-device FPS/thermal, accurate occlusion, privacy
  review, TestFlight and actual App Store release preparation remain pending.

The owner elected to **defer physical-device validation while coding
continues**. This does not waive the hardware/asset/legal acceptance gates
before a distributable app can be described as completed.

## Active iOS milestones; each must build and run on a physical iPhone

| Milestone | Deliverable | Exit gate |
| --- | --- | --- |
| **Mobile-0 — native camera shell** | iOS-only Swift/SwiftUI app, one native camera owner, permissions, orientation, source frame ID/timestamps, local-only processing, no account or network | Real camera preview in airplane mode on identified device; no Python/Unity runtime; no data upload |
| **Mobile-1 — live body tracking** | MediaPipeTasksVision `PoseLandmarker` LIVE_STREAM with bundled Lite model, one person, 33 normalized + estimated world landmarks, optional segmentation, latest-only frame queue | Real person moves: landmarks remain on the SAME displayed source frame; drop/recover on occlusion without stalling rendering |
| **Mobile-2 — transparent procedural skeleton** | Rigid connected *proxy* skeleton, skeleton clipping to person silhouette, GPU alpha compositor and automatic framing/reacquisition | No manual bone anchors; walk/raise arm/squat in defined scenes; reference drawing stays over a moving user at a plausibility threshold |
| **Mobile-3 — reviewed coherent anatomy atlas** | Audit original Z-Anatomy asset/attribution; offline mobile mesh export and compression; coherent articulated rig with root/bone transforms | A complete reference atlas renders on actual mobile GPU without violating licenses, with proper connected limbs |
| **Mobile-4 — 3D correspondence** | Port validated IK/fit math from desktop into audited portable/native library; dynamic camera/body space alignment, segmentation, per-frame reprojection and reasonable reference limb movement | Measured real-person labeled landmark reprojection, no persistent detachment; lose/hide on bad fit or wrong left/right; tests on front/side/turning |
| **Mobile-5 — shipping quality** | UI for opacity/pause, explanation labels, thermal/latency instrumentation, camera permissions, offline/privacy, onboarding, device compatibility and TestFlight | Target >=30 FPS, p95 movement-to-display <=150 ms on selected physical device; camera interruption/resume and 10min thermal/battery tests recorded |

Do **not** claim a gate passed because Python unit tests, static C#
parser, or a browser mock passed. Physical smartphone test recordings and
measured latency are needed.

## Current source implementation note

- **Mobile-2 (source):** native Metal 3D tapered-bone proxy from MediaPipe
  image and approximate hip-relative world landmarks, opacity/focus
  controls and time smoothing, with successful Xcode source compilation.
  This is **not a reviewed 3D anatomy mesh** or physically measured
  real-person AR alignment.
- **Mobile-3 (pipeline source):** an optional, fail-closed reviewed
  whole-atlas binary/manifest reader, credited licence checks, pinned
  original-FBX offline Blender export and per-mesh reference anchors.
  **No full Z-Anatomy asset has been bundled, authored, run or reviewed.**
- **Mobile-4 (math source):** pure Swift two-link IK and right-handed
  atlas registration kernels; they do not make the proxy a calibrated
  anatomically correct real-person rig.
- **Mobile-5:** iOS release and real-device acceptance remain
  unimplemented. User has chosen to defer physical validation now,
  not to waive release acceptance requirements.

## Architecture work packages

### Mobile runtime (iOS only; implemented native source prototype)

```text
Mobile/iOS/MagicMirror/
  App/                      native SwiftUI state, permissions, privacy
  Camera/                   single captured-frame source + geometry
  Tracking/                 MediaPipeTasksVision LIVE_STREAM adapter
  Motion/                   native IK + frozen/reference model
  Anatomy/                  reviewed skinned atlas import/metadata
  Rendering/                Metal camera + alpha skeleton compositor
  Calibration/              automatic fit, confidence and invalidation
  Diagnostics/              frame-id/reprojection/latency counters
  Resources/                approved bundled .task + atlas asset
```

The native iOS source and XcodeGen project already exist and compile for
an arm64 Simulator in GitHub Actions. A real iPhone installation and camera
validation are still required; do not equate compilation with hardware
acceptance or reintroduce a Python/Unity runtime.

### Interoperability from existing source

Export deterministic fixture vectors from the current compiled M4/M5
math and pose-frame protocol. New mobile native code must pass **parity
tests** for 3D handedness, body/world coordinates, left/right IDs, IK
joint limits, frame identity, pinhole intrinsics and source-to-display
mirroring.

Do not ship a loopback TCP receiver or run a localhost Python process
inside the app. Keep any offline FBX optimization scripts in development
only; the installable phone application bundles finalized audited assets.

## Usability contract

The normal path is a one-screen experience:

1. Open -> camera permission (only first run) -> live unmirrored rear camera.
2. One person enters frame -> detect shoulders and hips automatically.
3. After a short quality-gated stabilization, draw semitransparent **reference**
   bones; do not require tapping a calibration button.
4. Move the arm/knee/body -> pose and anatomical bone rig follow together.
5. Tracking dropout -> fade affected bones, then resume on reacquisition.
6. Optional opacity and pause controls appear without covering the subject.

A full-body skeleton requires the subject to be far enough away to
appear sufficiently in frame; on limited phone focal lengths or a close
selfie this may be impossible. Provide a clear, friendly framing hint and
optional upper-body mode rather than manufacturing missing bones.

## Risk register and how to validate

| Risk | Evidence required |
| --- | --- |
| Camera/pose frame mismatch | Image + landmarks bound to one capture timestamp; native automated fixture and physical capture checks |
| "Looks like X-ray" false confidence | Permanent illustrative/nonmedical label; all product copy tested for clarity |
| Wrong body side under mirror | Deliberate front/rear camera flip matrix, explicit real-movement left/right tests |
| Pose world lacks calibrated camera extrinsics | Test known camera intrinsics, dynamic body↔camera pose estimation, real reprojection |
| Full atlas huge/unrigged | Mobile-optimized offline asset conversion, rig audit, measured memory/GPU and attribution |
| Segmentation hides intended inside-body bones | Custom person-silhouette compositing; avoid blanket occlusion that masks all virtual anatomy |
| Moving/turning people, occlusion | Defined motion dataset with manual visible-joint labels, quality gates and fade behaviour |
| Battery / thermal throttling | >=10-minute sustained session metrics on named models, optional Lite fallback |
| Device variation | Capability-driven ARKit depth fallback on supported iPhones, no dependency on LiDAR/ToF |

## Definition of first usable mobile MVP

A user installs a signed app on a supported phone, disables networking,
grants camera permission, points its built-in camera at **one person**,
sees a clearly marked standard semitransparent skeleton appear automatically,
and watches the skeleton continue to follow visible joint motion with no
external machine, sensor, service or account.

The MVP can initially use a coherently rigged *proxy skeleton* pending
asset audit, but it must be labelled as such and cannot be represented as
the final verified Z-Anatomy full atlas. The final product acceptance also
requires reviewed anatomical content and appropriate device benchmarks.

## Next executable tasks (iOS only)

**First blocking gate:** install the existing signed native app on a named
iPhone, validate actual camera permission/foreground/background recovery,
partial and torso tracking, overlay orientation, frame identity and
Airplane Mode. Collect real FPS, p95 movement-to-display latency, thermal
and battery evidence; do not substitute CI builds or callback cadence.

**Parallel code work:** keep source-only tests for camera/body projection,
front/side/turn ambiguity, atlas-hierarchy invariants, and missing joint
fail-closed behavior. Only connect licensed, human-reviewed 3D atlas assets
after source identity, rig hierarchy, joint bindings, attribution and true
camera registration have been independently verified. The Leonardo layers
sheet must not expose fake anatomy while assets remain blocked.

**After iOS hardware and anatomy gates:** prepare iOS release accessibility,
privacy, TestFlight, signing and App Store acceptance. No Android development
or cross-platform parity work is planned.

## Mobile-5 UI source update — 2026-11-07

A camera-first native SwiftUI Leonardo layout is implemented in source:
compact header, collapsed opacity disclosure, accessible Layers sheet,
retained working region focus and permanent reference/nonmedical disclosure.
The anatomy sheet deliberately marks all detailed anatomy systems and
section planes unavailable; only the procedural reference proxy is active.
Its safe availability mapping is covered by new XCTest source.

This advances the **UI/source** part of Mobile-5, not its device exit gate.
Actual iPhone display sizing, VoiceOver/Dynamic Type QA, on-device camera
registration, latency, heat, battery, privacy acceptance, TestFlight and
shipping remain outstanding. Mobile-3 licensed rig integration and Mobile-4
validated camera-space alignment remain independent blockers. The former
Mobile-6 Android milestone has been canceled.

## Mobile-3/4 coherent mesh connector — source work (2026-11-07)

A pure Swift triangle adapter now checks correspondence between the
reviewed binary mesh manifest and the separately validated hierarchical
bone manifest, then projects complete atlas triangle commands through
the existing same-frame, independently reviewed camera projection gate.
Missing, mismatched or unprojectable anatomy fails closed. Source
XCTest fixtures exercise a successful synthetic path and rejected
source revisions, bone node paths and landmark IDs.

This narrows the **source-level** gap between 3D forward kinematics and
atlas mesh geometry. It does not install a reviewed anatomy model or
activate the GPU atlas, and it does not satisfy the real-iPhone
calibration, licensing, latency or TestFlight exit gates.

## Mobile-3/4 calibrated Metal bridge — source stage (2026-11-07)

Added a fail-closed native `CalibratedAtlasDrawBatch` factory to convert
validated coherent, source-camera-projected mesh triangles into renderable
Metal vertex buffers. The Metal overlay consumes such a batch only when
the source frame timestamp/size, viewport, selected focus and opacity
match, otherwise it retains the procedural reference proxy. Removed the
older automatic weak-perspective atlas display branch from the GPU renderer;
it did not establish independently reviewed physical camera extrinsics.

No runtime producer of calibrated atlas batches exists yet because model
redistribution, rigging/vertex attachment, independent camera/body pose,
real iPhone validation and licensed assets remain blocked. New synthetic
XCTest source checks valid projected geometry and fail-closed behavior,
but CI `build-for-testing` is not device validation. The iOS-only platform
scope remains unchanged.

## Mobile-3 offline asset verification slice (2026-11-07)

The developer-only Blender exporter now invokes an independent
standard-library `MMATLAS1` verifier after writing its atlas package.
A standalone CLI and CI-tested synthetic fixtures reject wrong source
pins, missing review records, damaged binary lengths/hashes, broken
triangle spans, malformed rest anchors and invalid vertex data.

This is a **build-time structural gate**, not asset release acceptance.
A human must still perform mesh-level copyright/attribution review,
complete reviewed bone hierarchy and skinning/attachments, generate the
actual optimized model, and validate calibration and rendering on an
identified iPhone. Only iOS work is planned.

## Mobile-2/4 live articulated proxy — runtime integration (2026-11-07)

The native `MirrorViewModel` now captures a stable estimated MediaPipe
world reference and applies the existing native `TwoBoneIK` kernel to
eligible observed arm and leg chains on every matched camera callback.
The resulting **geometry-only** pose is fed through `MirrorScreen`
into the existing `MetalSkeletonOverlay`, which requires matching
capture timestamp/image dimensions. Frozen lengths, per-joint confidence,
pixel displacement and projection-quality gates prevent unconstrained
joint movement. Camera/pose dropout, pause, stale data or image
resolution changes reset the reference.

This is an implemented **on-device source/runtime path** for the
original procedural 3D proxy, not proof of usable iPhone performance,
validated camera extrinsics, a 3D licensed anatomical atlas, proper
skinning, hidden-bone reconstruction or passed live XCTest. It does
not satisfy the Mobile-3 reviewed anatomy model gate or Mobile-4
real-person calibrated registration exit gate. Future code should
prioritize those substantive gaps rather than more standalone stubs.

## Mobile-3/4 native live atlas runtime connector (2026-11-07)

Connected the previously separate verified asset loaders, frozen
body-world reference, reviewed atlas shoulder/hip anchors, coherent
parent-propagated rig planner, independently reviewed same-source-camera
projector and Metal geometry-batch output into the active
`MirrorViewModel` → `MirrorScreen` → `MetalSkeletonOverlay` path.
Resource file loading happens outside the main actor. Source timestamp,
image dimensions, region and viewport mismatch invalidate geometry;
partial tracking and dropouts keep the procedural proxy.

**Not an active anatomically verified AR model:** the repository has no
reviewed distributed atlas binary and the installed app does not provide
independently approved per-frame body-to-camera extrinsics. Both must be
added and checked before real atlas drawing is eligible. Synthetic
camera/mesh regression checks do not lift those gates. Real-device
framing, source-asset legal review and sustained latency testing are
still pending. No Android work is planned.

## Mobile-3/4 3D anatomical surface shading and clip-space fix (2026-11-07)

The reviewed atlas projection now carries source-mesh surface normals
through parent-connected bone rotation, atlas/body coordinate rotation
and reviewed camera rotation into Metal's shaded vertex format. Removed
the flat normal placeholder from calibrated batches. Corrected
normalized camera depth and procedural proxy Z positions into Metal's
0-to-1 clip range to avoid near-plane clipping of stylized rear arcs.

These improvements compile as part of the native renderer but do not
manufacture unreviewed anatomy, real RGB depth, occlusion or a valid
per-device camera registration. The source atlas and iPhone performance
and visual QA gates remain open.

## Mobile-3/4 actual GPU linear blend skinning slice (2026-11-07)

Added a Metal vertex path that blends four source-mesh bone influences
and normals with a per-frame uniform bone palette and calibrated pinhole
camera projection, rather than generating every bent triangle on the
CPU. The app now loads optional, model-SHA-bound, audited skinning
weights and conditionally selects that path when a verified atlas
and independently reviewed camera exist. Source-frame identity,
viewport, focus and opacity gates remain intact. Old proxy and rigid
atlas fallback paths remain available.

This closes the native **shader/palette/runtime plumbing**, not the
reviewed weights authoring, real source atlas, independent camera
calibration, physical iPhone rendering or anatomical correctness gates.

## Mobile-4 automatic candidate 6DoF estimation (2026-11-07)

Added an on-device, robust multi-initialization nonlinear camera-pose
candidate solver using current-frame MediaPipe 2D/3D correspondence and
real camera intrinsic matrices. A throttled background estimate now
feeds an explicitly **unreviewed** local diagnostic; underconstrained
depth/torso geometry or poor reprojection fails closed. The reviewed
anatomy atlas camera provider remains independent and is not unlocked
by this estimated result.

This is a substantive camera-pose algorithm and source-runtime
integration. It still requires real iPhone reprojection statistics,
motion/facing/outlier tests, latency and independent camera/body
calibration before attaching approved anatomy.

## Mobile-3/4/5 true GPU surface sections — code stage (2026-11-07)

Integrated a live 3D half-space section plane with the verified,
GPU-skinned atlas: axial, sagittal and coronal directions are derived
from the current confident torso basis in camera space, and the actual
Metal shader clips on the camera-space interpolated skinned position.
The Leonardo Layers sheet can select a plane, adjust its position and
return to a complete atlas. The controls remain locked unless verified
atlas and camera evidence are present.

**Scope distinction:** this implements 3D mesh *surface clipping*, not
medical/internal volume slices or watertight cut caps. Live phone
facing/occlusion quality, source anatomy/weights and camera registration
still need human and physical-device acceptance.

## Mobile-5 on-camera reference segment inspector (2026-11-07)

Added an interactive camera tap target, exact-aspect-fill segment
hit-testing, live selection highlight and accessible Leonardo notebook
description for observed proxy shoulder/arm/leg/pelvis segments. A
frozen, stale, invisible or out-of-focus segment is not selectable.
Names are educational region labels, not claims of detected bones.
Future licensed per-mesh picking will require the audited geometry
package; this path does not rename proxies as true anatomy.

## Native skinned-mesh GPU reuse (2026-11-07)

Removed routine per-frame rest-mesh rebuilding and rest-mesh Metal
uploads from the audited atlas path. Immutable source geometry is
prepared once for each body focus and cached by live resource identity;
only compact bone palette, camera, clip plane and opacity uniforms
change per frame. Metal's cached vertex buffer replaces the old new
MTLBuffer allocation on every tracked video frame. Validated synthetic
checks cover resource identity across frame/opacity changes. Physical
device throughput, GPU memory pressure, thermal and latency acceptance
remain open.

## Native multi-anatomical system switching (2026-11-07)

Extended MMATLAS1 / optional skin weight loaders to six separate
audited source packages and recorded system identity in the model
manifest. One on-device SwiftUI/MirrorViewModel layer selector
conditionally switches independently verified, registered skeletal,
muscular, organ, vascular, neural or joint mesh sets. Each candidate
layer is evaluated until coherent current-session registered geometry
can actually be drawn; source/license/camera gaps remain locked and
the existing proxy is always available. This is **code-level layer
switching**, not a claim that all third-party anatomical systems have
passed human source licensing, joint review, device calibration or
iPhone performance checks.

## Mobile-5 registered source mesh picking (2026-11-07)

Implemented tap-time perspective-correct picking of currently skinned,
source-attributed 3D mesh triangles. The picker respects bone weights,
camera frame/crop, nearest surface depth and active half-space clip,
and the actual Metal vertex shader highlights the verified part
without reuploading geometry. A separate Leonardo note displays
reviewed source display names. This is NOT observed human internal
tissue: only legally/anatomically reviewed model source metadata
qualifies. No unreviewed source is bundled or auto-unlocked.

## Mobile-3 offline six-system source-to-MMATLAS1 exporter (2026-11-07)

Expanded the Blender-only geometry exporter and Python structural
preflight across six *actually existing* Z-Anatomy FBX sources at
the pinned Git commit, preserving original byte/blob provenance per
system. Optional LBS skinning data now comes only from explicitly
reviewed authored Blender vertex groups and named hierarchy bone IDs.
The native app can load those independent artifacts with no runtime
Python/network. Approved USDZ hierarchy authoring/packaging, licensing,
anatomical bindings, full size/performance and live iPhone acceptance
are still separate gates.

## Native multi-system anatomy compositing (2026-11-07)

Expanded the preexisting single-reviewed-system selector into
**simultaneous** skeleton/muscles/organs/vessels/nerves/joints reference
layer controls with independent opacity, source-specific pigment, and
stable per-frame Metal compositing. Resource loading remains offline,
separately SHA/rig/weights-reviewed per system; the user can clear all
reviewed systems and return to the illustrative proxy. The renderer
retains multiple immutable mesh buffers within a bounded GPU LRU.
Cross-frame geometry and incorrectly sectioned rigid layers are not
composited as if verified.

This is shipped *source code* and native UI plumbing, not bundled
approved Z-Anatomy multi-system assets, verified physical camera
registration, or a proved medical internal-reconstruction effect.
Real-device acceptance remains an independent step.

## Mobile-4 exact-frame person silhouette clipping (2026-11-07)

Integrated a one-person MediaPipe segmentation mask into the existing
source-matched camera/pose result. Task-owned pixels are copied before
returning from its callback, transmitted with the same frame and
sampled by the unified Metal shader with the original aspect-fill
crop. It affects proxy, independently reviewed rigid and all active
GPU-skinned anatomical layers in one render pass. Missing masks
preserve existing source-matched rendering without fabricating
foreground silhouettes. This improves reference-geometry background
clipping but is **not** true internal-tissue depth occlusion.


## iOS-only business decision: paid App Store, fail-closed source rights (2026-11-08)

Owner selected a **paid iPhone/iOS MagicMirror**, not an Android port.
The product's original code can be monetized independently of
third-party model licensing; no Z-Anatomy/BodyParts3D asset is
authorized for commercial delivery merely because upstream uses CC
BY-SA. Some original subassets have NC terms and Apple packaged
App Store DRM/distribution needs a separate compatibility review.

A new actual XcodeGen **Release pre-build and .app post-build scan**
enforces a per-asset paid release license ledger, pinned checksums,
SDK/license notices and explicit named owner/legal review. The
`paid-app-clearance.json` starts **UNAPPROVED** and automatically
blocks all Release/Archive builds; Debug remains available for
research. The preflight includes independent commercial rights for
the pinned PoseLandmarker **weights** as well as the MediaPipe
Apache-2.0 SDK. No legal authorization is claimed by CI.

**Preferred Mobile-3 completion:** commission original anatomy mesh,
human-reviewed coherent rig/weights, suitable written exclusive
commercial usage rights and actual iPhone measured alignment.
Then finish Mobile-5 privacy, notices, StoreKit/paid listing, TestFlight
and required independent legal release approval.
See `Docs/PAID_IOS_APP_STORE_RELEASE_POLICY.md`.


### Commercial source decision: DBCLS original vs commissioned (2026-11-08)

Direct official DBCLS BodyParts3D 4.0 OBJ data now has an official
2025 CC BY 4.0 license statement, distinct from the mixed-source
Z-Anatomy derivative. This is a **potentially lower-cost, lower-chain-
complexity** input; **both** CC BY 4.0 and CC BY-SA 4.0 contain
no-effective-DRM restrictions, so neither is automatically cleared for
a paid protected App Store binary. Avoid unapproved conversions or
misattributed derivatives. Compare a lawfully cleared direct OBJ
pipeline against commissioning independently authored iOS rigged
geometry. See `Docs/PAID_ANATOMY_MODEL_SOURCE_OPTIONS.md`.

## Selected CC BY-SA commercial asset route (2026-11-08)

Implement separate, publicly downloadable **model geometry** and
human-reviewed author/rights evidence, while preserving independent
closed-source paid iOS app code. A new synthetic-tested
`sharealike_publication.py` produces exact-model CC BY-SA ZIP +
readable OBJ, complete per-mesh provenance, credits, modification
record and SHA ledger. `paid_release_gate.py` verifies that the actual
app atlas is byte-for-byte the same geometry as the public model;
the Field Notes screen conditionally shows the exact public download
URL only when a reviewed atlas is bundled and the release notice is
present. This is conditional **legal/engineering preparation**, not
permission to ship. Public CC license terms do not override third-party
NC nor eliminate Apple DRM incompatibility; independent review is
still required. See `Docs/PAID_IOS_APP_STORE_RELEASE_POLICY.md`.

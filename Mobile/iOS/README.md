# MagicMirror iOS — native camera + local pose overlay

**Status:** Native iOS implementation in progress. This first slice renders a
shaded, translucent **volumetric 3D proxy bones** from 33 MediaPipe surface
landmarks and optional body-relative world estimates. This is **not** an
accurate 3D Z-Anatomy FBX rig or an image of a person's actual internal bones.

The installed app uses SwiftUI, AVFoundation, and MediaPipeTasksVision.
**No Unity, Python server, desktop connection, cloud processing, account, or
wearable device** is required at runtime.

## Prepare a development Mac

Install Xcode 16+ and XcodeGen (`brew install xcodegen`). Attach a physical
iPhone running iOS 17 or newer, and set up your Apple signing team. From the
repository root:

```bash
bash Mobile/iOS/Scripts/fetch_model.sh
cd Mobile/iOS
xcodegen generate --spec project.yml
open MagicMirror.xcodeproj
```

In Xcode choose the **MagicMirror** scheme and your connected iPhone.
Select your development team under Signing & Capabilities, then Run.
Allow camera access on the first launch. Point the rear camera at **one
person**. A visible arm or shoulder span is enough to try partial tracking;
shoulders **and** hips together unlock torso-anchored anatomy alignment.
The app draws only segments with two confident joints, so a partial view
may show fewer bones or no overlay if the model cannot see a valid segment.

After installation, test in Airplane Mode: no model downloads or API calls
are present in the app. The build-time MediaPipe Swift package and bundled
model require network during developer setup only.

For a simulator **compilation** check, without a camera:

```bash
xcodebuild -project MagicMirror.xcodeproj -scheme MagicMirror \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build-for-testing
```

## Adaptive partial-body tracking

MediaPipe can provide 33 landmark estimates even when parts of the body
are out of frame; estimated landmarks are not automatically trustworthy.
The iOS pipeline now distinguishes **searching**, **partial tracking**
(at least one observed, confidence-gated segment), and **torso-anchored
tracking** (both shoulders and hips). Each segment and each body region
has independent confidence evaluation. The procedural Metal limb proxy
can follow a single reliable visible arm without inventing missing limbs.

Full torso, rib, pelvis, and cranium reference geometry still require
its original observed anchors; approved Z-Anatomy atlas placement,
reference-pose capture, and 3D motion planning retain the strict
four-point torso gate. The original 80ms temporal filter handles valid
joints individually and now preserves per-capture camera intrinsics.
No standalone hand detector is introduced; partial-body detection
quality and jitter need physical iPhone testing.

## Improved original procedural skeletal silhouette

Until the full original reference atlas is individually reviewed, the
offline native Metal fallback now includes lightweight **stylized rib-cage
arcs**, connected **pelvic hoops** and a **cranial outline** in addition to
the limb spindles. These features are generated only when the shoulders,
hips (and both ears for the cranium) are confidently observed.

The shapes are *new, original procedural educational illustrations*, not
individual recovered bones, real anatomical rib numbers, patient anatomy
or a licensed Z-Anatomy model. The renderer continues to show the procedural proxy unless a separately
calibrated, same-frame atlas draw batch is supplied; a binary review flag
alone never enables live anatomy. The region-focus control preserves the
arms-only and legs-only views without ribs or head arcs.

The extra geometry uses six-sided tube segments to limit per-frame CPU
mesh generation and Metal vertex traffic. Geometry and gating are covered
by Xcode-compiled XCTest source; actual iPhone CPU/GPU timings are pending.

## Exact-frame Metal camera compositing (new)

In tracking mode, `CameraPosePipeline` now retains **at most six** source
BGRA buffers for a maximum of 160ms. The asynchronous MediaPipe callback
can consume ONLY the buffer with the exact same capture timestamp as
the 33-point pose. These are published as one `AlignedPoseVideoFrame`.

`MetalSkeletonOverlay` renders that **source image first** and then the
proxy/approved anatomical triangles in one Metal command buffer/drawable.
`VideoAspectFillCrop` uses the source frame's actual width/height and the
view's current size. The on-device skeleton and video can no longer be
silently taken from unrelated source timestamps during tracking.

**Fallback:** if no pose, tracking is lost, the GPU cannot wrap the BGRA
buffer, or the app is paused, the transparent Metal layer clears and
the same-session `AVCaptureVideoPreviewLayer` underneath continues showing
live video. This is not a second camera or an upload.

**Trade-off:** while tracking, displaying only completed MediaPipe source
frames can increase apparent video latency and reduce displayed camera
frame rate. Benchmarks must measure actual camera-to-photon p95 on a
physical iPhone before declaring real-time product acceptance. Timestamp
matching alone does not prove fast enough motion response.

## What is included

- `App/MirrorScreen.swift`: SwiftUI one-screen, camera permission hint,
  opacity control, pause, and an always-visible nonmedical label.
- `App/MirrorViewModel.swift`: iOS Observation state with small view
  invalidation and 300ms stale-pose expiration.
- `Calibration/CameraIntrinsicMatrixReader.swift`: on supported
  AVFoundation formats, read source-frame 3x3 intrinsic matrix; never
  synthesize focal length or copy a matrix from a different frame.
- `Calibration/BodyCameraProjection.swift`: pure camera-space pinhole
  projection and visible-landmark P90 registration check requiring an
  independently supplied body-to-camera transform.
- `MagicMirrorTests/CameraIntrinsicMatrixReaderTests.swift` and
  `BodyCameraProjectionTests.swift`: synthetic matrix identity,
  3D reprojection, confidence/frame mismatch tests.
- `Tracking/BoundedVideoFrameStore.swift`: local BGRA memory retention,
  frame timestamp matching, bounded buffer size and session reset.
- `Rendering/VideoAspectFillCrop.swift`: video texture-to-preview crop
  mapping, shared with the pose geometry conventions.
- `Rendering/MatchedCameraShaders.metal`: direct BGRA texture sampling
  into the Metal drawable before bone shading.
- `MagicMirrorTests/MatchedVideoCompositorTests.swift`: synthetic
  source-buffer ownership, eviction and crop parity tests.
- `Tracking/PoseFrameAssociationGate.swift`: bounded timestamp-to-source-
  dimensions mapping for asynchronous LIVE_STREAM callbacks; rejects stale,
  replayed, out-of-order and old-session results, with no stored pixels.
- `MagicMirrorTests/PoseFrameAssociationGateTests.swift`: XCTest covering
  exact frame dimensions, eviction, lifecycle reset and source ordering.
- `Camera/CameraPosePipeline.swift`: **one AVFoundation rear camera**,
  32BGRA portrait video, monotonic timestamps, and MediaPipe
  `.liveStream` running **on device**.
- `Camera/CameraPreview.swift`: native preview layer using the exact
  session that supplies inference frames.
- `Tracking/PoseGeometry.swift`: typed 33-point observations, confidence
  gates and aspect-fill coordinate mapping.
- `Anatomy/AnatomyAtlasManifest.swift`: fail-closed reviewed model
  metadata + local bundled USDZ SHA-256 check (no atlas shipped yet).
- `Anatomy/AnatomyReferenceCapture.swift`: stable multi-frame median
  body reference capture for eventual approved 3D rig.
- `Anatomy/AnatomyMotionPlanner.swift`: relative 3D bone rotation
  requests from MediaPipe world landmarks; not a camera transform.
- `MagicMirrorTests/AnatomyAtlasManifestTests.swift` and
  `AnatomyReferenceCaptureTests.swift`: synthetic manifest, hierarchy,
  reference stability and motion-contract XCTest source.
- `Rendering/MetalSkeletonOverlay.swift`: native transparent GPU renderer
  with **no second camera or ARSession**, composited over the preview.
- `Rendering/VolumetricBoneMesh.swift`: connected tapered 3D bone proxies
  and bounded illustrative depth; this is not individual anatomy.
- `Rendering/SkeletonShaders.metal`: shaded translucent mesh shaders.
- `Tracking/PoseTemporalFilter.swift`: 80 ms time-aware pose smoothing,
  reset on dropout, pause or session stop.
- `Rendering/PoseSkeletonOverlay.swift`: older 2D Canvas research fallback,
  no longer used by the primary screen.
- `MagicMirrorTests/PoseGeometryTests.swift`: camera crop, visibility,
  nonfinite values and left/right conventions.
- `MagicMirrorTests/VolumetricBoneMeshTests.swift`: mesh topology,
  dropout, proxy depth and smoothing regression cases.

The MediaPipe result now uses captured geometry and optional focal
length/principal point saved for its *own* source timestamp, rather
than taking the newest camera frame's dimensions or intrinsics.
This reduces 2D overlay drift after source resolution/orientation changes.
The native preview layer can still display a newer frame than inference:
actual end-to-end frame alignment and perceived latency require iPhone tests.

The unmirrored rear-camera buffer is rotated to portrait before both
tracking and preview. The source coordinate system is **not secretly
flipped**; left/right anatomical IDs remain standard MediaPipe indices.

The app needs camera permission once. Frames are not uploaded, saved to
Photos or logged. Model inference is local. User tracking can temporarily
disappear under occlusion or when the subject leaves frame; the overlay
hides rather than drawing fabricated bones.

## Model asset identity

`Scripts/fetch_model.sh` downloads the Google-hosted
`pose_landmarker_lite.task` **during app build preparation**, verifies
the exact SHA-256 and byte count, and stages it into the app bundle.

- Size: `5777746` bytes.
- SHA-256: `59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a`.
- SDK: `MediaPipeTasksVision` from pinned MediaPipe Git revision
  `2df17d66d380f74884c1505a7e7ac677020c3980`.

The remote `latest` URL is mutable: **checksum mismatch fails closed**.
No model binary is committed to Git. Review model and anatomical asset
distribution rights before public release.

## Optional reviewed whole-atlas package

`Anatomy/VerifiedAnatomyAtlas.swift` supports a developer-generated,
**human-reviewed** mobile skeleton package. It validates both dataset
attribution licences, the model SHA-256, source hierarchy names,
reviewed segment anchors and contiguous triangle records. If there is
no approved `skeleton_atlas.mmgeom` and
`skeleton_atlas.manifest.json` in the app bundle, the renderer stays
on its procedural 3D reference proxy. No anatomy binary is shipped
by the repository. The exporter runs under **Blender on a developer
machine**, never on iPhone.

See [whole-atlas offline authoring](../../Docs/MOBILE_ATLAS_PACKAGE.md).
The original Z-Anatomy/BodyParts3D derivatives require CC BY-SA
attribution and source/model-specific review. Native mesh projection
is an approximate rigid segment fit, **not** calibrated personal
bone geometry or verified live device performance.

## Atlas import is deliberately blocked pending legal/anatomical review

See [the native atlas integration contract](../../Docs/IOS_ANATOMY_ATLAS_INTEGRATION.md).
The runtime model loader requires a separately reviewed USDZ and human-audited
rig/anchor manifest, and checks the bundled binary SHA-256. A deliberately
invalid example manifest is included under `Docs/examples/`; it is never
packaged into the phone app. The asset itself, actual skin/rig mapping and
camera-space 3D registration are **not complete**.

## Gaps before actual anatomical AR

The source now includes a live **3D volumetric proxy renderer**, but
**not** anatomically accurate 3D bones. The projected x/y endpoints still
come from MediaPipe image landmarks; relative z is an uncalibrated
hip-centered estimate, not an iPhone-camera-space reconstruction. Next:
1. Pass real Xcode build and physical rear-camera capture.
2. Validate portrait orientation and keypoint-to-preview alignment on
   several iPhone screen aspect ratios, including body motion/occlusion.
3. Supply a **real** and separately calibrated body-to-camera pose,
   measured iPhone lens intrinsics, visible-joint reprojection gate,
   and true face/mirror/occlusion handling. See
   `Docs/IOS_CAMERA_PROJECTION_AND_REPROJECTION.md`.
4. Add a **reviewed** mobile 3D anatomy rig, verify source licenses,
   convert the original connected atlas offline to optimized mobile assets.
   No unreviewed atlas mesh is bundled by this PR.
5. Implement dynamic camera/body registration, depth/occlusion and
   independent measured overlay/latency benchmarks.

Source parsing or successful simulator compilation **does not** prove
physical camera behavior or true body-to-anatomy alignment.

## Optional source-frame weak-perspective atlas projection

An independently human-reviewed atlas may use `WeakPerspectiveCameraFit` to
project body-world mesh triangles into the corresponding captured source
image and then the displayed aspect-fill viewport. Fit quality must pass the
P90 reprojection gate and a confident torso anchor is still required. This
is an on-device approximation, **not** calibrated camera extrinsics, a
medical observation of internal bones, or a replacement for the reviewed
coherent hierarchy rig. When projection evidence is missing, atlas geometry
is hidden; an unapproved atlas is never activated. See
[the weak-perspective registration note](../../Docs/MOBILE_CAMERA_WEAK_PERSPECTIVE.md).

## Leonardo camera-first screen and honest anatomy layer explorer

The native SwiftUI screen now uses a compact single-row title/status header
and a smaller parchment control dock. The existing Whole / Arms / Legs
focus remains separate from a new **Layers** information sheet. The opacity
slider expands only when requested; the explanatory nonmedical reference
label remains visible even with the drawer closed. This is a **UI source
implementation**, not a physical-iPhone visual or accessibility acceptance.

The Layers sheet lists the current **illustrative procedural proxy** as the
only available display layer. Skeletal atlas, muscle, organ, vessel, nerve,
and joint/ligament systems remain explicitly labelled **Planned** and are
not given misleading functional toggles. Axial, sagittal and coronal
section planes are described as unavailable until actual registered 3D
clipping exists. This interface does not bundle Z-Anatomy, introduce a
second camera, or turn off local privacy gates. Synthetic catalog XCTest
source enforces that all unreviewed categories remain unavailable.

The next native UI refinement keeps the same AVFoundation/MediaPipe/Metal
pipeline and improves **how** its existing controls are presented:

- A slim manuscript-style camera header with accessible 44-point diagnostics
  control; tracking states now distinguish preparing, blocked and interrupted
  camera states from actual pose acquisition.
- A quiet paper/sepia/verdigris control dock with a notebook folio rule,
  focus Picker, compact Layers/Opacity/Pause buttons, and an always-readable
  reference disclaimer. At accessibility text sizes, action buttons stack.
- A two-page native **Systems / Sections** anatomy notebook. Systems list
  identifies only the current proxy as available; future licensed anatomical
  layers and real 3D section planes remain clearly unavailable. The section
  drawings are visual *concept cues*, not a running clipping engine.
- Respect for Reduce Motion when opening the opacity adjustment, with no
  changes to pose landmarks, retargeting, camera ownership or Metal geometry.

**Verification required:** Xcode arm64 Simulator build-for-testing via CI,
followed by actual iPhone visual layout, VoiceOver/Dynamic Type and
camera/overlay latency testing. This source update does **not** prove
real-device presentation or complete reviewed anatomy.

The **whole-app native UX** now also includes an optional Field Notes sheet with
Use / Privacy / About pages, a simple on-device diagnostics toggle, and a pure
`MirrorPresentationState` mapper that prevents paused/stale pose from
masquerading as live tracking or blocking camera-permission recovery.
`MirrorPresentationStateTests.swift` contains deterministic UI-state tests.
None of these additions requires cloud access, a second camera or a new
navigation tab.

The live image and Metal overlay now have separate SwiftUI observation
boundaries: the sole AVFoundation preview stays in the stable root scene,
while `MirrorLiveRenderSurface` observes frame-rate pose / Metal draw batch
changes. `MirrorViewModel.currentCoverage` only updates when the
recognition class changes (none/partial/torso-anchored), so the manuscript
controls do not need to invalidate on every pose callback. This is a
source-level performance improvement, **not** measured real-iPhone FPS. The guide describes current privacy behavior as source-level
claims; App Store and third-party SDK disclosures still require review.

The SwiftUI mirror and both notebook sheets now use native `Localizable.strings`
resources for **English and Simplified Chinese**. They follow the device's
iOS language; 113 paired source keys have been checked for parity and
empty translations. The design intentionally retains small Latin folio
marks as visual metadata while translating actual controls, status, locked
anatomical systems, camera recovery and VoiceOver-facing descriptions.
The adaptive header falls back to an MM mark on very narrow layouts and
reflows the tracking pill under the brand for accessibility text sizes.
During valid partial tracking it avoids leaving a large guidance card
over the visible body.

**Localization manual QA:** Set iPhone Settings → General → Language & Region
to English and 简体中文 respectively, or use an app-specific language override
where supported. Restart the app and inspect Mirror, Anatomy Folio and Field
Notes at ordinary and very large text sizes. Verify real permission denial
and interruption states, long descriptions and VoiceOver, not only a
Simulator build.

See the [complete iPhone UI journey handoff](../../Docs/IOS_UI_USER_JOURNEYS.md)
and [DESIGN.md](../../DESIGN.md) for the owner-selected Leonardo direction.

## Coherent atlas triangle adapter (research source)

`Anatomy/CoherentAtlasMeshProjection.swift` connects reviewed
`MobileAtlasManifest` triangle groups to the separate
`AnatomyAtlasManifest` hierarchical bone IDs and to source-matched
`CoherentAtlasCameraProjection`. Entire-mesh node paths, joint indices,
rest anchors, triangle bounds and provenance must match; any invalid
binding or projected vertex rejects the batch. Unlike the optional
weak-perspective adapter, this path requires an independently reviewed
camera transform and its P90 source reprojection gate.

**This is not yet a displayed 3D atlas.** No licensed Z-Anatomy mesh has
been shipped, and the live Metal renderer is intentionally not wired to
this reviewed-calibration-only path. Source compilation and synthetic
tests do not establish legal clearance, clinical validity or physical
iPhone alignment.

## Calibrated atlas → Metal draw bridge (source implementation)

`Rendering/CalibratedAtlasDrawBatch.swift` converts a complete validated
`CoherentAtlasMeshProjection` result into the existing Metal vertex format.
Its factory cannot be called with arbitrary screen coordinates: it requires
a reviewed mesh/hierarchy pair and a separately calibrated same-frame camera
projection. It rejects invalid opacity, missing triangles, nonfinite vertex
positions, zero-area triangles, and oversized batches.

`MetalSkeletonOverlay` now accepts an *optional* validated batch and draws
it **only** if the source timestamp, image dimensions, view dimensions,
region focus and opacity still match the displayed source frame. Otherwise
it falls back to the procedural illustrative proxy. The previous automatic
weak-perspective atlas loading in Metal has been disabled, because a matching
mesh filename or boolean review flag alone does not establish physical
camera extrinsics. The old weak-perspective algorithm remains research code.

**Important:** the normal camera screen does not yet construct a calibrated
batch. There is no approved Z-Anatomy asset or independently reviewed live
camera extrinsic provider, so the app continues to render only the reference
proxy. The mapped clip-space depth is still illustrative; source-atlas
surface normals are now rigidly rotated into camera space. Neither is
a measurement of the person's internal tissue or bone geometry. Do not
represent this source bridge as live atlas AR or physical-device verification.

## Offline atlas package preflight

An optional audited whole-atlas build now runs an independent structural
verifier before claiming export success. You can also run it directly:

```bash
python3 Mobile/iOS/Scripts/verify_atlas_package.py \
  --package /private/reviewed/export
python3 -m unittest discover -s Mobile/iOS/Scripts/tests -v
```

The verifier checks the source pin, manifest/binary hash, actual vertex
records, triangle alignment and full hierarchy path coverage. GitHub CI
runs the synthetic regression fixtures. No anatomical assets or model data
are fetched, committed, or redistributed by this test. Human asset rights,
anatomical accuracy, coherent 3D skin/rig and calibrated real iPhone
overlay remain separate blockers; successful preflight never unlocks
an unreviewed model.

## Live articulated procedural rig (Mobile-2/4 runtime slice)

`Motion/LiveProxyRigRetargeter.swift` now runs in the **actual on-device
camera-to-Metal path**. After twelve stable torso observations,
`AnatomyReferenceCapture` freezes estimated body-world reference limb
lengths. Every eligible, fresh MediaPipe pose passes through
`TwoBoneIK.solve` for the four visible arm/leg chains, preserving the
captured upper/lower segment lengths. A same-frame weak-perspective fit
projects each adjusted elbow, wrist, knee or ankle back into the **actual
source image dimensions** before the procedural Metal geometry is built.

This is a **live educational proxy improvement**, not a verified
Z-Anatomy skeleton, calibrated camera extrinsics, personalized bone
measurements or true occlusion. Individual chains fail closed on missing
joints, large length differences, over-clamped targets, nonfinite geometry
or excessive source-image displacement. If the reference is not ready,
the frame is partially observed, or the 3D fit fails, the app retains
its existing confidence-gated partial-body procedural proxy.

Only the geometry uses the retargeted pose: the original filtered
`PoseSnapshot` and its matched source camera buffer remain separate.
Metal accepts the geometry pose only with the **identical source timestamp
and image size**. Dropout, camera stop, pause, stale tracking and
capture-resolution changes reset the reference to avoid carrying a
previous person's body proportions across sessions. The three layer
categories and legal source review remain unchanged.

Synthetic XCTest source in
`MagicMirrorTests/LiveProxyRigRetargeterTests.swift` covers
reference acquisition, fixed limb lengths, stale/replayed frames,
source-resolution changes and loss/reacquisition; normal CI
`build-for-testing` compiles these tests, it does not execute them.
Real iPhone tracking quality, motion latency and battery/thermal load
remain outstanding.

## Live reviewed-atlas runtime integration (source stage)

The native camera screen now has a real, conditional runtime path for a
reviewed anatomical package: it loads both the verified MMATLAS1 model and
the independently checked USDZ/rig manifest in a background task, verifies
their source revision and hierarchy correspondence, extracts consistently
reviewed shoulder/hip rest anchors, captures a stable 12-frame reference,
runs the parent-connected coherent 3D rig, projects all selected triangles
through a source-matched independently reviewed camera transform, and
publishes the resulting Metal vertex batch **only for that same frame and
viewport**. On any missing or invalid input the visible app remains on its
existing procedural reference skeleton; it never guesses camera
extrinsics or invents a source model.

The production camera-calibration provider is intentionally **not
installed**: a camera intrinsics matrix and MediaPipe body-world estimates
alone are insufficient evidence of calibrated extrinsics. No reviewed
Z-Anatomy package is committed/bundled. This means the *code path exists
and compiles*, but the real atlas is still **not displayed** in the
shipping prototype. The synthetic full-path XCTest fixture is a
programming regression, not independent license/anatomy/device review.
Full-mesh per-frame CPU/GPU performance and actual skinning quality still
need physical iPhone profiling before this mode can ship.

## Articulated anatomy normals and safe Metal depth (source implementation)

The coherent camera atlas path now carries **actual verified-model vertex
normals** through each bone's 3D rest-to-pose rotation, atlas/body frame,
and reviewed body/camera rotation before delivering them to Metal. The
shading no longer uses the same flat billboard normal for every triangle.
Only source-authored normals are used, not normals inferred from a user's
RGB camera image. The calibrated projection maps camera depth to
Metal's nonnegative clip range.

Also corrected the currently visible original **procedural proxy** depth:
Metal expects clip-space Z between 0 and 1, so reference rib, pelvis and
skull arcs no longer risk disappearing at the near plane merely because
their illustrative depth is negative. Synthetic XCTest source checks
the normal transform, mesh batch normals, and proxy clip bounds.

There is still **no shipped reviewed anatomical atlas**, no independently
reviewed per-frame body/camera transform provider, and no physical iPhone
GPU/occlusion benchmark. Passing CI compilation is not device validation.

## Native four-influence Metal GPU Skinning (new source implementation)

`SkinnedAtlasShaders.metal` now performs **linear blend skinning on the GPU**
with up to four named bone influences per source vertex. An exact-frame
`CoherentAtlasCameraProjection` supplies independently calibrated
atlas-rest-to-camera bone transforms. The shader blends rest positions and
surface normals, then projects with the source-frame camera intrinsics and
the same aspect-fill crop used for camera video. The renderer selects this
batch ahead of rigid atlas geometry only when source timestamp, image size,
viewport, opacity and focus all match. Missing input preserves the existing
procedural and rigid pathways; no second camera is opened.

The optional `skeleton_atlas.skinning.json` bundle sidecar requires schema
version 1, the identical `sourceRevision`, exact `modelSHA256` of the
original `skeleton_atlas.mmgeom`, `reviewedJointWeights: true`, and exactly
one `vertices` entry per unindexed MMATLAS1 triangle vertex. Each entry
has `boneIds` (four reviewed hierarchy bone IDs) and `weights` (four
finite nonnegative values summing to 1); unused slots have weight zero.
Joint names are not guessed or derived by proximity. A corrupted or
inconsistent sidecar prevents the reviewed atlas package from loading.

No audited weights or original anatomical atlas are bundled today; the
live GPU path is **implemented and compile-tested but not activated on a
real person**. This does not establish real human bone locations, real
camera extrinsics or license approval. Full mesh deformation quality,
transparency and sustained GPU performance need device validation.

## Automatic on-device 6DoF camera pose candidates (Mobile-4)

`Calibration/AutomaticCameraPoseEstimator.swift` now solves a provisional
body-world-to-camera rigid transform from SAME-FRAME MediaPipe 3D
landmarks, observed camera-image 2D landmarks and actual AVFoundation
camera intrinsics. The nonlinear six-parameter robust optimizer tries
multiple initial yaw guesses, uses damped least-squares refinement,
validates torso geometry and minimum 3D depth spread, and rejects
incorrect/nonfinite inputs or excessive global landmark P90 reprojection
error.

`MirrorViewModel` schedules this on a background utility task at most
once every 750 ms while a torso and exact camera intrinsics are
available; it resets on pause, tracking loss or stopping the camera.
The optional **local diagnostics** display a camera *candidate* and its
image P90 error. No images, camera frames, 3D coordinates or calibration
records are saved or uploaded.

**Important:** these are 6DoF candidates from MediaPipe's approximate,
not surveyed, model-space 3D points. They are not independently reviewed
physical camera extrinsics, cannot distinguish every facing/mirror
ambiguity, do not establish actual bone positions, and NEVER automatically
set `independentCameraReviewConfirmed` or authorize atlas rendering.
Real device acceptance, occlusion, source identity and licensed anatomical
assets remain separate gates.

## Native 3D anatomy surface sectioning

A verified **GPU-skinned atlas**, independently reviewed source-frame
camera transform and reliably observed shoulders/hips can now generate
live camera-space **axial, sagittal or coronal half-space cut planes**.
`AnatomySectionCut` constructs mutually orthogonal axes from the
visible torso, transforms the plane into the source camera coordinates,
and the Metal `skinnedSectionFragment` discards fragments on the cut
side of genuinely skinned 3D triangles. The Leonardo Anatomy notebook
shows plane buttons and a shoulder-width displacement slider **only
while the reviewed GPU-skinned mode is actually active**. Ordinary proxy
skeletons do not acquire fake anatomy section controls.

This is real GPU **surface clipping**, not a closed volumetric
cross-section: triangles are cut by a fragment half-space test, no cut
face/cap mesh or interior anatomical tissue is synthesized. Body-world
torso facing is only an estimate; reviewed model and independent
camera/body registration remain mandatory. No source Z-Anatomy assets
or approved skinning weights are shipped with the prototype.

## Tap-to-inspect visible reference parts (interactive iPhone UI)

Tap a visibly tracked arm, leg or shoulder/pelvis reference segment in
the live camera picture. The native hit tester computes the shortest
distance to the **actually rendered procedural segment** after the same
source-image aspect-fill transform as Metal, restricts targets to the
current Whole/Arms/Legs focus and rejects low-visibility or offscreen
segments. A soft verdigris line highlights the selected live segment;
an accessible Leonardo field-note card explains the body region and
explicitly labels it as an illustrative pose guide rather than a
measured anatomical bone. Tapping elsewhere clears the selection.

Selections are invalidated when landmarks disappear, the camera stops,
tracking pauses or a reviewed atlas replaces the proxy. There is no
cross-person persisted identity, image upload, or fake anatomical
structure name. Picking actual Z-Anatomy mesh parts remains conditional
on a separately reviewed atlas and associated geometry metadata.

## Static GPU anatomy mesh reuse (native performance work)

The reviewed 4-weight skinned rest mesh is immutable across camera
frames. The live runtime now prepares its Whole/Arms/Legs vertex arrays
once per approved atlas resource set and reuses them for successive
tracked frames. The Metal renderer keeps one resident vertex buffer for
the active geometry identity and focus, instead of allocating/uploading
up to 180,000 static 80-byte vertices on every callback. Real-time
joint matrices, camera projection, alpha and the 3D section plane stay
dynamic, so body motion and UI controls still update every frame.

The shader now applies opacity from a tiny per-frame uniform, avoiding
a full vertex rewrite when the user moves the opacity slider. A new
reviewed model runtime receives a distinct UUID and invalidates its
previous GPU cache automatically. This is a code-level optimization,
not a claim of achieved physical iPhone FPS, memory or thermal figures.

## Independent multi-system anatomy resource slots (native layers)

The Leonardo notebook now has real selection controls for skeleton,
muscles, organs, vessels, nerves, and joints/ligaments, in addition to
the always-available illustrative reference proxy. Each anatomical
system must provide its **own** offline model bundle and rig, not a
renamed or reused skeleton atlas:

| Layer | MMATLAS1 base name | Reviewed USDZ hierarchy manifest |
|---|---|---|
| Skeleton | `skeleton_atlas` | `anatomy_atlas_manifest.json` |
| Muscles | `muscles_atlas` | `muscles_atlas_manifest.json` |
| Organs | `organs_atlas` | `organs_atlas_manifest.json` |
| Vessels | `vessels_atlas` | `vessels_atlas_manifest.json` |
| Nerves | `nerves_atlas` | `nerves_atlas_manifest.json` |
| Joints/ligaments | `joints_atlas` | `joints_atlas_manifest.json` |

Each `<base>.manifest.json` must match the exact source binary
`<base>.mmgeom`, approved hierarchy, hash and legal attribution.
Additional non-skeleton package manifests require
`anatomicalSystem` equal to the requested layer's raw value
(`muscles`, `organs`, `vessels`, `nerves`, `joints`). The existing
legacy skeleton package may omit that field. Optional
`<base>.skinning.json` carries the audited, model-hash-bound
per-vertex influences.

Independent resource loading runs off-main. A layer only becomes
selectable after its verified source has **actually produced
camera-registered coherent geometry** during the current tracking
session. Switching layers uses one source-matched Metal renderer and
falls back to the educational proxy when reviewed anatomy is
unavailable. The default camera tries skeleton first, but the user
does not need a manual calibration wizard. This repository still
**does not include any independently approved multi-system models or
an approved live camera extrinsics provider**, so the additional
layer controls remain correctly locked in distributed builds.

## Source-authored 3D anatomy tap inspection

When a legitimate reviewed, registered GPU-skinned atlas is displayed,
tapping its actual triangle can now select the human-reviewed
`sourceHierarchyPath` and `displayName` of the corresponding model
part. Tap-time CPU picking uses precisely the displayed pose palette,
four bone influences per vertex, camera intrinsics, aspect-fill
parameters and active 3D half-space cut; it selects the closest
intersected mesh surface in perspective (rather than nearest MediaPipe
joint). The Metal skinned shader highlights the selected source-node
triangle range using a small uniform, preserving its static GPU vertex
cache. Leonardo's accessible detail card identifies the source
reference, not the person's observed internal tissue.

A missing, stale, camera-unmatched or unreviewed 3D source cannot be
picked as anatomy. While only the procedural proxy exists, taps still
use the clearly labeled observed pose guide; tracking dropout or
switching system clears the selection. Actual Z-Anatomy structure
names are not invented by the app: they come only from separately
reviewed part manifests that have passed all local checksum checks.

## Simultaneous independently reviewed anatomy layers

The native iPhone Anatomy notebook can now **toggle more than one**
available reviewed anatomical system at once (skeleton, muscles,
organs, vessels, nerves, joints). Each system has its own verified
offline MMATLAS1 mesh, USDZ hierarchy and optional reviewed skinning
weights, plus a distinctive illustrative pigment and independent
opacity slider. Tap **Reference proxy** to hide all anatomical systems.
An unavailable or unregistered system remains visibly locked; no other
system's mesh is substituted for it.

The live camera coordinator produces exact-source-frame geometry for
every active reviewed system in stable catalog order. The single
Metal renderer composites all matched GPU-skinned and rigid approved
batches on the one analyzed BGRA frame; mismatched frames are skipped
and the clearly labeled procedural proxy is the safe fallback. A
bounded **48 MiB GPU rest-mesh buffer LRU** retains multiple static
approved meshes between frames, while each system updates only its
own small bone palette, projection, opacity and section plane. Section
controls enable only if **all currently drawn enabled systems have
valid GPU-skinned geometry**, avoiding unclipped rigid layers.

This completes source-level multi-system toggles, layering, per-layer
opacity and bounded GPU caching. The repository still ships no legally
approved muscles/organs/vascular/nerve models, and no independently
reviewed camera-body extrinsics; a layer cannot display just because
its switch exists. All tints are educational illustrations, not
actual measured tissue colors. Physical iPhone thermal/performance
and visual behavior still require independent acceptance.

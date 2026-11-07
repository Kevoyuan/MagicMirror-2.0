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
person with both shoulders and hips visible**.

After installation, test in Airplane Mode: no model downloads or API calls
are present in the app. The build-time MediaPipe Swift package and bundled
model require network during developer setup only.

For a simulator **compilation** check, without a camera:

```bash
xcodebuild -project MagicMirror.xcodeproj -scheme MagicMirror \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build-for-testing
```

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

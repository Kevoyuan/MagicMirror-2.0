# MagicMirror iOS — native camera + local pose overlay

**Status:** Native iOS implementation in progress. This first slice renders a
translucent **proxy skeleton** from 33 MediaPipe surface landmarks; it does
**not** yet display the original 3D Z-Anatomy FBX or infer real internal bones.

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

## What is included

- `App/MirrorScreen.swift`: SwiftUI one-screen, camera permission hint,
  opacity control, pause, and an always-visible nonmedical label.
- `App/MirrorViewModel.swift`: iOS Observation state with small view
  invalidation and 300ms stale-pose expiration.
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
- `Rendering/PoseSkeletonOverlay.swift`: small, translucent SwiftUI
  Canvas overlay, using the same aspect-fill crop as the video.
- `MagicMirrorTests/PoseGeometryTests.swift`: frame crop, visibility,
  nonfinite data and connected-limb regression tests.

The MediaPipe result now uses capture geometry saved for its *own* source
timestamp, rather than taking dimensions from the newest camera frame.
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

## Gaps before actual anatomical AR

The source now implements live **2D skeletal visualization**, not
semi-transparent anatomically accurate 3D bones. Next:
1. Pass real Xcode build and physical rear-camera capture.
2. Validate portrait orientation and keypoint-to-preview alignment on
   several iPhone screen aspect ratios, including body motion/occlusion.
3. Add a mobile 3D rig, review Z-Anatomy source licenses, convert the
   intact atlas offline to an optimized mobile asset.
4. Implement dynamic camera/body registration, depth/occlusion and
   independent measured overlay/latency benchmarks.

Source parsing or successful simulator compilation **does not** prove
physical camera behavior or true body-to-anatomy alignment.

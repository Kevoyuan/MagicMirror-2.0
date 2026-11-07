# iOS Mobile-4: explicit source-frame camera intrinsics and reprojection

**Status: compiled-source milestone, not calibrated live anatomy.**

This module defines the missing distinction between MediaPipe's
hip-relative *estimated* `worldLandmarks`, native portrait video
pixel coordinates, and actual body-to-camera extrinsics.

## Input contract

- The app has exactly ONE rear-facing AVFoundation camera session.
- Where supported, enable
  `AVCaptureConnection.isCameraIntrinsicMatrixDeliveryEnabled` before
  running capture; from every video `CMSampleBuffer`, read Apple's
  `kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix`.
- `CameraIntrinsicMatrixReader` accepts valid, packed or SIMD-aligned
  3×3 float matrices and refuses bad dimensions/invalid values.
  **No fallback intrinsics are guessed** on unsupported camera formats.
- The original `PoseFrameAssociationGate` now binds (timestamp, image
  size, optional camera intrinsics) as one immutable source-frame record.
  MediaPipe's asynchronous callback receives the metadata of THAT frame,
  never the most recent capture frame.
- `PoseSnapshot.cameraIntrinsics` is optional. It does not grant
  intrinsic calibration if no attachment was supplied. The iPhone's
  capture orientation, crop, and intrinsic-coordinate conventions still
  require device validation.

## Pinhole reprojection and its limits

`BodyCameraProjection` requires:
1. Real focal length and principal point for the same portrait image,
   and the original image dimensions (pixels).
2. An **independently estimated and checked** body-world → camera
   rigid 3D transform (unit quaternion + translation, meters).
3. World landmark coordinates in that same body-world frame.

It calculates `u=fx*X/Z+cx`, `v=fy*Y/Z+cy`, where camera +Y points
down and positive Z points forward. It refuses negative/near-zero Z,
invalid rotation and inconsistent frame dimensions. It never claims
that MediaPipe's world depth is camera-space depth by itself.

`BodyReprojectionGate` measures projected **surface keypoint**
difference versus MediaPipe's observed normalized 2D landmarks.
Its 90th percentile error is expressed as a fraction of the
**source image width**, with a proposed 3% gate for specified test sets.
That is NOT a measurement of real skeleton accuracy or internal bones.

The native reader and projection math are wired to tracking and can be
tested with entirely synthetic camera poses. A correct current
extrinsic-estimation algorithm and fully calibrated anatomical
world↔camera rig are still unimplemented. Therefore the current Metal
proxy remains explicitly illustrative and uses 2D pixel anchors and
bounded uncalibrated depth.

## Automatic body-to-camera pose solver (experimental source)

`BodyCameraPoseEstimator.swift` now implements on-device **experimental
6-DOF optimization** over confident MediaPipe world/image landmarks
(shoulders, elbows, wrists, hips, knees and feet). It requires the native
same-frame intrinsic matrix, nondegenerate 3D joint spread, at least 12
visible correspondences and a meaningful projected shoulder width.
An approximately frontal pose seeds a damped robust least-squares fit;
accepted camera rotations/translations must pass selected-joint P90
reprojection checks. Implausible, missing or inconsistent inputs
are rejected rather than displayed as confidently calibrated anatomy.

An actual macOS `swiftc`-compiled synthetic smoke binary now executes
frontal, small-yaw and intentionally corrupted camera-pose fixtures in
GitHub Actions **before** the full Xcode build. This is a stronger math
check than compiled-but-unexecuted XCTest alone, but remains a
**synthetic test**. Reprojection goodness on MediaPipe's own estimates
does not independently validate the real camera/body geometry. The
estimator is not yet wired to approved USDZ rigging and the current
Metal proxy remains based on 2D endpoints and bounded illustrative z.

## Acceptance pending (user deferred physical verification)

- Check camera intrinsic attachment presence, orientation and crop on
  named iPhone models, especially portrait BGRA rotation and lens changes.
- Estimate current body-to-camera extrinsics robustly from real
  correspondences and reject wrong facing/mirror/identity.
- Project real approved USDZ joints with reviewed rest transforms and
  measured confidence; add occlusion/recovery.
- Run XCTest on simulator and physical camera motion, alignment,
  temperature/FPS tests before claiming an AR skeleton MVP.

Official Apple API sources:
- https://developer.apple.com/documentation/avfoundation/avcaptureconnection/iscameraintrinsicmatrixdeliverysupported
- https://developer.apple.com/documentation/avfoundation/avcaptureconnection/iscameraintrinsicmatrixdeliveryenabled
- https://developer.apple.com/documentation/coremedia/kcmsamplebufferattachmentkey_cameraintrinsicmatrix

No Unity, Python service, cloud image upload or camera re-capture is used.

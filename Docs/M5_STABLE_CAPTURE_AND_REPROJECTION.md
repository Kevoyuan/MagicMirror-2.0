# M5 — Stable reference capture and source-frame reprojection diagnostics

**Status:** Compiled, unit-tested source mathematical foundations. They do NOT
measure true human skeletal anatomy, camera-to-display latency or a working
Unity AR alignment. The actual Unity Editor, camera and complete Z-Anatomy
FBX have **not** been run with this code.

## Why this engineering increment matters

The project previously had a mathematical body-world → atlas registration
but no stable reference-pose capture, explicit pinhole camera projection
parameters, or way to quantify predicted overlay-to-landmark agreement.
A single bad frame, an incorrect aspect ratio, or an accidentally reused
IK prediction would produce a convincing-looking but wrong anatomical overlay.

The new components separate three operations:

1. **Reference capture:** `ReferencePoseCaptureWindow` accepts a bounded
   series of PoseFrame-v1 records (12 frames by default), and uses
   component-wise medians of shoulder/hip world estimates. It checks the
   *maximum* observed joint deviation from those medians: a median does not
   conceal a large outlier.
2. **Projection:** `BodyWorldPinholeCamera` requires explicitly reviewed
   camera origin, right/up/forward axes and normalized camera intrinsics
   in the **same MediaPipe-estimated body-world frame**. It does not infer
   them from a Unity camera or pretend that MediaPipe world landmarks
   provide camera extrinsics. It rejects mirrored source flags,
   left-handed/reflected bases, non-orthonormal axes, non-finite inputs
   and points behind the camera.
3. **Diagnostics:** `AtlasReprojectionDiagnostics` transforms predicted
   *moving* atlas-root-local joint positions back through
   `BodySimilarityCalibration` into body-world, projects them into
   the source image, and compares with **same-frame** 2D landmark
   estimates. This is a consistency diagnostic, not ground truth.

## Capture state machine

`new ReferencePoseCaptureWindow(requiredFrames: 12,
minimumConfidence: 0.6f, maximumDriftInShoulderWidths: 0.06f,
maximumFrameGapMs: 250)`

The API exposes `TryAdd(frame)`, `TryFreeze(..., out calibration,
out quality)`, `RequiresReset`, `IsFrozen` and `Reset()`.
It rejects low-confidence/missing world landmarks, demo/mirrored input,
duplicate or backwards frame IDs/timestamps, changed image dimensions,
long frame gaps and excessive pose movement.

If a bad sample is encountered, the window enters a **poisoned** state:
the caller must explicitly `Reset()` and begin a new reference capture.
It never automatically carries a partially captured pose across a camera
disconnect. Successfully frozen calibration remains immutable until reset.

The resulting `PoseCaptureQuality` reports sample count, start/end frame
identifiers and the largest relative joint deviation. Quality reports are
**not** hardware/clinical validation of the subject's bones.

## Camera and mirror contract

In the *unmirrored source image*, normalized pinhole coordinates are:

`sourceX = cx + fx * dot(world - cameraOrigin, right) / depth`

`sourceY = cy - fy * dot(world - cameraOrigin, up) / depth`

`depth = dot(world - cameraOrigin, forward)`

Normalized intrinsics must be derived from independent camera calibration:

- `fx = fxPixels / sourceWidth`
- `fy = fyPixels / sourceHeight`
- `cx = cxPixels / sourceWidth`
- `cy = cyPixels / sourceHeight`

Neither browser resolution nor anatomical shoulder width alone determines
camera intrinsics or extrinsics. The 3D body-world reference is not the
same thing as the camera's Unity world transform.

**Display mirroring is strictly a later 2D operation**:
`displayX = 1 - sourceX` when the display uses a mirror view. Do not
reflect estimated 3D body coordinates or swap left/right anatomical
joint IDs to imitate a mirror.

## Same-frame P90 evaluation

Each `AtlasReprojectionAnchor` carries:

- An actual **reviewed** anatomical correspondence (MediaPipe index,
  predicted atlas-root-local point).
- The prediction's `sourceFrameId` and `sourceTimestampMs`, which
  must exactly equal the PoseFrame/JPEG source frame being scored.
- A fresh moving-joint position computed for **that frame**, not a
  static source-rest pose mistakenly reused after movement.

The API fails the entire result if anchors are duplicated/unreviewed,
stale, behind the camera, non-finite, or too few visible. Low-confidence
landmarks are counted as excluded, never as successful matches.

For each eligible landmark, Euclidean **pixel** residual normalized by
image **width** is:

`sqrt(((projectedX - observedX) * width)^2 + ((projectedY - observedY) * height)^2) / width`

This corrects the vertical aspect ratio for non-square source images.
`P90ErrorAsImageWidth` uses deterministic nearest-rank percentile.
For example, a 0.1 normalized vertical difference on 1280×720 is
`72 / 1280 = 0.05625`, **not** `0.1`.

A numeric target such as `p90 <= 0.03` is *only a hypothetical
threshold on scored source-landmark consistency*, not achievement of
the roadmap's **independently verified real-person** p90 goal.
`GroundTruthValidated` is always `false`.

## CI reproduction (no installed Unity)

~~~bash
dotnet build Tools/ci/csharp_kinematics/KinematicsChecks.csproj -c Release --warnaserror
dotnet run -c Release --no-build \
  --project Tools/ci/csharp_kinematics/KinematicsChecks.csproj
~~~

The .NET project compiles the **exact production Unity C# source files**
alongside the existing M4/M5 IK, pose protocol and registration.
New checks exercise pinhole math, right-handed camera bases, valid/invalid
depth and source mirroring, source pixel aspect ratios, stale frame IDs,
missing confidences, P90 thresholds and camera resolution mismatches.
The capture checks exercise bounded noise, one tolerable outlier, excessive
drift, time gaps, frame rollback, invalid confidence and explicit reset.

The numeric sample outputs are generated with constructed synthetic
reference coordinates, **not** measured physical-camera evaluation.

## Next true M5 acceptance gates

1. Obtain **actual** camera intrinsic calibration and valid body-world-to-
   camera extrinsics; verify rotation handedness and source mirror semantics.
2. Import the one complete verified `SkeletalSystem100.fbx`, review anchors
   and licensing, and define an actual bone motion rig. Preserve source FBX.
3. Drive reviewed anatomical joints by the M4 IK outputs **on the same frame**,
   then supply the moving atlas joint predictions to this diagnostic API.
4. Run Unity 6.3 with a real camera; measure reprojected landmark residuals
   on an independent, consented frontal-view evaluation set. Track occlusion,
   pose confidence, left/right identity, torso turns and dropout recovery.
5. Only count actual, reproducible real-camera metrics toward the roadmap
   target (joint reprojection p90 <= 3% of source image width).

Source code passing CI is **necessary but insufficient** for M5 completion.

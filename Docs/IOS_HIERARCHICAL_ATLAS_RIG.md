# iOS anatomical atlas: coherent parent-child rig pose kernel

**Status: Swift implementation and synthetic XCTest source, not a verified
Z-Anatomy rig, physical phone result or camera-aligned atlas.**

The iOS code now contains `CoherentAtlasRigPlanner`. Its purpose is to
produce a mathematically coherent **atlas-space pose** from reviewed
anatomical hierarchy, a frozen stable reference body pose and an explicitly
constructed body-to-atlas similarity registration. It is independent
of the legacy Unity/Python runtime.

## Why the previous method was not enough

The optional `VerifiedAnatomyAtlas.makeProjectedMesh` can take each
reviewed part's rest axis and independently align that part to a detected
body segment in screen coordinates. It does **not** preserve attached
joint pivots when image landmarks differ in position or limb lengths.

The hierarchy planner addresses that part of the problem before an
approved bone mesh is ever shown:

1. Require an `AnatomyAtlasManifest` that passes human review flags,
   stable unique ids, no parent cycles, vetted rest pivots and 33 landmark
   mapping. Merely setting a test Boolean is NOT a legal/anatomy review.
2. Require one **frozen** reference `PoseSnapshot` with 33 world
   estimates, the current 33-landmark frame with matching dimensions and
   later/equal timestamp, plus an explicit
   `BodySimilarityRegistration` for a reviewed 3D body/atlas alignment.
3. For every bone, compare original atlas rest vector to the transformed
   *reference* body vector. Reject if reference direction/length differs
   beyond the conservative safety tolerance.
4. For each current frame, calculate a proper shortest-arc relative
   quaternion from the atlas rest segment to the observed current
   segment. The anatomical rest length remains fixed; no per-limb
   stretching to screen landmarks is allowed.
5. For any child bone, determine the new child pivot by applying the
   **parent's posed rigid transform** to the original reviewed child
   pivot. This is ordinary forward kinematics: it avoids independent
   child root teleportation. Check the propagated child anchor against
   the estimated observed anchor; reject if they diverge too far.
6. Require a complete coherent result for every reviewed bone in the
   manifest. A missing elbow, invalid angle, bad parent or disconnected
   child returns **nil for the whole rig**, not a partly plausible atlas.
7. The output is a list of `AtlasRigBonePose` commands in
   **atlas-root coordinates**, each with a rest/posed pivot, a proper
   rotation, invariant reference length and confidence.

All tolerances are engineering starting assumptions, not medical
standards or measured device tracking performance. They are explicit
and adjustable in the planner; relaxing them must have evidence.

## Important coordinate distinction

MediaPipe `worldPoints` are *estimated and hip relative*, not measured
camera-space bone positions. `BodySimilarityRegistration` is an
independent reference-body ↔ atlas coordinate mapping. Neither is a
physically measured RGB camera extrinsic transform.

The planner does **NOT**:
- tell whether a viewer is facing toward or away from the camera;
- solve axial twist of long bones from only two endpoints;
- establish full 3D camera pose, occlusion or mobile lens parameters;
- deform a correctly skinned USDZ/FBX atlas automatically;
- identify a human's real internal bones;
- provide an anatomical license or model hierarchy review;
- prove it works in a real moving-person session.

The separate reviewed camera projection layer and proper original
model skin/attachment metadata are still needed. Do not wire the
planner into the default Metal camera overlay without verifying the
actual atlas identity, camera calibration and reprojection acceptance.

## Automated evidence and test plan

`Mobile/iOS/MagicMirrorTests/CoherentAtlasRigPoseTests.swift` covers
constructed reference anchors, parent-child attachment, unchanged
bone lengths, stable reference, invalid hierarchy, low confidence,
implausible length change, image size changes and invalid limits.

The GitHub macOS workflow **compiles** these XCTest sources and the
production Swift planner under `xcodebuild build-for-testing` on an
arm64 iOS Simulator target. This is **not** execution of XCTest, an
imported full FBX, an available licensable atlas or a phone benchmark.

Next implementation seam after human-reviewed source assets:
- A USDZ or verified MMATLAS1 per-node mapping that exactly corresponds
  to these reviewed `BoneBinding.nodePath` ids.
- A verified local-camera to body-world transformation with source-frame
  reprojection gates.
- A rig renderer that applies atlas-space poses, proper joint transforms
  and skinning **without separating connected anatomy meshes**.

The final product remains a smartphone-only educational reference AR
illustration, never an actual X-ray scan.

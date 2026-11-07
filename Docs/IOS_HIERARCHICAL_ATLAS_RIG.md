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

A pure, fail-closed camera-space seam is now available in
`CoherentAtlasCameraProjection.swift`. Before any rest vertex can be
projected, it requires:

- the exact **same source timestamp and image dimensions** as the
  hierarchical pose;
- explicitly reviewed source-camera extrinsics, never a guessed FOV;
- an exact matching physical-lens intrinsic record;
- the existing `BodyReprojectionGate` passing a same-frame landmark
  P90 threshold no weaker than 3% of source image width;
- a named reviewed bone ID in the coherent pose and a finite rest
  vertex in the same atlas-root coordinate system.

The projector composes atlas rest → articulated atlas point → estimated
body world → calibrated RGB camera → source pixels → exact aspect-fill
viewport. This is tested with **constructed** camera parameters and
synthesized landmarks. It is **not** enabled in the default GPU renderer,
because the reviewed mesh binding, dynamically validated real camera
extrinsics, legal source rights and actual rig skin/vertex assignments
are not yet available.

Do not wire these helpers into the default Metal overlay without
verifying the actual atlas identity, camera calibration and independent
source-frame reprojection acceptance.

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

## Mesh-to-rig binding gate (source implementation, 2026-11-07)

`CoherentAtlasMeshProjection.swift` now validates the entire triangle
atlas against the independently reviewed hierarchical bone manifest and
the same-frame `CoherentAtlasCameraProjection`. It requires exact source
revision, unique node paths, one-to-one complete bone coverage, matching
MediaPipe joint identities, matching rest anchors, contiguous triangle
ranges, and successful projection of every selected vertex.

It emits *projected triangle commands*, not a GPU draw call or a skinned
USDZ render. A bad or missing binding, inconsistent range, unreviewed
metadata or invalid projection rejects the entire result (nil), rather
than publishing a partially detached skeleton. All current XCTest fixtures
are synthetic; their review flags are test fixtures, not human sign-off.

**Not wired to the default Metal renderer.** There is still no approved
source asset, independently reviewed physical camera extrinsics, verified
mesh-to-bone geometry or actual phone validation. Do not treat the new
adapter as a shortcut around these blockers.

## Metal presentation integration boundary

A `CalibratedAtlasDrawBatch` converts already-reviewed coherent projected
triangles into the existing 48-byte Metal bone vertex ABI, using explicit
illustrative flat normals and bounded clip-space depth. The renderer checks
frame identity, image/viewport dimensions, focus and opacity before drawing.
It no longer automatically selects a weak-perspective atlas merely because
an approved-looking local file was found. There is **no live producer** for
the calibrated batch without independently confirmed camera extrinsics,
an approved coherent 3D mesh and verified joint-to-vertex bindings.

Simulator compilation and test fixtures do not replace legal/anatomical
review or real-phone visual/reprojection acceptance.

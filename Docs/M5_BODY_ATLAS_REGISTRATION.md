# M5 — Body-world ↔ reference-anatomy coordinate calibration

**Status:** a reference-pose mathematical/metadata foundation. This is NOT
yet a complete camera-space AR registration, a moving Z-Anatomy skeletal rig,
or proof of anatomical accuracy.

## Why this comes after M4

M4 constrained two-link IK preserves reference link lengths, but
MediaPipe's `pose_world_landmarks` are *estimated hip-relative 3D body
landmarks*, not the original FBX hierarchy's root-local coordinates.
The Z-Anatomy model has its own axes, units, root transformation and
anatomical joint centers. Feeding raw estimated world points into imported
FBX bone Transforms would be wrong.

## What the new C# source actually implements

- `Unity/Assets/Scripts/Motion/BodySimilarityCalibration.cs`:
  engine-independent, **right-handed 3D similarity registration** from
  one explicitly selected pose reference frame to the original FBX
  **root-local** reference frame.
- `BodyWorldCalibrationBridge.cs`: reads the actual protocol-v1
  `PoseFrame` and quality-gates left/right shoulders (IDs 11/12) and
  both hips (IDs 23/24); midpoint of hips supplies the body plane.
- `FullBodyAtlasProfile`: a separately reviewed `atlasMidHipLocal`
  and `midHipAnchorReviewed` gate, in addition to original shoulders.
- `FullBodyAtlasCalibrationWindow`: author a candidate mid-hip point
  via a Scene View handle **without modifying the original FBX**.
  Moving the mid-hip handle clears its reviewed flag.
- `M5BodyCalibrationSelfCheck`: future Unity Editor menu validation
  `MagicMirror > Validation > 3D Body-to-Atlas Calibration Check`;
  also invoked by the batch suite. Actual Unity execution pending.

### Mathematical registration

Given subject-left/right reference shoulder coordinates `L/R` and a
mid-hip `H`, build a right-handed orthonormal basis in both the
estimated-pose frame and separately reviewed atlas-root-local frame:

`X = normalize(R-L)`

`Y = normalize((H-(L+R)/2) - project_on_X(H-(L+R)/2))`

`Z = cross(X,Y)`

The uniform scale is `atlas shoulder width / estimated shoulder width`.
Fit shoulder midpoints by translation, and rotate between the right-handed
bases. The mid-hip positional residual (expressed in atlas shoulder widths)
can be thresholded to reject disproportionate, noisy or otherwise
inconsistent reference observations.

**Do not assume a single RGB camera has revealed the user's bones.**
These are visual-fit transforms applied to a *standard reference* atlas,
not individual internal anatomy measurements.

## Safety and observability gates

The one-shot reference-pose bridge refuses calibration if:
- The original atlas shoulder and mid-hip anchors were **not reviewed**.
- A frame is synthetic (`demo=true`), invalid, or has a mirrored source
  flag. Mirroring in the **Unity 2D display** is separate and expected.
- Pose/world coordinates are missing, non-finite or low confidence.
- Shoulder span or torso plane is degenerate.
- Scale is outside the explicit allowed calibration bounds.
- Mid-hip residual exceeds the configured reference-size tolerance.

**Limits:** Three nearly coplanar anchors cannot independently prove
subject-facing direction, camera extrinsics, or distinguish all
left/right/chirality errors. A 3D reflection is *never applied silently*
by this code. Actual source-world camera axis semantics, facing-direction
selection and reprojection remain an M5 hardware acceptance gate.

A bounded, median-based multi-frame reference capture implementation,
`ReferencePoseCaptureWindow`, and a C# camera-reprojection diagnostic
are now available and unit-tested in `Docs/M5_STABLE_CAPTURE_AND_REPROJECTION.md`.
Actual camera intrinsics/extrinsics and Unity overlay runtime are still
unmeasured.

Calibration must be captured in a controlled, explicitly confirmed
reference pose and **frozen across motion** until re-calibration. Running
a brand-new similarity fit independently on each animation frame would
absorb part of the person's movement and create visual instability.
The bridge does not save profiles, change any mesh, run automatically
per frame, or directly drive any FBX Transform.

## Offline reproducible tests (Unity installation not needed)

~~~bash
dotnet build Tools/ci/csharp_kinematics/KinematicsChecks.csproj -c Release --warnaserror
dotnet run -c Release --no-build --project Tools/ci/csharp_kinematics/KinematicsChecks.csproj
~~~

This executable compiles **the actual Unity project C# files**:
`TwoBoneKinematics.cs`, `BodySimilarityCalibration.cs`,
`TwoBoneWorldPoseBridge.cs`, `BodyWorldCalibrationBridge.cs` and
`PoseStreamProtocol.cs`. A tiny empty `UnityEngine` namespace exists
only to satisfy an unused `using UnityEngine` in the protocol source;
it does **not** emulate Unity components, editor, scene objects or rendering.

The test checks forward/inverse transforms, 3D right-handed frame
rotation, exact shoulder fit, reference-length preservation,
non-collinear constraints, bounds, invalid/NaN input, simulated/low
confidence frame rejection and M4 IK compatibility. CI records the
executed assertion totals.

## Future Unity manual workflow

1. Download and import the **one intact original** `SkeletalSystem100.fbx`.
2. Export and audit the hierarchy inventory (`Docs/M3_WHOLE_ATLAS_AUDIT.md`).
3. In `MagicMirror > Phase 4 > Calibrate Full Atlas Anchors`, place
   anatomically verified left/right shoulders and the NEW mid-hip anchor,
   and manually confirm their reviewed/provenance/asset license fields.
4. Check source atlas units and axes, and source-right/source-left identity.
5. Integrate the now-authored bounded stable reference-capture window under
   explicit user control, freeze once, and obtain **physical** camera
   intrinsics/extrinsics and facing-direction conventions. Run real camera
   reprojection tests; the C# synthetic diagnostics are not actual results.
6. Apply the transform only in the reviewed full-atlas rig, keeping all
   original FBX geometry immutable and unmapped anatomy in the rest pose.
7. Validate real shoulder/hip reprojection, connected limb motion,
   tracking loss/recovery, visual latency and rendering on both macOS
   and Windows before accepting M5.

Until these physical checks are completed, M5 is a **verified math
foundation**, not a finished working AR body registration.

# M4 — Constrained 3D two-bone inverse kinematics (engine-independent foundation)

**Implementation status:** actual C# geometry kernel is compiled and executed
in .NET 8 Linux CI, with 53 deterministic assertions in the initial test suite.
The Unity-specific PoseFrame bridge and Editor self-check have syntax parsing
but **have NOT yet been compiled/executed in Unity**. Original Z-Anatomy FBX,
actual joint anchors, camera registration and visible anatomical animation
have **not** been verified.

## Why this is not just an animated Avatar

MediaPipe's 33 image/world landmarks are **surface/body estimates**, not
measurements of internal bone centers. The final mirror requires anatomical
bones to stay connected while following estimated human motion, instead of
moving every FBX child directly onto uncertain landmark positions.

This M4 foundation implements a safe, deliberately limited two-link inverse
kinematics solver for shoulder→elbow→wrist and hip→knee→ankle chains.

## Pure C# math, tested without Unity

`Unity/Assets/Scripts/Motion/TwoBoneKinematics.cs` has no
`UnityEngine` dependency. The exact same C# source is compiled into
`Tools/ci/csharp_kinematics/KinematicsChecks.csproj` so CI can actually
execute its geometry, not merely parse Unity scripts.

~~~bash
dotnet run -c Release --project Tools/ci/csharp_kinematics/KinematicsChecks.csproj
~~~

This should print `MAGICMIRROR_M4_TWO_BONE_CSHARP_PASS`. Tests cover:

- Exact preservation of both reference link lengths under joint movement.
- Straight and bent limb cases using geometric law-of-cosines solutions.
- 3D bending planes (Y/Z), opposite poles and left/right consistency.
- Human-configured flexion bounds, clamping unreachable and overly
  folded wrist/ankle target distances to the reachable hinge arc.
- Rejecting zero-length segments, undefined distal directions, collinear
  bend-plane hints, invalid angles and non-finite coordinates.

Given proximal point `S`, desired distal point `W`, segment lengths
`a` and `b`, and flexion `f` (0° straight), the allowable
source-space end-to-end distance is:

`d(f) = sqrt(a² + b² + 2ab cos(f))`

We clamp requested distance to the review-approved flexion interval,
then obtain the intermediate joint position using the bend pole. This
preserves *reference-model* segment lengths. It does not produce true
observed human bone lengths.

### Critical ambiguity: bend/twist is not measurable from one camera

A distal target and two lengths leave an entire circle of possible elbow
positions. We use an explicit third point, the estimated elbow/knee, as
a bend-plane **hint**. If it is collinear with the limb direction, the solver
returns `false` rather than choosing a random sign. This avoids artificial
flips; a production temporal fallback must be reviewed separately.

The solver also cannot infer axial pronation, shoulder roll, torso heading
or realistic cartilage/soft-tissue motion.

## Strict bridge to the MediaPipe PoseFrame

`TwoBoneWorldPoseBridge.TrySolveEstimatedWorld` maps the standard
MediaPipe indices (11,13,15), (12,14,16), (23,25,27), (24,26,28) into
four two-link chain inputs. It requires:

1. A valid PoseFrame with 33 `worldLandmarks` and matching 33 image
   landmarks used only to gate `visibility` and `presence`.
2. Finite world 3D coordinates and an observable non-collinear bend plane.
3. **Reviewed reference lengths expressed in the SAME unit scale and
   coordinate frame as the estimated world points.** Do NOT pass raw FBX
   units directly. Source atlas scaling and camera coordinate registration
   are not implemented in this bridge.

Output remains in estimated MediaPipe world coordinates. It is **not yet
safe to set raw Unity Transform positions** from these values. Mirror
semantics and axis conversion belong to the M5 registration layer.
Unreviewed anatomy must not become animated just because this call succeeds.

## Editor-level check (to run later, not yet passed)

The Unity Editor menu **MagicMirror > Validation > Constrained Two-Bone IK
Check** runs synthetic valid/invalid world landmark tests. The existing
**M2BatchValidation** now calls it as its **sixth** future Editor suite.

This test will confirm Unity-side data types and bridge logic when Unity
6.3 is actually available; the current CI does not validate any Unity API.

## Next genuine M4 acceptance gates

- Import and inspect the one complete pinned `SkeletalSystem100.fbx`.
- Review the anatomical identities, per-group rest anchors, correct joint
  centers, source model axis/orientation, licenses and world-unit scale.
- Define a calibrated, reversible coordinate transform between estimated
  MediaPipe body-relative world coordinates, camera space, and FBX root.
- Wire IK outputs into the non-destructive `FullBodyAtlasRetargeter`
  **only behind a verified calibration gate**, preserving original FBX
  hierarchy and immutable rest transforms.
- Test linked elbow/knee motion, occlusion/reacquisition, out-of-plane
  movement, limb and person identity switching and left/right mirroring.
- Compile and visually validate the actual Unity 6.3 project on Windows
  and macOS with representative real camera footage; measure latency.
- Never interpret model motion as actual individual internal anatomy.

M4 is a mathematical foundation **in progress**, not a complete full-body
3D retargeting system or a release milestone.

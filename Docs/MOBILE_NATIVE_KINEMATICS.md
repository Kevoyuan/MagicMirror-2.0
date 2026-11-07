# Native iOS kinematics / reference registration — source implementation

This mobile-only source ports the engine-neutral C# M4/M5 mathematical contracts
to native Swift. It is **not** an assertion that model-estimated world poses,
internal bone geometry, image-to-camera extrinsics or a full atlas animation are
already solved.

- `Motion/TwoBoneIK.swift`: valid two-link arm/knee bend lengths, bounds,
  pole-side safety, unreachable target clamping and explicit failure.
- `Motion/BodySimilarityRegistration.swift`: a positive-scale,
  right-handed transform between source and atlas shoulder+midhip anchors,
  bidirectional mapping and a residual threshold.
- `Mobile/iOS/MagicMirrorTests/NativeKinematicsTests.swift`: deterministic
  pure math checks; these do NOT exercise real people or mesh bindings.

**Coordinate contract:** Source points are MediaPipe's hip-relative
model-estimated body-world coordinates, not camera coordinates. Calibration
is valid only if it uses one stable pose reference and a human-reviewed
atlas rest-pose anchor mapping. Mirroring, camera intrinsics and facing must
be resolved separately.

These kernels are intentionally independent of SceneKit/RealityKit/Metal:
the future atlas binding layer can use them without coupling to one GPU.
The current phone renderer uses a **3D volumetric procedural proxy**, not
licensed Z-Anatomy meshes. A full atlas, facing checks and real device
measurements remain open gates.

The user asked to defer *hardware validation* while implementation
continues. Do not mark hardware gates complete based on these tests.

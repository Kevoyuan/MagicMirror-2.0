# Mobile camera-to-body weak perspective — source-only iOS feature

A monocular camera cannot directly measure bone geometry, camera-space
human depth or exact person-specific anatomy. MagicMirror's native
`WeakPerspectiveCameraFit` estimates a **bounded, orthogonal weak-perspective
3D model-to-source-camera-image projection** from the same MediaPipe
landmark timestamp.

- Uses approximately 15 anatomically indexed visible surface joints
  shared by the 33-point image and world streams.
- Fits a common positive pixel-per-world scale, 2D translation and two
  orthogonal 3D screen-axis directions, derives the third by cross product.
- Iteratively excludes gross 2D/3D correspondence outliers, rejects
  degenerate geometry and quality-gates P90 image reprojection.
- The camera preview still uses the source capture's aspectFill crop.
- Native iOS processing only. No additional camera, server, Python runtime,
  special wearable or LiDAR required.
- A reviewed atlas package can project its physically shaped source mesh
  *after* rigid parts are transformed into the observed body-relative
  3D pose-world frame, instead of stretching triangles directly in the
  2D image plane.

**Not a camera intrinsics/extrinsics calibration.** MediaPipe world points
are model estimates, the camera's true focal length/distortion remains
unknown, and three-axes/monocular front-back ambiguity remains unresolved.
P90 landmark reprojection measures visible tracked surface points,
**not** how close the drawing is to the person's actual internal bones.

Default source-quality gates are implementation heuristics, not real-world
validated thresholds. Physical device turning/occlusion/facing tests and
Z-Anatomy reference-mesh license/anchor audit are still release blockers.

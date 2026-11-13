# W3b — model-estimated world landmarks and local in-plane consistency

**Scope:** Web source only. **Status:** implementation proposed for PR review, not physical camera acceptance.

MediaPipe Pose Landmarker offers two different observations for the same
person/frame: normalized image landmarks (33) and hip-centered world landmarks
(33, coordinates described by the SDK in model-estimated meters). See
https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker
and https://developers.google.com/edge/api/mediapipe/js/tasks-vision.poselandmarkerresult.

W3b passes the latter through the same Worker/main-thread inference result,
same camera-session identity, same latest-only gate, and same local-only
memory boundaries. It adds a diagnostic inside the existing collapsed camera
diagnostics disclosure. No pose data, camera video or geometry is uploaded,
downloaded, logged or retained by the diagnostic.

`Web/src/world-pose.ts` compares corresponding landmarks from the **same
accepted frame**. It fits a weighted 2D similarity transform from predicted
world X/Y to actual video/crop/mirror display pixels (selected 12
shoulder/arm/hip/leg indices). Requires five observed pairs and nondegenerate
world variance. Reports match count and an in-plane residual; a residual
below 6% of the shorter viewport axis is a **candidate consistency check**,
not an approved 3D registration. A large residual is an explicit
inconsistency; missing or low-confidence landmarks produce no 3D fit.

The fit does **not** use model-estimated Z to claim camera depth. It does
**not** solve camera intrinsics, extrinsics, out-of-plane rotation,
person-specific bone lengths, scale truth, physical anatomical alignment or
occlusion. Small residuals can occur even for fundamentally wrong 3D
hypotheses. The transform must not be fed into a clinical, real-atlas or
camera-depth renderer. No new anatomical layer is enabled by W3b.

Next separate stages: collect voluntary device/browser acceptance evidence,
evaluate known synthetic camera intrinsics/extrinsics and 3D reprojection
residuals, obtain a reviewed legal anatomical rest rig and retarget chain,
then verify physical camera-to-model registration on real devices. Public
release remains blocked by independent model-license, dependency and SDK
privacy review.

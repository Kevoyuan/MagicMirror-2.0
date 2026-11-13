# W3c — explicit camera-geometry hypothesis and reprojection evidence

**Scope:** Web-only, synthetic-first geometry test harness. **Release:** still
blocked by independent rights/privacy/device QA. **Not** real 3D AR.

## Why this is the next slice

W3b carries the MediaPipe Pose Landmarker 33 model-estimated hip-relative
world points alongside their 2D image observations and tests only a
weak-perspective *in-plane* similarity. W3c does not turn this into a
calibration. Instead, it introduces a stricter, independently testable
**perspective reprojection evaluator** for a camera model supplied explicitly.
This is groundwork for a later, evidence-backed camera registration study.

## Explicit geometry contract

- Image coordinates: original source video, width/height in pixels; no
  automatically inferred focal length, lens distortion or device metadata.
- Hypothesized camera intrinsics: `fx, fy, cx, cy` in source-image pixels,
  exactly matching the source resolution. No lens distortion is modeled.
- World-to-camera rigid transform: ROW-MAJOR right-handed 3×3 orthonormal
  rotation with determinant +1 and translation in the same
  **model-estimated coordinate units** as the input. It is neither obtained
  from MediaPipe nor independently verified.
- Camera coordinates are explicitly **+X image right, +Y image down,
  +Z forward**. For `(Xc,Yc,Zc)=R*Pw+t`, accepted depth must exceed 0.05
  model units. Pinhole projection is `u=fx*Xc/Zc+cx` and
  `v=fy*Yc/Zc+cy`.
- Only AFTER pinhole projection, convert `(u,v)` and observed image
  coordinates to viewport space using the same existing
  `object-fit:cover` transform and optional horizontal mirror. Mirroring
  is never an anatomical left/right index swap.
- `frame.session/frameId` must exactly match the geometric hypothesis
  session/frameId. An old or future session/frame cannot reuse calibration
  evidence.
- Model-estimated world Z participates in *hypothetical* perspective
  projection, not as a direct measurement of actual camera depth.

## Acceptance and refusal

`Web/src/camera-registration.ts` is pure and has NO DOM, camera, Worker,
Three.js or network effects. It checks at least six high-confidence,
matched, nondegenerate pairs from shoulders/arms/hips/legs. It rejects
malformed intrinsics, left-handed/reflected and nonorthonormal rotation,
nonfinite world points, absent/mismatched session data, and anything
behind/too near the hypothesized camera plane. For comparable valid pairs
it computes weighted RMSE (display px), p95 residual and inlier fraction.

A *geometric-candidate* must meet the following **synthetic engineering**
thresholds: RMSE <= 3% of shorter viewport axis, p95 <= 6%, and at least 80%
of matched points with error <= 4%. These are not clinical, physics or
camera-calibration validation limits. A low error is necessary but
**never sufficient** to approve a real camera transform, because world
landmarks and body dimensions remain model-estimated and the supplied
camera hypothesis could be wrong or overfit. All diagnostics return:

- `cameraCalibrationApproved: false`
- `anatomyOverlayApproved: false`
- `note: GEOMETRIC_CHECK_ONLY_NOT_CAMERA_CALIBRATION`

The only accepted provenance values are `synthetic-fixture` and
`external-unverified`. There is deliberately no self-declared "certified"
or runtime production calibration mode.

## UI self-check

The existing camera diagnostics is still collapsed by default; this change
places multiple diagnostic rows in ONE readable panel (W3b text previously
shared overlapping absolute-position rules). A 44px keyboard-accessible
button runs **one fixed, generated, camera-free fixture**. It displays
12-pair perspective residuals and clearly states SYNTHETIC ONLY /
未标定真实设备 in EN/ZH. It neither opens a camera nor changes the overlay,
feeds landmarks to the inference engine or enables any real anatomy layer.

## Evidence / next step

Deterministic Vitest tests exercise raw pinhole coordinates, independent
synthetic truth, mirror and cover crop, outliers, partial data, degenerate
point sets, invalid intrinsics, negative/near depth, rigid reflection,
frame/session mismatch and permanent non-approval. A camera-free Playwright
test exercises the actual user-visible button, bilingual copy, and existing
single stage canvas on Chromium and WebKit engine emulation.

**Still open:** actual-source iPhone/desktop camera measurements, lens
distortion, known physical calibration target observations, verified
intrinsics/extrinsics, source-specific MediaPipe/world-coordinate axes,
3D point correspondences from a lawful anatomical rest rig, real-device
screen-to-camera latency, Mesh/material legal evidence and privacy sign-off.
A later separate W3d should implement an audited calibration-evidence
workflow with physical target data, per-device calibration provenance,
reprojection hold-out frames and user consent — NOT auto-PnP fit on
model-estimated human joints and not auto-release.

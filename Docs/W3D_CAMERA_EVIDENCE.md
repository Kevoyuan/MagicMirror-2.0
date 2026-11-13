# W3d — Local camera calibration evidence (source-only engineering milestone)

This is a **camera-free, offline numerical audit**. It does not calibrate
an iPhone, a webcam, a human body, anatomical model or lens. A low
reprojection error is only evidence that an externally supplied,
unverified camera hypothesis agrees with independently held-out,
declared 3D target correspondences. It is **NOT a licensing or AR gate**.

## Why W3d instead of more procedural filter UI?

W3c proved pinhole projection mathematics on an authored fixture.
Real-world registration needs camera-source-specific intrinsics,
an explicitly measured 3D target in a known coordinate frame,
rigid extrinsics, independent held-out points, lens distortion treatment
and reproducible hardware evidence. W3d begins the *evidence* work
without secretly fitting a camera from unverified MediaPipe model-depth
observations.

## File contract (Version 1)

Users may open the **Diagnostics → Check offline camera evidence** dialog
and choose a local UTF-8 JSON file (max 128 KiB) matching:

```ts
{
  schemaVersion: 1,
  kind: "magicmirror.camera-evidence",
  provenance: "synthetic-fixture" | "external-unverified",
  cameraModel: "pinhole-no-distortion",
  units: "meters-declared",
  intrinsics: {imageWidth:number,imageHeight:number,fx:number,fy:number,cx:number,cy:number},
  worldToCamera: {
    rotation: [r00,r01,r02,r10,r11,r12,r20,r21,r22],
    translation: [tx,ty,tz]
  },
  captures: [
    {id:"reference-1",split:"reference",points:[
      {id:"A",world:[x,y,z],image:[uPx,vPx]}, ... // at least 6
    ]},
    {id:"holdout-1",split:"holdout",points:[
      {id:"G",world:[x,y,z],image:[uPx,vPx]}, ... // >=6, disjoint IDs
    ]}
  ]
}
```

Only the exact keys above are accepted: no camera images, identifying
metadata, network URLs or provenance-assurance flags are allowed. Device
information and signed review evidence must be handled in a separate,
consented human audit, not smuggled into this numerical file.

Coordinates use **unmirrored source-image pixel units**; +X camera right,
+Y camera down, +Z camera forward. Matrix is row-major and right-handed,
world→camera. `meters-declared` is a user declaration, not a proven
physical ruler reading. Lens model is explicitly ideal pinhole with
no distortion; a real-world file should only use already
undistorted image observations or expect inflated residuals.
The file never asserts verified intrinsics, physical dimensions
or camera optical distortion. Real iPhone camera intrinsics and
extrinsics may vary with focus, zoom, orientation and media settings.

The evaluator requires two or more distinct captures (max 8),
a total of at most 256 observations, ≥6 points in reference and
≥6 *different target identities* in holdout, nondegenerate 3D spread,
positive depth, finite coordinates inside the exact source image
and valid right-handed rigid camera transform. The *reference* and
*holdout* metrics are separately reported. Candidate engineering
thresholds: reference and holdout RMSE each ≤1.25% of shorter source
dimension, holdout p95 ≤2.5%. These are **not** clinical, optical
calibration, lens-model, physical or safety acceptance thresholds.

Even a geometric pass returns the following hard-coded flags:
```json
{
  "cameraCalibrationApproved": false,
  "anatomyOverlayApproved": false,
  "sourceAuthenticityVerified": false,
  "note": "LOCAL_GEOMETRY_CHECK_UNVERIFIED"
}
```

No input coordinates, data file, snapshots or user-identifying details
are logged, sent, exported or retained after processing; the page
only retains its short anonymous score summary in memory until reload.
Failed imports display a generic message without echoing JSON input.

## Demonstration and tests

`Web/src/camera-evidence-fixture.ts` creates original, deterministic,
nonplanar 3D positions and numerical pinhole projections, with no
connection to MediaPipe, Z-Anatomy or a real camera. Unit and browser
tests verify positive/negative paths, disjoint holdout IDs, invalid
depth/rotation and preservation of unapproved flags. Hosted Chromium
and WebKit engine simulations still cannot validate real Apple GPU,
camera geometry or physical lens distortion.

## Remaining human work (W3d2)

- Capture and independently measure a **physical** noncoplanar
  multi-point 3D target with consent, ruler/fixture specification,
  named device/browser, real original image dimensions and intrinsics.
- Verify lens distortion / undistortion pipeline and device orientation;
  validate on multiple captured holds, not just synthetic points.
- Review real registration error and drift with the person actually
  moving; evaluate temporal stability and occlusion/side changes.
- Only then plan an opt-in real anatomy binding preview using
  legally cleared source geometry and reviewed joint weights.
- Keep `Web/release-clearance.json` false until independent
  Google pose model-weights rights and SDK metrics/privacy review.

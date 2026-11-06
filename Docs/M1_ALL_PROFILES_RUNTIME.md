# M1 — All three MediaPipe model profiles: real Linux VIDEO smoke and content locks

**Verified on 2026-11-06** in GitHub-hosted Ubuntu / Python 3.11 with
`mediapipe==0.10.35`. These are tests of model loading and invocation, **not**
real-human detection accuracy, output latency, Unity performance, or a
Windows/macOS compatibility claim.

## Model provenance and tested hashes

All three official MediaPipe Pose Landmarker bundles were downloaded from
the corresponding Google-hosted `float16/latest` storage URLs and actually
loaded into PoseLandmarker VIDEO mode, which processed **three uniform RGB
frames per profile** with strictly increasing synthetic timestamps.

| Profile | Size (bytes) | SHA-256 |
|---|---:|---|
| Lite | 5,777,746 | `59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a` |
| Full | 9,398,198 | `4eaa5eb7a98365221087693fcc286334cf0858e2eb6e15b506aa4a7ecdcec4ad` |
| Heavy | 30,664,242 | `64437af838a65d18e5ba7a0d39b465540069bc8aae8308de3e318aad31fcbc7b` |

These exact hashes and sizes are now enforced in
`Tools/pose_sidecar/download_model.py` for both existing local files and
newly downloaded files. The URL suffix `latest` remains mutable, so future
upstream replacement **must fail closed** instead of silently accepting
different model bytes. This checksum records artifact *identity*, not that
the publisher is trustworthy or that redistribution is licensed.

## Commands

From repository root (on Linux, MediaPipe may require libgles2/libegl1/libgl1):

~~~bash
python3 -m pip install -r Tools/pose_sidecar/requirements.txt
python3 -m Tools.pose_sidecar.download_model --all
python3 -m Tools.pose_sidecar.download_model --all --verify-only
python3 -m Tools.pose_sidecar.smoke_runtime --profile lite --frames 3
python3 -m Tools.pose_sidecar.smoke_runtime --profile full --frames 3
python3 -m Tools.pose_sidecar.smoke_runtime --profile heavy --frames 3
~~~

The model blobs are in `Tools/pose_sidecar/models/`, which must stay
`gitignore`d and must not be uploaded as CI artifacts. Headless GitHub
Actions downloads them temporarily in each job. CI runs two independent
Full/Heavy matrix legs and a Lite smoke job.

## Boundaries

- The source input is synthetic uniform color. There is no subject and no
  precision/recall evaluation or real pose tracking performance measurement.
- Absolute model-call times reported by the smoke harness are *diagnostics*
  on blank frames; they cannot be interpreted as a comparison of Lite, Full
  and Heavy inference under real workloads or as end-to-end UI latency.
- No actual Unity Editor compilation, bone animation, depth registration,
  real Z-Anatomy FBX movement, or Windows/macOS webcam execution occurred.
- MediaPipe version is pinned at 0.10.35. Other Python dependencies are
  bounded loosely by requirements and transitively resolved by pip in CI;
  a complete cross-platform wheels lock/OS matrix is still required before
  a production release.
- Full/Heavy compatibility has only been checked on the CI's Linux runner,
  not on the user's hardware.

## Next M1 acceptance gate

Record real camera input, ground-truth anatomical *surface joint* tracking
metrics on consented clips, warm-up conditions, per-profile inference
stability on representative macOS and Windows devices, and actual complete
camera-to-Unity-render display latency. The estimated 3D world landmarks
are not measured bone centers.

# MagicMirror 2.0 — remaining work as acceptance-driven tasks

**Updated:** 2026-11-13. **Active product:** Web-first, open-source,
camera-local educational anatomy mirror. iOS source frozen; Android
canceled. This is the actionable delivery backlog (the
[roadmap](WEB_MVP_ROADMAP.md) retains older research history).

A task is DONE only when its source implementation and appropriate
verification exist. Unit tests and emulated WebKit are **not** real-device
QA; a filename or license label is **not** copyright clearance.
No automatic claim that a code check equals product acceptance.

| ID | Task / dependency | Now | Acceptance evidence |
|---|---|---|---|
| 1a | W3d external camera evidence parser & independent holdout audit; W3c | Implementing | Strict bounded input, known 3D points vs unmirrored image pixels, positive depth, nondegenerate target, RMSE+p95 separately on disjoint reference/holdout; tests and EN/ZH offline UI; always unverified |
| 1b | W3d physical camera acceptance; 1a | Blocked: no measured device evidence supplied | Source-image resolution and measured target, device/browser/rotation, true intrinsics/distortion, physical reference and independent holdout reprojection, named test engineer, dated acceptance |
| 2a | W2m per-mesh provenance checklist; current local atlas | Source implemented, real assets remain unreviewed | Source SHA-locked inventory, all actual source mesh identities, author, origin, declared license and exception/NC flags; no automatic redistribution clearance |
| 2b | W2n lawful rigged anatomical rest source; 2a + reviewed rights | Original 19-joint SkinnedMesh study in progress (W2n1); **real source still blocked** | Human-reviewed source geometry, body axes, normalized connected joint graph, skin weights, isolated poses, validated rig errors & measurable GPU cost |
| 3 | W3e camera/body to REAL atlas skinning; 1b + 2b | Blocked | Camera-space projection residuals on physical devices, stable left/right, moving torso/arms/legs, occlusion fallbacks; no fake inner-bone precision |
| 4 | W4 semantic skeleton/muscle/organ layers and learning; 2b + 3 | Partially existing original notes/static local study | Real material/section hierarchy, selection and EN/ZH sourced notes backed by reviewed meshes |
| 5 | W1 real browser QA; Web running | Blocked: physical/browser evidence needed | iPhone Safari/desktop Chrome camera permission, flip/crop, worker fallback, pause/background recovery, rate, thermal/battery and screenshots |
| 6 | W0/W4 public static site; model and privacy review + 5 | Blocked | PoseLandmarker weight redistribution proof, MediaPipe SDK metrics/privacy notice, attribution/notices, reviewed production release lock, HTTPS hosting |

### Critical path

**1a → 1b** and **2a → 2b** run in parallel; both converge into
**3 (real anatomy retargeting)** → **4 (real learning layers)**.
**5 + 6** are required for public product acceptance but do not
establish geometry correctness.

### Scope truth

Already implemented (source, not full product acceptance): Web camera
and confidence gates, single Worker/main fallback, 2D proxy, W3a
original 2.5D articulated rig, W3b model-world consistency,
W3c synthetic perspective evidence, local-only FBX/GLB research,
mapping/anchor/virtual-chain authoring, EN/ZH, generated GLB,
local tutorial and browser CI. No genuine full human anatomical
model is currently redistributed, no legal skinning rights
are approved and no real camera registration is accepted.

`releaseApproved` must remain FALSE for this whole task series until
independently reviewed. A composite percent would be judgmental, not
an inspectable engineering KPI; prioritize critical-path milestones.

### W2m1 source progress (2026-11-13)

The source implementation now provides SHA-locked local per-mesh
license evidence template export and local audit import,
with NC/ShareAlike/missing counts and permanent false rights
approval. The original "2a W2m" table row is therefore
**source implemented / actual-source legal review still blocked**.
A real Z-Anatomy mesh/source hash and independent author/asset
rights review have not been provided. See
[W2M_ANATOMY_RIGHTS.md](W2M_ANATOMY_RIGHTS.md).

## GitHub acceptance issues (created 2026-11-13)

These represent **open external or source-verified acceptance**, not
work executed in the background. Follow the dependency order.

- [#78](https://github.com/Kevoyuan/MagicMirror-2.0/issues/78) W3d2 physical camera/3D target evidence
- [#79](https://github.com/Kevoyuan/MagicMirror-2.0/issues/79) W2n lawful canonical anatomical rest rig and skinning
- [#80](https://github.com/Kevoyuan/MagicMirror-2.0/issues/80) W3e actual atlas camera-space retargeting
- [#81](https://github.com/Kevoyuan/MagicMirror-2.0/issues/81) W4 genuine layered anatomy and source-backed study
- [#82](https://github.com/Kevoyuan/MagicMirror-2.0/issues/82) W1 real iPhone Safari/desktop Chrome hardware QA
- [#83](https://github.com/Kevoyuan/MagicMirror-2.0/issues/83) W4 public release weight/SDK/privacy/mesh rights

Engineered first slices: W3d1 [#74](https://github.com/Kevoyuan/MagicMirror-2.0/pull/74),
and W2m1 [#76](https://github.com/Kevoyuan/MagicMirror-2.0/pull/76).
Source work does not close physical/legal issues.

### W2n1 mechanical completion ≠ anatomical product acceptance

A generated original 19-joint full-body test rig demonstrates real
Three.js Bone parent transforms, normalized `skinIndex/skinWeight`
buffers, GLB export/import and an authored elbow/knee animation. This
is **independent of** Z-Anatomy/BodyParts3D model copyright and
MediaPipe camera measurements. Its joints use fictional authored
positions and its mesh is an abstract tubular mannequin, not real
bone shapes. Rig quality samples are NOT exhaustive anatomical
verification.

Merged source/test milestone [PR #84](https://github.com/Kevoyuan/MagicMirror-2.0/pull/84):
**201/201 unit tests** and **26/26 hosted Chromium/WebKit engine
browser tests**; main Web/Foundations CI passed. These verify a
purely original GLB/skin/animation pipeline and do not provide
real anatomical source or physical device acceptance.
[W2n1 engineering contract](W2N1_CANONICAL_SKINNED_FIXTURE.md)
defines all unreleased aspects. Issue #79 stays open until the
actual lawful, anatomically reviewed rest source and real mesh
weights are available.

# Mobile-3/4: source rights, real rig weights and camera registration

**Status: engineering gates and verified test fixtures, not an approved model or
a physical-iPhone demonstration.** This document governs the only active
iPhone/iOS product. It does not authorize any third-party mesh.

## 1. Pin the real model before reviewing it

First audit **only the skeletal system**, to reduce mixed-source
licensing and articulation complexity. The pinned upstream is:

- `LluisV/Z-Anatomy`, commit `6c7f9016bd5899ac8edafd31b9900c151df42ed6`
- `Resources/Models/FBX/SkeletalSystem100.fbx`
- Exactly **41,339,660 bytes**, Git blob SHA-1
  `7c62e45211bf3992bb7239170343e06e2b073865`

The main Z-Anatomy project identifies its core as CC BY-SA 4.0, adapted
from BodyParts3D under CC BY-SA 2.1 Japan. Their notices also identify
third-party models with additional licenses, including Dundee **inner
ear CC BY-NC-SA 4.0** and Lissie Cowley **kidney CC BY-NC 4.0**.
**Neither a global CC BY-SA header nor a source filename proves
each included object is free of non-commercial restrictions.**

- [Original model license](https://github.com/Z-Anatomy/Models-of-human-anatomy/blob/master/License.txt)
- [Original source credits](https://github.com/Z-Anatomy/Models-of-human-anatomy/blob/master/Readme.md)
- [Pinned FBX predecessor model notice](https://github.com/LluisV/Z-Anatomy/blob/PC-Version/Resources/Models/License.txt)
- [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)
- [BodyParts3D data](https://dbarchive.biosciencedbc.jp/en/bodyparts3d/)

**Do not ship** the FBX, derivatives, thumbnails or other assets from a
source with unresolved provenance. The author must confirm obligations
for actual distribution, including appropriate attribution, indicated
modifications and distribution of derivative geometry under compatible
share-alike terms. Original app code and its licensing are a separate
matter. Seek a qualified rights review where uncertain.

## 2. Inventory the ORIGINAL FBX, no invented joint mapping

On a developer workstation with Blender and Python, from repo root:

```bash
python3 -m Tools.anatomy_tools.fetch_atlas --download
python3 -m Tools.anatomy_tools.fetch_atlas --verify-only
blender -b --python Mobile/iOS/Scripts/inventory_source_fbx.py -- \
  --system skeleton \
  --fbx Unity/Assets/ThirdParty/ZAnatomy/SkeletalSystem100.fbx \
  --out /private/skeleton.audit-draft.json
```

The inventory records every imported source mesh's exact hierarchy
path, vertex/polygon counts and authored Blender group names; it
doesn't infer **any** anatomical bone, license identity, normal axis or
animation weight. **Every license, rig ID, anchor and approval is
deliberately null/false/unresolved.** The draft is a private
human-reviewed source, not a distributable asset.

The one-time source inspection workflow is also permitted to download
that exact pinned FBX in an isolated Actions runner and retain only
a text review draft, never the FBX or derived mesh. It does not auto-
approve the atlas or confer rights.

## 3. Human review fields are mandatory for each original source mesh

The review file must enumerate EXACTLY all source mesh paths. The
`bindings` entry for each mesh requires:

- `componentLicense`: original source name, unique source mesh
  identity, license ID, author credit, HTTPS evidence URL, origin notes,
  `humanReviewed: true` and `commercialReuseConfirmed: true`.
  Automatic checks accept only `CC-BY-SA-4.0`, `CC-BY-SA-2.1-JP`
  or `CC-BY-4.0` (with their obligations). `CC-BY-NC-4.0`,
  `CC-BY-NC-SA-4.0`, unknown and blank licenses **fail**; the
  bool cannot override them. A rights reviewer must **actually**
  inspect object origin; these fields are documentary assertions,
  not a substitute for legal clearance.
- `componentLicenseReview`: named human reviewer, real ISO date,
  `intendedUse: "commercial-distribution"` and review notes.
  Missing, future-dated and anonymous records fail.
- `group`: torso / arms / legs; `fromLandmark` and `toLandmark`:
  actual MediaPipe semantic pairing; distinct integer IDs in 0..32.
  `restFrom` and `restTo`: independently measured reference
  segment anchors in **source-import world coordinates**, not guessed
  bone pivots or image pixels.
- `boneId`, `parentBoneId`, `anchorsReviewed: true`: reviewed
  unique IDs and exact hierarchy edges for every original mesh.
  A coherent rig requires human-reviewed shoulders/hips, correct
  left/right identity, no cycles and physical rest-parent relationships.
- Optional GPU skinning: `reviewedJointWeights: true` and
  `reviewedRigHierarchy: true` require an actual Blender group
  `vertexGroupToBoneId` map on each source mesh, plus an
  `approvedSkinBoneIds` allowlist for that mesh. The map must point
  only to pre-reviewed, included bones and allowed influence IDs.
  Every exported triangle vertex needs 1–4 real authored nonnegative
  weights summing approximately to one. The native GPU palette is
  currently limited to **256 reviewed bones**. **Never synthesize
  weights from distance or mesh filenames.**

The export and assembly now record the normalized per-mesh license
ledger in `*.manifest.json` and check every entry against the
private review before assembling the rig. The independent verifier
rejects missing, unknown or NC component evidence; the iOS loader
rejects bundled model bytes when any component lacks documentary
rights metadata. The flags are not cryptographic signatures and
cannot replace inspecting the actual human source record.

## 4. Export, verify and assemble only after actual rights/rig review

```bash
blender -b --python Mobile/iOS/Scripts/export_full_atlas.py -- \
  --system skeleton \
  --fbx Unity/Assets/ThirdParty/ZAnatomy/SkeletalSystem100.fbx \
  --review /private/skeleton.approved-review.json \
  --out /private/approved-atlas

python3 Mobile/iOS/Scripts/verify_atlas_package.py \
  --system skeleton --package /private/approved-atlas

python3 Mobile/iOS/Scripts/assemble_reviewed_atlas_rig.py \
  --system skeleton --package /private/approved-atlas \
  --review /private/skeleton.approved-review.json
```

Export fails if the source bytes differ, any mesh lacks a binding,
source rights are incomplete, triangle budget exceeds 180,000
**unindexed vertices**, or weight groups are missing/unreviewed.
Assembly checks bone IDs, parent cycles, landmark rest anchors,
vertex spans, hash agreement and every nonzero skinning weight
against that original mesh's reviewer-approved influence list.

An actual full source file may be too large, unrigged or have too many
mesh/rig nodes for the initial native GPU budget. That is **a
blocker requiring deliberate manual simplification and review**, not
permission to drop meshes silently or invent anatomically meaningful
replacement structures.

## 5. On-device alignment: never treat self-fit as an independent camera

The on-device pipeline already connects AVFoundation source frames,
MediaPipe 33-point world/image estimates, a background 6DoF candidate
solver, whole-atlas registration and Metal GPU skinning.

A new **continuity gate** rejects a diagnostic camera hypothesis until
three consecutively timed source candidates agree in orientation and
translation, without yaw flips, replay, incompatible resolution,
excessive reprojection error or underconstrained landmarks.
It only improves the *unreviewed diagnostic*. Its result is **not**
passed to `installIndependentlyReviewedCameraProvider`.

Why: a low reprojection error on the SAME MediaPipe points used to
fit the camera cannot independently certify true body-to-camera
extrinsics, bone positions or real anatomical correspondence.
A real signed iPhone/actual moving-subject study must validate the
camera with independent targets or human-measured reference geometry.
Until then the reviewed-atlas camera gate stays closed and the app
falls back to the clearly labelled procedural reference.

## 6. Reproducible engineering checks versus blocked release gates

```bash
python3 -m unittest discover -s Mobile/iOS/Scripts/tests -v
cd Mobile/iOS && xcodegen generate --spec project.yml
xcodebuild -project MagicMirror.xcodeproj -scheme MagicMirror \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build-for-testing
```

GitHub CI compiling XCTest is not the same as running them on iPhone.
Before any shipped real atlas: obtain signed per-component rights
records, independent rig and skin evaluation, verified orientation
under front/side/turn/occlusion, >10 minutes on a named iPhone and
measured display FPS, battery/thermal behavior and motion-to-photon
latency. Release target remains >=30 displayed FPS and <=150 ms p95
movement-to-screen, **currently unverified**.


## Verified pinned original asset inspection

The first actual GitHub Actions Blender 5 import of the pinned
skeletal FBX succeeded: **1,952 original mesh objects, 828,711 vertices,
1,093,544 polygon faces, zero pre-existing object vertex-weight groups,
and four non-renderable imported objects**. The workflow checks the
source's SHA and provides a **text-only unapproved review draft**; it
does not distribute any geometry or validate a person/camera.
Source evidence and the 256-joint GPU architectural conflict are
recorded in
`Docs/IOS_ACTUAL_ZANATOMY_SKELETON_AUDIT_2026-11-08.md`.

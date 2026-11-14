# W2n1 — Original canonical skinned rig and authored joint graph

**Platform:** Web-only offline study. **Source state:** original generated,
non-anatomical rig fixture. **Not:** Z-Anatomy / BodyParts3D, external
rights clearance, physical body measurement, live camera retargeting,
medical interpretation, or a real person's bone locations.

## Why W2n1 exists

The prior W2 work can inspect original local FBX/GLB source meshes and
authored weights, but it did not ship a working full-body **SkinnedMesh**
with an actual connected 3D joint hierarchy, vertex weights and
joint-driven animation. W2n1 supplies this mechanical milestone with
wholly original generated geometry. It tests the full GLB
generation → GLTFExporter → local GLTFLoader → sampled skin weights →
animation playback path before using any third-party anatomy.

## The engineering-only reference

- `Web/src/canonical-rig.ts` owns a fixed **19-joint** parent tree:
  pelvis; spine/chest/neck/head; left/right shoulder/elbow/wrist;
  left/right hip/knee/ankle/foot.
- Absolute rest coordinates are AUTHOR-CHOOSEN units, not meters or real
  measured anatomy. Fixture axis conventions are +X figure-left,
  +Y up, +Z forward. Imported models may use different conventions.
  Anatomical left/right is never inferred from English mesh names.
- The pure validator rejects duplicate/missing nodes, invalid parent
  tree, nonfinite rest positions, zero/giant bone lengths, reversed
  sides, displaced pelvis and upside-down legs.
- A separate bounded sample audit rejects invalid/duplicate vertex
  indices, missing weights, unknown joint keys, too many active
  influences and non-normalized weights. These checks concern
  *proposed samples* only, not an imported mesh's full authored
  vertex buffer.
- `canonical-rig-demo.ts` generates 18 original swept tubular
  surface segments with 5 rings/8 sides each. Every generated vertex
  is weighted to a segment's parent and child bones with a linear,
  normalized blend. The entire generated geometry is ONE SkinnedMesh,
  skinned to the same original 19 Bone nodes.
- One local animated clip rotates both elbows and knees through an
  authored reference range. It is not a real person walking, medical
  musculoskeletal movement, or pose inference.

## User workflow

Open **Layers → Local FBX/GLB study → Original 19-joint skinned demo**.
Only then generate the authored in-memory GLB and import through the
SAME existing research viewer; the source SHA256 and mesh inventories,
rig-sample diagnostics, clip selection and play/pause remain active.
The main mirror camera remains off while the separate local inspector
is open. No executable pose injection, network model request,
auto-download of anatomy, database, storage or release flag.

Original 3-box source-study remains available and unchanged.

## Acceptance and non-acceptance

Unit tests verify exact topology/laterality, invalid rotations/weights
and permanent fail-closed flags; browser smoke must demonstrate that
the actual generated GLB loads with **one authored SkinnedMesh**,
**19 Bone joints**, **no sampled weight failures**, **one animation**,
and survives camera-off/EN-ZH/close interactions in Chromium desktop
and iPhone-sized WebKit engine emulation.

Even with these checks passing, these flags remain FALSE:

- `anatomicalVerificationApproved`
- `cameraRegistrationApproved`
- `retargetingApproved`
- `publicationRightsApproved`
- `actualMeshSkinningVerified` for the abstract proposed-samples audit

These are *study/fixture* outputs only. Browser WebKit emulation is NOT
physical iPhone Safari QA.

## What still blocks the actual goal

- [ ] W2n2: Choose exact genuine anatomical source, check original
  license/NC exceptions **per mesh** against W2m evidence, pin hash,
  source version and lawful distribution.
- [ ] W2n3: Human-review actual anatomical rest joints, orientation,
  part→joint attachment and authored deformation skin weights, then
  verify real imported SkinnedMesh behavior; do NOT treat this
  original fixture as anatomy.
- [ ] W3d2: Obtain real physical-camera intrinsics/extrinsics,
  distortion and target holdout measurements.
- [ ] W3e: Independent physical-device camera-to-real-rig motion
  registration with occlusion/failure behavior.
- [ ] W1/W4: Real iPhone Safari/Chrome QA, SDK model-weight rights and
  privacy review. `Web/release-clearance.json` stays false.

This technical experiment does not close [issue #79](https://github.com/Kevoyuan/MagicMirror-2.0/issues/79)
because the authentic anatomical model and legal/real-rig review are
still unavailable.

# Third-party assets — licensing and release gate

This newly initialized repository includes **no third-party anatomy meshes,
model weights or OpenPose native dependencies**.

## Anatomy sources (not shipped)

- https://github.com/Z-Anatomy/Models-of-human-anatomy
- https://github.com/LluisV/Z-Anatomy/tree/PC-Version
- Complete preferred skeletal FBX: SkeletalSystem100.fbx

Z-Anatomy sources mention CC BY-SA 4.0 and BodyParts3D CC BY-SA 2.1 Japan,
with certain other meshes having non-commercial restrictions. Determine the
**exact rights for each model** before bundling anything. The original atlas
is acquired separately and excluded from Git.

## Release checklist

1. Record revision, source URL, authors, transformations and mesh license.
2. Audit each asset independently, especially for non-commercial terms.
3. Include required attribution, notices and share-alike requirements.
4. Do not redistribute unresolved assets or call the project medical imaging.
5. Obtain a separate appropriate grant for model weights where required.

This inventory is an engineering gate, not legal advice.


## Per-component release controls (2026-11-08)

Upstream [Z-Anatomy License.txt](https://github.com/Z-Anatomy/Models-of-human-anatomy/blob/master/License.txt)
states the atlas core's CC BY-SA terms and credits DBCLS/BodyParts3D.
It separately identifies Dundee inner-ear and Lissie Cowley kidney
content under non-commercial CC licenses. A general repository header
cannot grant commercial use of those separately sourced components.

The iOS exporter, independent binary preflight, rig assembler and
installed model loader now require *per-mesh human-reviewed* evidence
of original source and a compatible license. The source inventory
tool initializes every original mesh's rights/rig state as unresolved.
There is no way to produce a verified commercial package simply by
renaming NC files or asserting a top-level CC BY-SA flag. Actual
provenance review and license compliance remain human responsibilities.
See `Docs/IOS_ATLAS_SOURCE_RIGHTS_AND_REGISTRATION.md`.

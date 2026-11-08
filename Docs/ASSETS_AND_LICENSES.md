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


## Paid App Store distribution gate (2026-11-08)

The paid iOS app has **two independent content-rights responsibilities**:
(1) actual reviewed anatomy models and (2) on-device MediaPipe
PoseLandmarker `.task` weight binaries. The published MediaPipe
SDK source is generally Apache-2.0, but this alone does not prove
the separately hosted task model's commercial redistributability.

The BodyParts3D site's latest 2025 copyright notice now states
**CC BY 4.0**, while older historical versions and Z-Anatomy-derived
notices cite **CC BY-SA 2.1 Japan**. Determine rights for exact
pinned source files rather than automatically claiming newer terms
retroactively. Upstream Z-Anatomy also credits NC-restricted material.

We recommend new, independently authored/commissioned animation assets
with explicit written commercial App Store redistribution and
technical-restrictions rights; a German commission should spell out
sufficient `Nutzungsrechte` rather than assuming ownership transfer.
Use a specialist IP lawyer to review all signed rights and potential
share-alike/DRM conflicts. An artist's promise or manifest flag alone
cannot resolve unlicensed source content.

`Mobile/iOS/project.yml` now invokes a fail-closed paid Release
asset/NOTICE check against the actual app bundle. The current
`Mobile/iOS/CommercialRelease/paid-app-clearance.json` is **BLOCKED**.
This is the correct default. Research source is not App Store release.
See `Docs/PAID_IOS_APP_STORE_RELEASE_POLICY.md`.

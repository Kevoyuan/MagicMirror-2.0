# Pinned Z-Anatomy skeletal FBX: actual source inspection

**Inspection date:** 2026-11-08 (GitHub Actions, Ubuntu / headless Blender 5)

**Evidence:** [successful pinned original model import and text-only inventory](https://github.com/Kevoyuan/MagicMirror-2.0/actions/runs/42474861536).
The run verifies the immutable 41,339,660-byte source file with Git blob
SHA-1 `7c62e45211bf3992bb7239170343e06e2b073865`, imports its
actual hierarchy, and emits only `source-skeleton-audit-draft` (text
JSON artifact retained for 7 days). It does not upload or redistribute
the original FBX or derived geometry.

## Real original-source measurements

| Measurement | Verified result |
| --- | ---: |
| Blender-imported `MESH` objects | **1,952** |
| Source mesh vertices | **828,711** |
| Source polygon faces | **1,093,544** |
| Mesh objects with source vertex groups | **0** |
| Non-renderable / geometrically problematic mesh objects | **4** |
| Rights-reviewed, redistributable objects demonstrated | **0** |
| Actual human-reviewed atlas skin weights demonstrated | **0** |

These are **source inventory** counts, not unindexed triangle stream
vertex counts and not an iPhone rendering benchmark. The source
polygon topology and original hierarchy must be independently reviewed
before optimization. All 1,952 source entries are intentionally
unapproved in the generated private review draft.

## Concrete blockers exposed by the real data

1. **No authored skin weights.** The original inspected FBX includes
   zero vertex-group-bearing mesh objects. A human anatomist/3D rigger
   must first define bone pivots, semantic hierarchy, attachments and
   weights; inferred proximity to MediaPipe image landmarks is not
   acceptable anatomical evidence.
2. **1,952 source mesh objects vs 256 GPU bone palette entries.** The
   existing rig manifest models **one unique joint ID per mesh** and
   the Metal skinning palette is capped at 256 bones. The complete
   original cannot enter this one-to-one contract directly. A new
   *many-original-meshes → one reviewed anatomical joint* mapping is
   needed, keeping source mesh path and license evidence per geometry
   part while reducing true independent animated joints. Do not
   manufacture 1,952 independently moving "bones".
3. **Geometry budget.** The current `MMATLAS1` renderer accepts at
   most **180,000 unindexed triangle vertices**; the upstream original
   has over a million polygon faces. It cannot be shipped at the
   inspected size through the existing exporter. Deliberate,
   human-reviewed simplification, per-region LOD, and mesh performance
   instrumentation are required; silent mesh dropping is prohibited.
4. **Four non-renderable imported objects** need explicit per-object
   disposition (retain as meaningful parent/group, empty source mesh
   exclusion or repaired geometry) with source identity and human
   change notes. The inventory retains them rather than hiding them.
5. **License and privacy.** General Z-Anatomy CC BY-SA statements do
   not authorize NC/unknown individual imported components. No
   commercial-use approval or license compatibility has been issued
   for these 1,952 objects, and no distributable asset is bundled.
6. **Independent camera extrinsics.** MediaPipe-derived 6DoF
   reprojection is self-referential diagnostic evidence. No independent
   calibrated camera/body transform or matching actual iPhone 3D atlas
   overlays have been validated.

## Next real implementation stages (no fake pass conditions)

**A — Human rights review:** Audit each original mesh against the
upstream source/attribution material, populate the per-mesh rights
ledger, determine applicable share-alike and excluded restricted
content. Keep unclear objects out of commercial packages; retain
provenance even if meshes are consolidated or optimized.

**B — Joint/mesh contract revision:** Add a separately authored
`reviewedRigNodes` hierarchy with no more than 256 real anatomical
motion joints and map all permitted source `MESH` paths to those
joints through reviewer-approved assignments. Adapt the Swift
mesh-to-bone projector, skinned GPU batches, hit testing and verifier
to preserve every original part's path, attribution and reviewed
influence palette. Add synthetic tests for multiple meshes sharing
one joint, missing assignments, cyclic hierarchy and left/right
identity. The current one-to-one runtime must **not** be treated as
compatible with the 1,952-object source until this migration.

**C — Offline authored deformation:** Create an actual Blender
armature/pivots and human-reviewed source vertex groups on the
permitted meshes, author weights and freeze a separate original/rest
reference pose. Do not fill weights via heuristic and call it verified.
Export as a mobile-optimized, integrity-checked `MMATLAS1` and
consolidated GPU skinning bundle with audited geometry budgets.

**D — Source-frame live validation:** Independently calibrate
camera/body transform and compare actual observed body motion,
reprojection and visual overlay on named real iPhones. Gate portrait,
front/side/turn, partial occlusion, model loss and discontinuities;
retain the procedural reference when any validation fails.

**Bottom line:** Verified original model import and documentary/legal
gates are implemented. A real working, approved deformable atlas on
iPhone is **not** yet implemented or validated. No personal bones
are measured or diagnosed from the RGB camera.

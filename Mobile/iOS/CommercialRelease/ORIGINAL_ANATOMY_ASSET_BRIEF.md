# MagicMirror 2.0 — Original commercial 3D anatomy commissioning brief

**Goal:** commission a new, commercially usable **illustrative,
standard-reference** whole-body anatomical skeleton for an iPhone
app. **Do not copy or trace Z-Anatomy, BodyParts3D or other third-party
mesh files** into the commissioned deliverable without a separate,
independently approved rights record.

## Deliverables

1. Original source Blender project, with inspected polygon hierarchy,
   armature, material setup, textures and references documenting where
   geometry was independently created.
2. A human-reviewed anatomically reasonable reference rest pose,
   joint labels, left/right anatomical side, pivot positions,
   parent-child relationships and constrained motion ranges.
3. A coherent GPU-compatible 3D rig with <=256 independently animated
   joint palette entries; multiple individual mesh objects can attach
   to one reviewed joint. Never infer 1,952 motion bones from the
   earlier Z-Anatomy research inventory.
4. Authored vertex skin weights and an inspection report demonstrating
   correct shoulder/elbow/wrist and hip/knee/ankle deformation;
   no unreviewed auto skinning or silent influence pruning.
5. A mobile-ready LOD whose exported, **unindexed triangle** budget
   fits the initial 180,000 vertex renderer limit, unless a separately
   approved renderer optimization raises it with measured iPhone
   testing. Record every simplification, surface normal and region
   mapping; no missing or invented anatomical parts.
6. Exact-source copyright/licence provenance and a machine-readable
   asset manifest, including crypto hashes of delivered source and
   mobile geometry, revision IDs, model credits and any retained
   third-party material (if any).
7. Manual QA frames for front/back/side, raised arms, crossed limbs,
   squat, partial body and occlusion; actual signed iPhone tests
   and calibration are separately part of our engineering work.

## Written rights that the contract should address

**Ask a qualified German/IP lawyer to word the actual agreement.**
Germany generally protects authorship; rather than assuming automatic
"work made for hire", explicitly obtain suitable **exclusive Nutzungsrechte**
(where applicable) or sufficiently broad written licenses to the
deliverables and necessary component rights. Spell out:

- Worldwide distribution, commercial use, charging upfront,
  subscriptions and in-app purchases;
- App Store and other approved iOS distribution, Apple device-level
  technical restrictions/DRM, customer access, permitted sublicensing
  needed for platforms and service providers;
- Rights to modify, optimize, animate, merge, convert, localize,
  make derivatives, produce screenshots/videos and market the app;
- Duration, territorial scope, any termination rights, separate-source
  delivery, permitted credit and reproducible re-use;
- Warranty that all source geometry/weights/textures are original or
  separately licensed and provided with sufficient commercial rights;
- No undisclosed CC BY-NC, NC-SA, ND, ShareAlike, educational-only,
  editorial-only, AI-model-use-only or marketplace-specific restrictions;
- Correct attribution/third-party license disclosures and rights chain
  if anything external is incorporated with our written approval;
- Revision/defect resolution, documented handover and security of all
  deliverable/source project files.

## Acceptance gate

An attractive rendered 3D reference mesh is **NOT sufficient**.
Acceptance requires licensing evidence, complete source handover,
reasonable inspected anatomically consistent joint rig/weights,
and a reproducible mobile export that loads and aligns under
independently measured physical iPhone camera conditions.

**Owner note:** Do not publish or monetize unreviewed external atlas
assets in previews, advertising or the shipped iPhone bundle.

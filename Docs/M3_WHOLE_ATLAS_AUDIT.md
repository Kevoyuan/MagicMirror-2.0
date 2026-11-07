# M3 — Whole-atlas inventory audit before motion binding

**Status:** source-only readiness gate, verified on synthetic JSON only.
**NOT YET:** a real imported Z-Anatomy FBX, reviewed bone identity/joint
anchors, verified licensing, or tested Unity full-body motion.

## Why this gate exists

The complete `SkeletalSystem100.fbx` is a spatial anatomy atlas, **not**
a ready-rigged humanoid. The goal is to preserve one original FBX and bind
verified regional subtrees to an anatomical Motion Rig; splitting it into
independent files would lose provenance and spatial context.

A name like "humerus" is not enough evidence to assign a specific renderer
to a subject-side joint, and selecting a whole parent subtree may overlap
another moving region. This offline audit deliberately blocks automatic
verification and detects data inconsistencies before anyone tries to animate
the model.

## Run after obtaining and inspecting the intact source FBX

1. Acquire the pinned *original* FBX locally (no publishing binary):

   ~~~bash
   python3 -m Tools.anatomy_tools.fetch_atlas --download
   python3 -m Tools.anatomy_tools.fetch_atlas --verify-only
   ~~~

   The downloader checks exact byte length, source commit and Git blob
   digest. These checks confirm file identity, **not anatomical correctness
   or license rights**.

2. When Unity becomes available, open `Unity/` with the pinned Unity 6.3
   Editor. Import the whole FBX. Select **MagicMirror > Phase 4 >
   Full Atlas Setup** and export the Unity renderer hierarchy inventory
   to a JSON file. This preserves stable indexed Unity hierarchy paths.

3. Inspect the exported JSON **without** Unity:

   ~~~bash
   python3 -m Tools.anatomy_tools.audit_unity_inventory \
     --inventory /path/to/FullSkeletonHierarchyInventory.json \
     --report /tmp/magicmirror-atlas-audit.json
   ~~~

   The tool compares `Assets-Manifest/asset_sources.json` with the pinned
   downloader constants, checks the exact atlas asset path, renderer counts,
   duplicate/invalid paths, unreviewed flags, candidate motion groups,
   unsupported SkinnedMeshRenderers, and ancestor/descendant path conflicts.

4. Review each candidate in the actual intact FBX, validate anatomy side
   and renderer membership, establish true local proximal/distal anchors,
   review relevant source licenses and annotate the original model profile.
   Only then mark individual motion groups `reviewed` in Unity.

## Report contract

The output contains a list of **UNVERIFIED** candidate segments and
`rendererRootPathCandidates`, plus:

- `readyForRealAnatomyRig: false` (always; metadata alone cannot certify).
- `identityAndAnchorsReviewed: false` (always).
- `licensesReviewed: false` (always).
- `atlasStartLocal`, `atlasEndLocal`: always `null`; never invent anchors.
- Parent-child path conflicts and unsupported skinned-renderer counts.

The audit does not generate or modify any `FullBodyAtlasProfile` asset,
does not export FBX objects, does not automatically group all descendants,
and does not claim that an indexed Unity path is a stable anatomical ID.

## Offline validation (no actual FBX or Editor)

~~~bash
python3 -m unittest Tools.anatomy_tools.tests.test_audit_unity_inventory -v
python3 -m unittest discover -s Tools/anatomy_tools/tests -v
~~~

These tests use small, clearly synthetic reports. CI can test the
**schema/provenance contract** even while real Unity/FBX validation is
unavailable; real M3 acceptance remains blocked until hardware and a
reviewed full atlas are available.

## Source / distribution cautions

Z-Anatomy may include mesh-specific licenses and material derived from
BodyParts3D. A single top-level CC license claim is not a sufficient
per-mesh distribution review. The model and any personal recordings remain
out of Git by default. See `Docs/ASSETS_AND_LICENSES.md`.

**M3 next gate:** actual full FBX imported and visually inspected in Unity;
stable hierarchy mapping, correct rest-pose geometry and joint-center
annotations, legal attribution and source provenance, and the real atlas
moving without detached/overlapping bones under M4 constraints.

# MagicMirror paid iOS model sourcing — decision record (2026-11-08)

**Product:** paid iPhone/iOS educational anatomy AR, original app code
separate from 3D reference geometry. **No third-party anatomy cleared
for release today.** No legal advice or rights waiver is inferred.

## Real options, ordered by source-control risk

| Route | What is actually available | Main risk | Current decision |
| --- | --- | --- | --- |
| **A. New commissioned/original rig** | New Blender meshes, armature, actual authored weights and all source material | Written grant/assignment must really cover commercial Apple paid distribution, all elements, modifications and technical restrictions | **Preferred for lowest licensing ambiguity** |
| **B. Download directly from official DBCLS BodyParts3D archive** | BodyParts3D 4.0 official OBJ data, `isa_BP3D_4.0_obj_99.zip` and `partof_BP3D_4.0_obj_99.zip` | Official current license is CC BY 4.0, but exact dataset revision, provenance, attribution, downstream DRM restrictions and anatomy rigging still need review | **Promising lower-cost source; not yet release-approved** |
| **C. Repackage Z-Anatomy/LluisV FBX** | Previously SHA-verified original skeleton with 1,952 source mesh objects and no existing authored weights | Third-party NC/unknown subcomponents, old BY-SA chain, derivative share-alike/DRM, no ready mobile rig | **Research-only, not a recommended commercial asset** |

## Official BodyParts3D alternative — factual provenance

The [DBCLS official download page](https://dbarchive.biosciencedbc.jp/en/bodyparts3d/download.html)
offers version 4.0 reduced OBJ model archives. Its
[current official license page](https://dbarchive.biosciencedbc.jp/en/bodyparts3d/lic.html)
was updated **2025-02-27** and states **Creative Commons
Attribution 4.0 International** with the mandatory author credit:

> BodyParts3D, © The Database Center for Life Science licensed under CC Attribution 4.0 International

The official archive [release
README](https://dbarchive.biosciencedbc.jp/data/bodyparts3d/LATEST/README_e.html)
says the geometry data (release 4.0) was updated **2013-06-19**
and the license notice was updated **2025-02-27**. In contrast,
[older archive snapshots](https://dbarchive.biosciencedbc.jp/data/bodyparts3d/20110915/README_e.html)
mention CC BY-SA 2.1 Japan. Cite the EXACT archive/version
and the CURRENT accompanying official license evidence; do not
rewrite Z-Anatomy-derived mesh provenance as direct CC BY 4.0.

**CC BY 4.0 is commercially usable and has no ShareAlike requirement**,
but [its terms still prohibit additional effective technological
restrictions](https://creativecommons.org/licenses/by/4.0/deed.en).
An Apple App Store binary may involve additional restrictions. An IP
lawyer must evaluate the actual paid distribution mechanism or seek
separate written permission where necessary. Attribution alone cannot
settle this. The present paid release gate deliberately **does not
auto-approve even direct CC BY 4.0 anatomy** without additional
documented App Store technical-restrictions clearance.

All imported 3D models, even CC BY 4.0 originals, still require
source-version hashes, secure locally stored rights evidence,
reviewed semantic mesh IDs, coherent animation rig/skin weights,
mobile geometry optimization and actual physical iPhone calibration.
Do not take someone else's modified BodyParts3D derivative under
different terms and infer it is the original archive.

## Actionable staged plan

1. **Choose a source** (A or B) *before commissioning/adapting geometry*.
   If B: acquire version 4.0 **directly from DBCLS**, record URL/date,
   exact ZIP SHA-256 and included object hash/provenance, and preserve
   the official archive license notice.
2. Obtain independent commercial App Store legal review, including
   whether Apple package redistribution/DRM needs a separate written
   permission; keep actual legal documents private.
3. Verify that no NC/ND/other third-party data is included in the
   delivered source. For commissioned art, obtain suitable documented
   exclusive usage rights under German law and a deliverables handoff.
4. Design <=256 actual motion joints with many source meshes per joint,
   human-reviewed rig, anthropomorphic motion rules and authored weights.
   Preserve original mesh-to-source licensing records after optimization.
5. Verify device privacy and separately hosted PoseLandmarker WEIGHTS,
   not only MediaPipeTasksVision's Apache-2.0 SDK.
6. Only after all above, produce a reviewed `.mmgeom` and
   `*.skinning.json` package, review the actual paid app's notices,
   set commercial release clearance with exact hashes, and run both
   Xcode Release checks plus manual signed-IPA inspection.

**Current outcome: no source 3D anatomy binary/derived model is bundled
or approved for the paid App.** Preventing a release is an intentional
correct engineering state until those rights exist.

# W2m — Per-source-mesh anatomy license evidence workflow

**Status:** Web-only source implementation, no inspected real Z-Anatomy
mesh and no license/legal approval. The goal is to make verification
repeatable before the actual rig/retargeting work.

## Verified upstream scope (not an individual mesh license)

Z-Anatomy's official upstream
[License.txt](https://github.com/Z-Anatomy/Models-of-human-anatomy/blob/master/License.txt)
declares CC BY-SA 4.0 and lists BodyParts3D (CC BY-SA 2.1 Japan) as
source and exceptions including University of Dundee inner-ear work
(CC BY-NC-SA 4.0) and Lissie Cowley kidney
(CC BY-NC 4.0). Attribution and derivative share-alike apply;
NC components cannot be assumed suitable for commercial use.
This is **not** sufficient proof of the origin of an arbitrary
imported FBX mesh; names, hierarchy and provenance must be checked
against the exact source archive and its evidence.

An app may use the project-authored code under MIT, but **this does
not relicense** third-party model artwork or model weights.

## Simpler legal candidate: direct BodyParts3D (verify source version)

The **official** [BodyParts3D database license page]
(https://dbarchive.biosciencedbc.jp/en/bodyparts3d/lic.html),
updated **2025-02-27**, currently specifies **CC BY 4.0** for
the database and its requested attribution. This is potentially a
simpler starting point for independently sourced anatomy geometry
than importing Z-Anatomy's compound derivative collection, which
also identifies noncommercial third-party exceptions.

Do **not** transfer that modern database statement onto arbitrary
older snapshots or Z-Anatomy derivatives: the
[older 2010 archive README]
(https://dbarchive.biosciencedbc.jp/data/bodyparts3d/20100816/README_e.html)
explicitly specifies **CC BY-SA 2.1 Japan**, and older per-file
notices may survive into mirrored archives. Pin the exact dataset
release, URL, checksum, authors, model meshes and current provider
terms, confirm any conflicting archive-specific notices with a
qualified reviewer, and enter actual evidence **per mesh**.
Direct BodyParts3D source does NOT include a ready-to-use
human-motion skinning skeleton or physical camera calibration;
the W2n and W3e engineering gates remain.

## Owner workflow (offline)

1. Import an actual source FBX / self-contained GLB into the existing
   local anatomy viewer. Source SHA-256, file byte count, exact part
   names/hierarchy and mesh count come from the imported bytes.
2. Click **Download per-mesh rights template**. The worksheet
   contains one row per actual source mesh; **ALL values are
   unverified initially**, not guessed from anatomical naming.
3. Fill every mesh's `author`, `originalSourceURL`,
   `licenseId`, `licenseEvidenceURL`, `attribution` and
   `derivativeNotes` based on independent primary evidence.
   Keep `reviewStatus: "NOT_REVIEWED"`, and keep file-level
   `rightsStatus: "NOT_REVIEWED"`,
   `commercialUseApproved:false` and
   `redistributionApproved:false`. These fields cannot be
   changed by a file import; actual approval is a separate
   future human/legal workflow outside this source.
4. Import the filled JSON with the **Check completed local rights
   JSON** control. The validator requires the same source SHA,
   size, exact ordered mesh index/name/path and unchanged nonapproval
   fields. It reports counts of NC (commercial exclusions),
   ShareAlike duties, missing evidence, unresolved licenses and
   potentially ready-for-human-review rows. It never publishes or
   opens a license URL, uploads geometry, or marks anything cleared.
5. Independently inspect all source/author/geometry mappings, review
   translation and derivation status, and provide legally
   appropriate notices before considering public bundled models.

## License claim classes supported by the worksheet

| Declared claim | Triage meaning | Automatic approval |
|---|---|---|
| UNVERIFIED, OTHER, PROPRIETARY | Unresolved source/rights | Never |
| CC-BY-SA-4.0 | Attribution and ShareAlike need manual review | Never |
| CC-BY-SA-2.1-JP | Original/older ShareAlike obligations require manual compatibility review | Never |
| CC-BY-4.0 | Attribution and provenance still need human review | Never |
| CC-BY-NC-SA-4.0 | **NC commercial-use warning**, plus ShareAlike | Never |
| CC-BY-NC-4.0 | **NC commercial-use warning** | Never |

A filled-in website URL is NOT a license grant; a user can claim
anything in an imported worksheet. A model export from Blender or
conversion to GLB does not remove inherited copyright terms.
Nested unexpected fields (including self-declared approvals),
unsafe URLs or mismatched mesh identities are rejected. The import is
local-only and capped at 8 MiB.

## Remaining independent work

- Inspect an actual pinned Z-Anatomy source archive and per-mesh
  provenance, avoiding NC components or obtaining real separate rights.
- Define a lawful, reviewed human **rest rig** with canonical
  joints, local model axes and skin weights; current local source
  viewer has draft mappings/animation inspection only.
- Integrate a genuine rig with camera calibration and real-device
  tests before showing a live anatomy skeleton layer.
- Keep `releaseApproved:false` until independent Google
  PoseLandmarker weight redistribution and SDK privacy/metrics
  obligations are cleared.

This is **engineering inventory/triage**, not legal advice.

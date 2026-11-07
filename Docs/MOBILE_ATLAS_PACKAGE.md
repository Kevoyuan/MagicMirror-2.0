# MagicMirror iOS — whole anatomical atlas package (Mobile-3)

The **phone** loads only an offline, hash-verified, human-reviewed 3D
resource package. There is **no Unity, FBX importer or Python service
inside the installed iOS app**.

## Exact source, model-specific licences and ethical boundary

Pinned input: `LluisV/Z-Anatomy` commit
`6c7f9016bd5899ac8edafd31b9900c151df42ed6`,
`Resources/Models/FBX/SkeletalSystem100.fbx`, 41,339,660 bytes, Git
blob SHA-1 `7c62e45211bf3992bb7239170343e06e2b073865`.

The official Z-Anatomy `Resources/Models/License.txt` attributes
**BodyParts3D — DBCLS — CC BY-SA 2.1 Japan**, and
**Z-Anatomy — CC BY-SA 4.0**. Releasing derived model geometry requires
correct credit, licence notices and the relevant share-alike obligations.
The original atlas and any included third-party subassets must be
reviewed per mesh. The app's original code licence is a separate question.

Sources:
- https://github.com/LluisV/Z-Anatomy/blob/PC-Version/Resources/Models/License.txt
- https://github.com/LluisV/Z-Anatomy/blob/PC-Version/README.md

**No full FBX or derived binary is committed or bundled today.**

## Author-reviewed offline pipeline

1. Download and verify the **whole original** FBX using
   `python3 -m Tools.anatomy_tools.fetch_atlas --download` on a developer
   computer. Do not export separate invented bone FBXs.
2. Inspect its *actual* object hierarchy, anatomy and licence provenance.
3. Create a private `human-reviewed-bindings.json` with explicit
   per-MESH `sourceHierarchyPath`, `displayName`, `group`
   (`arms`/`legs`/`torso`), MediaPipe `fromLandmark`/`toLandmark`,
   and `restFrom`/`restTo` anchors **in source-import world coordinates**.
   Assign a reviewed attachment/parent segment to every source mesh,
   including static pelvis, ribs and skull. Never let a filename heuristic
   silently decide anatomical attachment or left/right.
4. After **human review**, set `reviewedForDistribution: true` and
   `reviewedJointBindings: true`. Include non-empty `modificationNotes`.
   The exporter requires that **every** imported mesh is accounted for.
5. Run, on a developer machine with Blender installed:

   ```bash
   blender -b --python Mobile/iOS/Scripts/export_full_atlas.py -- \
     --fbx Unity/Assets/ThirdParty/ZAnatomy/SkeletalSystem100.fbx \
     --review /path/to/human-reviewed-bindings.json \
     --out Mobile/iOS/Resources
   ```

   The author must first optimize high-poly geometry while preserving
   meaningful anatomy and record the changes. Export refuses more than
   **180,000 triangle vertices**; it never silently decimates.

6. The exporter produces:
   `skeleton_atlas.mmgeom` (one complete named mesh stream),
   `skeleton_atlas.manifest.json` (all part hierarchy paths, reviewed
   anchors, source pin, provenance and SHA), and
   `skeleton_atlas.ATTRIBUTION.txt`. Binary/manifest files are
   intentionally Git-ignored; redistribute reviewed derivatives with
   proper CC BY-SA licensing/attribution via the build or an approved
   asset distribution channel.
7. The native Swift loader checks version, reviewed flags, both
   model-licence credits, per-part topology and metadata and the
   **actual binary SHA-256**. On failure or missing assets, MagicMirror
   renders its clearly labelled **procedural proxy**, never an
   unreviewed third-party model.

## Data representation

`MMATLAS1` 8-byte ASCII header, 32-bit little-endian unindexed vertex
count, then `vertexCount` groups of six little-endian Float32s:
`position.x/y/z, normal.x/y/z` in imported source FBX world coordinates.
Each manifest part has a contiguous triangle range and reviewed
rest-start/rest-end anchors. Original source hierarchy path and name stay
on each part.

The native renderer uses the observed image joints and approximate model
depth to rigidly orient each reviewed part. This is **not a skinned rig**
or a calibrated camera 3D transform. It can preserve rigid source
geometry, but many anatomical regions need manual attachment and
occlusion/body-space fitting; none are automatically proven by a hash.

## Remaining real-world release gates

- A human reviews the actual full Z-Anatomy/BodyParts3D mesh/source
  licences and author-authored joint bindings.
- An appropriately optimized and reviewed whole atlas is exported,
  bundled, and visibly rendered on iPhone.
- iOS camera/world-body registration, projection, turn/side cases,
  occlusion and reference bone connection are measured on humans.
- Signed iPhone build, offline mode, thermal, performance and TestFlight.
- Diagnostic labels say **illustrative reference, not internal imaging**.

The user chose to defer hardware verification, not to fabricate approval.

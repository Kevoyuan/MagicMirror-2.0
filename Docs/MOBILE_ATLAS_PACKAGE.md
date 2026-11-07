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

## Independent MMATLAS1 package preflight (source implementation)

The offline exporter now **re-opens and verifies its own artifacts** after
writing the binary, manifest, and attribution text. Independently run it
on a developer machine before attempting to include any reviewed model:

```bash
python3 Mobile/iOS/Scripts/verify_atlas_package.py \
  --package /private/reviewed/export
```

This dependency-free check validates the pinned whole-atlas source identity,
the declared licence IDs and attribution, explicit review-flag records,
nonempty modification notes, the expected filename and SHA-256 of the
actual `MMATLAS1` bytes, bounded vertex counts and exact binary length,
unique hierarchy paths, full contiguous triangle coverage, landmark and
rest-anchor shape, finite positions, and nonzero vertex normals.

`python3 -m unittest discover -s Mobile/iOS/Scripts/tests -v`
exercises entirely **synthetic** binary fixtures with intentional corruptions.
The anatomy inventory GitHub Action runs those tests without Blender or a
real licensed mesh. A structurally valid model is **not** human-approved
anatomy, a legal determination, a complete coherent skin/rig, a calibrated
camera-space registration, or a validated iPhone rendering result.

## Six-system offline FBX exporter and audited skin weights

The exporter has been extended beyond the original skeletal prototype
to support six **separate pinned upstream FBX source files** at the same
`6c7f9016...` revision. Each original FBX must be downloaded and
verified by its precise source byte length and Git blob SHA-1 recorded
in `Mobile/iOS/Scripts/atlas_sources.py`. This is source identity,
not permission to redistribute or proof of anatomical accuracy.

| System | Verified upstream FBX |
|---|---|
| skeleton | `SkeletalSystem100.fbx` |
| muscles | `MuscularSystem100.fbx` |
| organs | `VisceralSystem100.fbx` |
| vessels | `CardioVascular41.fbx` |
| nerves | `NervousSystem100.fbx` |
| joints | `Joints100.fbx` |

`LymphoidOrgans100.fbx` is an additional upstream resource but is
**not silently merged** into the visceral-organ package. Such an
aggregation would require its own reviewed source/provenance record.

Example authoring command for a human-reviewed muscular package:

```bash
blender -b --python Mobile/iOS/Scripts/export_full_atlas.py -- \
  --system muscles \
  --fbx /private/z-anatomy/MuscularSystem100.fbx \
  --review /private/muscles.review.json \
  --out /private/magicmirror-reviewed-resources

python3 Mobile/iOS/Scripts/verify_atlas_package.py \
  --system muscles --package /private/magicmirror-reviewed-resources
```

The review JSON requires `anatomicalSystem`, reviewed source
hierarchy/segment anchors for **every source mesh**, nonempty
modification notes and explicit human distribution signoff.
The exporter refuses to rename a skeleton asset as a muscle/organ
asset, rejects FBX byte or blob hash mismatches, and rejects data
over the mobile geometry limit.

**Optional true GPU skinning:** a reviewed derivative mesh may have
authored Blender vertex groups. The author must mark
`reviewedJointWeights: true` and provide a
`vertexGroupToBoneId` map for **each reviewed mesh binding**,
mapping authored Blender group names to independently reviewed
hierarchy bone IDs. Every exported triangle vertex must carry 1–4
nonnegative finite authored weights with sum approximately 1.
No proximity heuristics, guessed anatomical attachments or silent
weight pruning occur. The exporter creates
`<system>_atlas.skinning.json` with four bone IDs/weights per
unindexed vertex and the **exact binary model SHA-256**, in a compact
format within the native 32 MB limit. When the review flag is false,
no skinning sidecar is emitted and the native loader uses the rigid
verified reference mesh if all other gates pass.

The source-built Blender artifacts are only part of the model
package. The author must separately provide a matching reviewed
USDZ hierarchy and its SHA-256-verified
`<system>_atlas_manifest.json` (the skeleton retains
`anatomy_atlas_manifest.json`). A model/weights file alone does
not activate the live 3D anatomical atlas. Any actual packaging and
release still require legal/source review and phone registration.

# Build an approved MMATLAS1 + coherent rig without a duplicate USDZ

MagicMirror's Metal renderer consumes \`*.mmgeom\`. After a human has
reviewed the model, rights and every anatomical mesh-to-rig binding, the
native runtime can now load a hierarchy manifest whose **asset SHA-256
refers to that exact same MMATLAS1 geometry**, instead of requiring an
unused second USDZ binary.

This is an optional alternative to the existing independently authored
USDZ rig workflow; no third-party model or approval record is supplied
in this repository.

## Developer workflow (offline only)

1. Run the reviewed, pinned Z-Anatomy Blender source exporter for one
   anatomical system, such as \`skeleton\` or \`muscles\`, producing
   \`<system>_atlas.mmgeom\` and its SHA-256 manifest. Do not silently
   decimate a source file or guess model identities from mesh filenames.
2. Complete the **private** human review JSON for that system. Its
   \`bindings\` must cover every original source mesh path exactly once
   and include \`boneId\`, \`parentBoneId\` (null for roots), and
   \`anchorsReviewed: true\` for each mesh. Keep the review record private
   until license and anatomy reviewers approve redistribution.
3. The review record must separately assert
   \`reviewedForDistribution\`, \`reviewedJointBindings\`,
   \`reviewedRigHierarchy\`, and \`licenseReviewed\` as \`true\`,
   reflecting actual human signoff rather than automated approval.
4. Run:

   \`\`\`bash
   python3 Mobile/iOS/Scripts/assemble_reviewed_atlas_rig.py \
     --system skeleton \
     --package /private/approved-atlas \
     --review /private/human-reviewed-bindings.json
   \`\`\`

   The tool checks model file/manifest SHA, all triangle spans, source
   revision, reviewed source-hierarchy correspondence, rest-anchor
   consistency, stable unique bone IDs, parents and hierarchy cycles.
   It requires explicit shoulder/hip anchors because the current
   runtime uses them for body-to-atlas similarity registration.
5. It creates \`anatomy_atlas_manifest.json\` for skeleton or
   \`<system>_atlas_manifest.json\` for another separately approved
   system. \`assetFilename\` points to the original
   \`<system>_atlas.mmgeom\` and \`assetSHA256\` is the real binary digest.
   The native runtime verifies the rig manifest and MMATLAS1 SHA, checks
   their hashes agree, and continues to require camera/pose registration.
6. Add the approved package and any separately reviewed
   \`<system>_atlas.skinning.json\` weights to the iOS resource bundle
   **only after legal and anatomy review**.

The standalone script and synthetic tests do not prove model licensing,
mesh anatomy, suitability for medical use, true camera extrinsics, GPU
occlusion or iPhone performance. The app still displays the distinctly
labeled reference proxy without actual approved assets and valid camera
registration.

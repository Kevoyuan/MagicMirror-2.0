# iOS coherent anatomy atlas — offline asset and rigging contract

**Status: mobile source implementation and tests, NOT a shipped licensed atlas.**
The iOS project has an opt-in, validated USDZ manifest reader and pure
reference-pose → current-pose joint-rotation planner. **No whole Z-Anatomy
model has been imported, rigged, attached to Metal, or proven on an iPhone.**

## Intended source, not shipped

- Pinned whole-atlas upstream: LluisV/Z-Anatomy commit
  `6c7f9016bd5899ac8edafd31b9900c151df42ed6`;
  `Resources/Models/FBX/SkeletalSystem100.fbx` (41,339,660 bytes,
  Git blob `7c62e45211bf3992bb7239170343e06e2b073865`).
- Preserve its source geometry and hierarchy. Its original FBX is **not**
  assumed to have a humanoid animation rig, known pivots, a redistributable
  license on every mesh, or legal rights for App Store packaging.
- See `Docs/ASSETS_AND_LICENSES.md` and `Docs/M3_WHOLE_ATLAS_AUDIT.md`
  for licensing, BodyParts3D attribution and overlapping mesh-group risks.

## Development-only conversion, not a phone dependency

1. Independently inspect each included geometry's redistribution rights,
   source revision, author attribution and required share-alike terms.
2. Acquire the **one original full FBX** outside the app (never ship a
   split-pieces imitation of the atlas). Review its hierarchy and identify
   true bone centers / proximal / distal anchors from the mesh.
3. Produce a coherent, mobile-optimized **USDZ** model with stable named
   nodes, compatible rest transforms, reduced material/draw-call cost and
   measured vertex count. Conversion may use a desktop tool during **build**,
   but the installed phone uses **no** Unity, Python or desktop companion.
4. Write `anatomy_atlas_manifest.json` conforming to
   `AnatomyAtlasManifest.swift`: source revision/URL, attribution,
   licenseIdentifier, bundled USDZ filename and computed **SHA-256**.
   Mark `licenseReviewed`, `anatomyReviewed` and each
   `anchorsReviewed` **true only after human verification**. Use the
   example template at `Docs/examples/mobile-anatomy-atlas.json` as a
   deliberately **invalid** starting point, not a release candidate.
5. Bundle the approved USDZ + manifest **only after clearance**. The
   loader checks manifest validity and actual asset hash at runtime and
   never silently downloads a model. A checked hash proves byte identity,
   **not** legal rights or anatomy correctness.
6. Map each named rig node's reviewed local pivot/rest axis to its
   MediaPipe proximal/distal landmark indices; audit hierarchy, duplicate
   paths, cycles and unsupported geometry. Keep the whole model spatially
   coherent, rather than animating unrelated extracted object files.

## iOS reference pose → motion contract

- `AnatomyReferenceCapture.swift`: acquire at least 12 stable 3D
  world-landmark observations, median-filter the reference pose and freeze
  it until capture-session reset. The threshold and frame count are
  engineering defaults, **not measured performance**.
- `AnatomyMotionPlanner.swift`: compare the reference and live limb
  directions for each **reviewed** source binding, calculate a normalized
  3D relative quaternion, carry rest length and confidence forward.
  Unreviewed, low-confidence or missing 3D values produce **no motion
  commands**, not made-up bone positions.
- These are purely *relative joint rotation requests*. They are not
  complete camera/body extrinsics, physical bone center estimates, joint
  contact constraints, skinned USDZ animation or AR projection.
- A future mobile rig runtime must map **relative rotations into the
  atlas's reviewed local coordinate system**, respect hierarchy and
  parent transform effects, and use a separately calibrated body-to-camera
  transform. Do not apply source-world quaternions directly to arbitrary
  USDZ nodes and call the result anatomically correct.

## Tests and release gates

The added XCTest source covers manifest review flags, hierarchy cycles,
duplicate IDs/paths, unsafe asset filenames, invalid pivots, reference
capture/loss and synthetic 3D rotation commands. Xcode compile checks
validate the code signatures; this is **not** a Unity Editor or hardware
test. Still pending before a real release: independently reviewed
third-party license, correct full atlas, actual rig/skin binding,
accurate camera-space projection, partial-occlusion strategy, 30 FPS,
device thermal tests, accessibility and App Store notices.

Never label the proxy Metal cylinders or these synthetic test vectors as
individual real human bones or a medical image.

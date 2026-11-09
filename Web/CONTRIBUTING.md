# Contributing to MagicMirror Web

This repository's **active product** is the open-source Web camera
and 3D educational anatomy experience. Native SwiftUI/Metal iOS
and previous Unity/Python are preserved research, **not** active
feature targets. Android native is canceled.

## First contribution

1. Read `AGENTS.md`, `Docs/ADR-003_WEB_OPEN_SOURCE_FIRST.md`,
   `Docs/WEB_MVP_ROADMAP.md`, `Web/README.md`.
2. Use Node.js 22+ and run:
   ```bash
   cd Web
   npm install
   npm run stage:assets
   npm run typecheck
   npm test
   npm run build:code
   npm run dev
   ```
3. Browser webcam access requires localhost/HTTPS. Try a computer
   webcam and mobile Safari/Chrome when you can. **Never** publish
   the CI-only `build:code` output as a licensed working site.
4. For feature PRs supply a short reproducible browser/test matrix,
   capture device/browser name and evidence of permission,
   orientation, mirroring, partial pose, tracking loss and recovery.
   Synthetic unit tests and CI compilation do not replace those.
5. Make PRs small, update docs and add deterministic regression
   tests to `Web/src/*.test.ts`.

## Licensing and privacy

- Newly authored `Web/` code is MIT per `Web/LICENSE`.
  Google MediaPipe SDK and its separately hosted `.task` weights
  **do not become MIT** merely because the app is open source.
- **Do not commit original or derived Z-Anatomy/BodyParts3D models**
  (FBX, OBJ, GLB, GLTF, USDZ etc), original unknown assets, copied
  educational texts, Google model weights or developer camera frames
  without documented appropriate owner rights and notices.
- The local FBX/GLB viewer reads **only user-chosen local files**
  and is not a distribution approval. Real atlas shipping needs
  per-mesh review, compatible CC/NC treatment and actual rig/AR
  evidence. Keep `Web/release-clearance.json` blocked until
  genuine third-party rights/SDK privacy review.
- Never add default camera recording, data uploads, account
  tracking, third-party analytics or translation APIs without an
  explicit privacy/product decision.

## Claim accurately

"MediaPipe 33-point estimate", "procedural 3D proxy",
"model-space static slicing", "local delivery time" are accurate.
"Actual user bones", "X-ray", "medical diagnosis", "verified
Z-Anatomy AR" or "real display FPS" are **not** justified by
the present Web product. If actual source rights or a browser
test are unavailable, describe the blocker and keep the
feature disabled.

## Local atlas inventory and evidence standards

Use the source-part hierarchy and JSON inventory as a private
working input to **human original-mesh** author/license/rig
review. It is **never** permission to bundle or relicense a
model. Source mesh names may contain personal/company data:
do not commit exported JSON or private evidence unless
origin and distribution rights were checked. Keep original
source identifiers intact in notes. Use `textContent` for
user-imported labels and prevent model texture URLs from
creating unsolicited remote network fetches.

## Rig and animation claims

Only report joint/weight counts actually found in the imported
model's `SkinnedMesh` and `skinWeight/skinIndex`.
Sampling is intentionally limited, and imported animations
are preview-only, unrelated to observed MediaPipe person
tracking. Every local source inventory must retain
`rightsStatus=NOT_REVIEWED`. Never treat a valid clip or
well-formed joint as evidence that the author approved
redistribution of the geometry.

## W2d rig-mapping drafts are NOT rights or animation approvals

Human-entered per-mesh `PoseSegmentId` assignments are
bound to exact original model SHA-256, byte size and real
mesh identity. Preserve the source fields and FAIL CLOSED
on all unknown/forged license/retargeting states. Never
automatically classify source mesh names as bones, assign
skin weights, or activate real camera anatomy AR based only
on a matching JSON. A matching original source and draft
are still **not** a legal redistribution grant, calibrated
rest pose or authored animation rig.

## Local source-point drafts are not verified joint anchors

The source-raycast points in W2e originate from an
explicit user selection on the SAME locally loaded
original mesh. Validate the exact source SHA-256
and current W2d manual segment relation before
import, and preserve uncalibrated/not-ready/not-
reviewed statuses. Do not infer 3D human joints,
verified bone anatomy, authored skin weights,
rest pose or commercial rights from these
arbitrary local reference points. No unreviewed
model asset or source-rig file goes into Git.

## W2f rigid-preview safety contract

Any new feature built on original-mesh W2f motion
must preserve exact reset to source mesh matrices
and reject source `SkinnedMesh` and authored clips.
The source file and vertices must remain unmodified.
A/B are human-clicked, **not** joint ground truth,
and X/Y/Z axes are original model axes, **not**
anatomically verified flexion or extension. Avoid
claims of live patient skeleton alignment; keep
rig/rights/SDK gates unapproved until verified
separately. Require synthetic matrix no-drift tests
plus real browser functional inspection.


## W2g source-chain review standard

Manual parent links describe a LOCAL virtual hierarchy,
not an anatomical joint tree. Keep `MAX_STUDY_CHAIN_MESHES=12`,
source-root pivot math and cycle/angle validation tested.
Render temporary ghost meshes separately from the imported
hierarchy, reusing source geometry ONLY while the original
viewer owns it. Always release ghost objects without
disposing shared geometry; preserve exact original source
matrices, source labels and authored animation clips.
No live camera retargeting or public anatomy rights is
approved by synthetic graph tests alone.

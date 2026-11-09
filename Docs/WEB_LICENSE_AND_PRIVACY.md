# Web open-source scope, anatomy rights and SDK privacy

This is an engineering checklist, not a legal opinion.

## Open code is not open third-party artwork

The newly authored TypeScript/CSS/Web tooling is licensed under
[Web/LICENSE](../Web/LICENSE) (MIT). That does NOT change the rights
to existing iOS, Unity, Python historical files or any third-party
model binaries. A root-wide open-source license would require an
independent authorship/ownership audit of those historic contributions.

The W0 Web prototype shows **original illustrated 3D cylinders and
spheres only**. It does NOT copy Z-Anatomy/BodyParts3D geometries.
Z-Anatomy is typically CC BY-SA 4.0 for many files, but includes
third-party components with NC terms; every actually incorporated
part needs independently grounded source/author/license review.
ShareAlike for model derivatives is a separate obligation and does
not automatically force independently authored app code open under
CC BY-SA; nor does merely open-sourcing Web code cure an NC problem.

## Separate Google model weights from SDK

`@mediapipe/tasks-vision@1.2.2` is an Apache-2.0 SDK, but separately
hosted `pose_landmarker_lite.task` weights may have their own use and
redistribution terms. Exact bytes are developer-stage-verified, not
equivalent to an actual legal grant. Do not publicly ship the staged
`.task` until those permissions are documented.

The current MediaPipe Tasks npm package privacy notice (last modified
June 2026) states that input images/audio/text are processed on the
device, but APIs **send performance and utilization metrics to Google**,
and implementers may have user-consent obligations. MagicMirror's own
code does not POST frames or save image data. Before a public site,
audit SDK network behavior, disclose any metrics collection and consent
appropriately under applicable law; don't claim "zero network calls".

Developer pages can fetch Google WASM/model binary only at staging
time; no remote inference API. Public static hosting requires HTTPS
for browser camera permission, apart from localhost secure contexts.

## Release stops

`Web/release-clearance.json` is deliberately FALSE. The normal
`npm run build` must check assets AND independent legal/SDK/privacy
review. `npm run build:code` used in CI only verifies source quality;
its unbundled model output must not be deployed as a fully working
site.

References:
- [Web MediaPipe Pose Landmarker](https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker/web_js)
- [MediaPipe npm SDK and privacy notice](https://www.npmjs.com/package/@mediapipe/tasks-vision)
- [MDN getUserMedia secure contexts](https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia)
- [Z-Anatomy upstream](https://github.com/Z-Anatomy/Models-of-human-anatomy)
- [CC BY-SA 4.0 terms](https://creativecommons.org/licenses/by-sa/4.0/)

## W1 opt-in local export (2026-11-09)

The Web UI provides **one explicit user-triggered PNG download**.
Camera frames, canvas data and pose observations remain in the
browser; the application itself has no recording, automatic saving,
analytics or upload endpoint. Downloaded files are subsequently
managed by the user's browser/device. Google MediaPipe SDK network
metrics obligations remain a distinct public-release review topic.

## User-chosen local anatomy models (W2a)

The browser File API is used only after a user picks a local FBX
or GLB. The app parses it in memory and deliberately prevents
model-provided external resource URLs from fetching third-party
texture files. The static inspector stops the active camera while
the dialog is open. No model geometry or file data is sent to
a server by the MagicMirror source and nothing is automatically
written to disk. These are privacy protections, NOT a source
license, authorization to redistribute or a guarantee about
malicious browsers/third-party extensions.

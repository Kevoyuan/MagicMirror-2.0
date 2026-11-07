# MagicMirror 2.0

**An offline-first, native anatomical AR mirror for iPhone (iOS).**

Point your phone camera at one person and explore a translucent, educational **reference skeleton** that follows observed movement. MagicMirror aims to make human anatomy intuitive through motion—not simulate an X-ray, scan anyone's actual bones, or diagnose a medical condition.

> **Development status · November 2026:** The active product is an **iPhone/iOS prototype**, not a released app. Source builds and XCTest targets compile in GitHub Actions for arm64 iOS Simulator. A physical iPhone camera experience, measured latency, a licensed and reviewed full anatomy atlas, and production distribution **have not yet been validated**. **Android development has been canceled and is not part of the product roadmap.**

[Native iOS guide](Mobile/iOS/README.md) · [Product design](DESIGN.md) · [Active roadmap](Docs/MOBILE_NATIVE_ROADMAP.md) · [Architecture decision](Docs/ADR-002_MOBILE_NATIVE_OFFLINE_FIRST.md)

## Why MagicMirror?

Instead of a character-replacement social filter, MagicMirror is designed as an **interactive anatomy learning tool**. The camera remains the main canvas while a transparent anatomical reference follows body motion. Planned educational layers can let you inspect skeletal regions, then eventually muscles and organs—only after verified assets and layer alignment exist.

The intended experience is **open app → allow camera → point at a person → see a reference overlay → explore**, with no account, external camera, desktop companion, Python server, Unity runtime, wearable sensor, or cloud inference.

## What's implemented today (iOS source)

| Area | Current implementation | Important limitation |
| --- | --- | --- |
| Camera and tracking | SwiftUI, AVFoundation rear camera, on-device MediaPipe Tasks Pose Landmarker and 33 estimated landmarks | Single-person prototype; physical device accuracy unverified |
| Partial-body detection | Confidence-gated arm/leg segments can appear without an entire body in view; separate partial vs torso-anchored tracking | Missing joints are **not** hallucinated; atlas registration needs reliable shoulder/hip anchors |
| Live overlay | Native Metal translucent **3D procedural proxy** for limbs, plus stylized ribs, pelvis, and cranium where anchors allow | Illustrative shapes, **not** measured internal anatomy |
| Frame association | Pose results matched to their exact capture timestamps and bounded source-video buffers for camera/Metal compositing | Timestamp consistency alone does not prove low camera-to-display latency |
| Display controls | One-screen camera view, Whole / Arms / Legs focus, opacity, pause overlay, context guidance | Expanded anatomy-layer interface remains a **design proposal** |
| Local diagnostics | Optional POSE FPS and p95 callback-gap HUD, hidden by default | Not camera FPS, display FPS, or motion-to-photon latency |
| Atlas groundwork | Local asset manifests and hash/license gates, reference capture, coherent parent-child 3D rig planning, reviewed camera projection contract, weak-perspective same-frame research fit | No approved Z-Anatomy atlas bundled, no proven skinned/animated full anatomy on an iPhone |

The app processes camera and pose data on device. Model/package downloads are **development-time** steps; the installed prototype is designed not to upload camera frames.

## Architecture

```text
                         iPhone rear camera (AVFoundation)
                                      |
                         timestamped source frame
                                      |
                         MediaPipe Pose Landmarker
                        (on-device, 33 estimated points)
                                      |
                      visibility / confidence / time gates
                                      |
                      +---------------+---------------+
                      |                               |
              Partial observed pose             Torso-anchored pose
                      |                               |
              Procedural limb proxy          Proxy + optional reviewed
                      |                       atlas research pipeline
                      +---------------+---------------+
                                      |
                    matched camera frame + Metal overlay
                                      |
                       SwiftUI camera / focus / opacity
                           + optional local diagnostics
```

**Atlas research paths are intentionally distinct:** the reviewed hierarchy / bone-length-preserving rig and camera-projection contracts are not equivalent to the optional weak-perspective fitting experiment. Their source components do **not** mean a complete skinned Z-Anatomy character is currently running in the app. Invalid or insufficient calibration must fail closed rather than display confident-looking but unsupported anatomy.

See the [iOS implementation guide](Mobile/iOS/README.md), [hierarchical rig contract](Docs/IOS_HIERARCHICAL_ATLAS_RIG.md), [weak-perspective research note](Docs/MOBILE_CAMERA_WEAK_PERSPECTIVE.md), and [local diagnostics specification](Docs/IOS_LOCAL_POSE_DIAGNOSTICS.md).

## Build the iOS prototype

**Developer requirements:** macOS, Xcode 16+, XcodeGen (`brew install xcodegen`), and an iPhone with iOS 17+ plus Apple signing for on-device installation.

From the repository root:

```bash
bash Mobile/iOS/Scripts/fetch_model.sh
cd Mobile/iOS
xcodegen generate --spec project.yml
open MagicMirror.xcodeproj
```

In Xcode, select the **MagicMirror** scheme, configure your Signing Team, choose your iPhone and run. Grant camera access. Point the **rear camera** toward one person: a confident observed limb can enable partial tracking; shoulders and hips provide the stronger torso anchor for complete-reference work.

To **compile** the app and XCTest target for a Simulator (without a real camera):

```bash
xcodebuild -project MagicMirror.xcodeproj -scheme MagicMirror \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build-for-testing
```

A successful `build-for-testing` compiles tests; it does **not** mean that XCTest ran on a device or that the overlay is visually aligned in live capture. The pinned MediaPipe package and pose model are acquired during developer setup, not by the installed app.

## Visual direction: Leonardo's anatomical notebook

[DESIGN.md](DESIGN.md) records the selected **Leonardo / anatomical field journal** direction: restrained parchment and sepia details, verdigris accents, a **small top status strip** and a compact bottom dock so the live camera occupies most of the display. A layered Z-Anatomy explorer (bone / muscle / organ / section views) is a **future UI concept**, not a shipped capability.

The initial focus modes are **Whole / Arms / Legs**. Do not confuse these working controls with fully implemented anatomical layers.

## Next release blockers

1. **Physical iPhone validation:** actual rear-camera tracking, occlusion and turning, overlay placement, sustained FPS, power, thermal behavior and end-to-end latency.
2. **Atlas review and integration:** source-model distribution rights, attribution, reviewed bone anchors, hierarchy/skinning, and real mesh-to-renderer integration. No model should appear as a verified human bone atlas before this review.
3. **Camera/body registration:** independently measured or validated camera geometry and a reliable pose-to-image alignment quality gate; handle facing direction and incomplete pose safely.
4. **Shipping readiness:** accessibility and on-device UX QA, signing, privacy review, TestFlight and release acceptance. There is no planned Android release.

Follow [MOBILE_NATIVE_ROADMAP.md](Docs/MOBILE_NATIVE_ROADMAP.md) for the authoritative active plan. Historical desktop milestones are **not** the mobile release checklist.

## Previous Unity / Python research (archived)

The repository retains prior desktop experiments: a Python MediaPipe pose sidecar, timestamped pose/video contracts, Unity visualization, and C# anatomy-registration / kinematics tests. They are **research and regression references only**. They are **not dependencies** of the native mobile app, and no Windows/macOS product is planned.

- [Archived architecture](Docs/ARCHITECTURE.md) · [desktop research roadmap](Docs/ROADMAP.md)
- [Desktop Unity validation notes](Docs/UNITY_RUNTIME_VALIDATION.md)
- [Python pose sidecar tests](Tools/pose_sidecar/tests) · [C# kinematics checks](Tools/ci/csharp_kinematics)
- [Assets and licensing](Docs/ASSETS_AND_LICENSES.md) · [Notices](NOTICE.md)

## Scientific and licensing disclaimer

MagicMirror visualizes a **standard educational reference**, not an individual's internal anatomy. A single RGB camera cannot see actual bones or organs. The procedural proxy and estimated MediaPipe world points are not medical measurements, calibrated depth, X-ray, CT, MRI, or clinical diagnostics.

**No reviewed Z-Anatomy / BodyParts3D anatomical asset is distributed with the iOS prototype.** Verify source-specific licenses and attribution before packaging derivatives. Do not assume the repository's *code* has an open-source license unless the owner adds an explicit LICENSE.

## Live IK reference proxy (native iOS source)

The iPhone camera-to-Metal source path now integrates stable
on-device body-world reference capture with fixed-length, two-bone IK
for confidently observed arms and legs. The renderer uses the resulting
per-frame, geometry-only reference pose only when it matches the
actual source video timestamp and dimensions; otherwise it keeps the
existing partial-body procedural fallback. This does **not** unlock
licensed Z-Anatomy, calibrate camera extrinsics or prove performance
on a real iPhone. See the [iOS guide](Mobile/iOS/README.md).

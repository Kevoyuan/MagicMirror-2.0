# MagicMirror iOS — App Store/TestFlight preparation (source-only)

MagicMirror uses one on-device camera stream, local MediaPipe Tasks inference,
a verified model bundled during developer build preparation, and native
Metal rendering. This app **does not collect, upload or store camera frames**
in its current source code and contains no account or advertising analytics.

- `Mobile/iOS/Resources/PrivacyInfo.xcprivacy` declares no tracking and no
  data collected by **MagicMirror's own implementation**. Review privacy
  manifests and required-reason APIs of the **actual resolved MediaPipe SDK**
  and other transitive libraries before App Store upload; this file alone
  does not certify full Apple privacy compliance.
- App obtains camera permission using `NSCameraUsageDescription`, already
  provided in `project.yml`.
- `CameraPosePipeline` now listens for capture-session interruption, ended
  interruption and runtime errors, resets the pose frame-association gate
  and hides stale skeleton mesh while the camera is unavailable. Source
  behavior is not a real iPhone interruption test.
- Pause disables overlays, not the camera itself; backgrounding stops the
  capture session using `MirrorScreen` scene-phase lifecycle hooks.
- Review Z-Anatomy/BodyParts3D and model-derived CC BY-SA attributions
  separately. Do not ship the full original FBX or claim clinical imaging.
- Make icon screenshots, localized App Store copy, accessibility review,
  signed release archive, TestFlight access, offline airplane-mode checks,
  memory, frame pacing, 10-minute thermal/battery and camera privacy tests
  on real supported iPhone hardware before publishing.

Required developer steps once hardware and Apple account are available:

1. Install Xcode and XcodeGen; provision an Apple development team ID.
2. Generate the Xcode project from `Mobile/iOS/project.yml` and
   package the SHA-pinned local MediaPipe model.
3. Open the target in Xcode, configure bundle identifier, signing,
   deployment target, icons, app metadata and physical device.
4. Run an actual live person pose, interruption, resume, opacity and
   screenshot capture; verify overlay registration rather than just dots.
5. Audit generated privacy report and third-party SDK model licences.
6. Archive for an iOS device and submit using Xcode Organizer / App Store
   Connect; run TestFlight external review and privacy questionnaire.

**Not completed:** approved anatomy atlas, physically proven alignment,
signed IPA/TestFlight deployment and App Store review. The user requested
continued implementation before hardware validation, not a false green gate.

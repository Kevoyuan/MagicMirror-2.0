# MagicMirror 2.0 — paid iOS App Store release policy

**Decision (2026-11-08): MagicMirror is intended to be a PAID
iPhone app.** Its own original SwiftUI/Metal code and product design
can be monetized. This policy is an engineering/release gate, **not a
legal opinion** and not confirmation that any third-party asset has
been licensed for commercial distribution.

## Non-negotiable commercial asset strategy

**Preferred production path: create original human-reviewed, animated
reference anatomy or commission a new model with independently
documented broad commercial rights.** The anatomical appearance and
technique may be informed by general scientific facts, but **do not
copy copyrighted Z-Anatomy/BodyParts3D meshes, exported derivatives,
textures, definitions or rig geometry** into the commercial deliverable
without a source-specific appropriate written grant.

**Research-only:** Z-Anatomy, BodyParts3D, LluisV original FBX files
and all prior adapted geometry; never include them in App Store
screenshots/videos/binaries until individually cleared. Git-ignore
does NOT stop XcodeGen from copying local `Resources/` binaries into
an installed App.

**CC BY-SA is not a general ban on charging.** It allows commerce,
but obliges attribution/share-alike, permits downstream reuse, and
forbids additional restrictions such as effective DRM on licensed
content. Apple may apply protections to an App Store package. An
App-Store-compatible separate written permission or a distribution
strategy validated by an intellectual property lawyer may be needed.
This project deliberately **does not auto-clear ordinary CC BY-SA**
assets for a paid packaged app. It permits **either** a source-specific
written grant **or** the owner-selected separately published CC BY-SA
model-only path, but the latter still needs real original-component
rights review and independent App Store distribution/DRM compatibility
assessment before an actual paid Release.

**NC / NC-SA / ND / unclear:** never include in the paid build on a
Creative Commons basis. A signed separate commercial permission
must cover the **actual owner of every incorporated component**;
a Z-Anatomy project-level message cannot waive rights held by third
parties. Rebuilding from an NC mesh using different file extensions
does not cure the license issue.

**Historical version trap:** The current BodyParts3D license page
states **CC BY 4.0** (updated in 2025) while archived dataset versions
and Z-Anatomy derivative notices cite **CC BY-SA 2.1 Japan**. They
refer to different distributions/versions; do **not** silently apply
the current website's terms to the exact pinned historic mesh. Review
the actual source bytes and chain of rights.

Sources, to verify near each launch:
- Apple App Review [§5.2 intellectual property](https://developer.apple.com/app-store/review/guidelines/#intellectual-property)
- [Creative Commons CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)
- [Creative Commons FAQ on technical DRM restrictions](https://creativecommons.org/faq/)
- [Z-Anatomy original license with third-party exceptions](https://github.com/Z-Anatomy/Models-of-human-anatomy/blob/master/License.txt)
- [Current BodyParts3D license](https://dbarchive.biosciencedbc.jp/en/bodyparts3d/lic.html)
- [Archived BodyParts3D release terms](https://dbarchive.biosciencedbc.jp/data/bodyparts3d/20110915/README_e.html)

## Additional independent dependency: PoseLandmarker model WEIGHTS

The iOS app uses `MediaPipeTasksVision`, pinned at Git revision
`2df17d66d380f74884c1505a7e7ac677020c3980`. The SDK
repository is generally under **Apache-2.0**. This DOES NOT prove
that a separately hosted `pose_landmarker_lite.task` binary is licensed
under Apache-2.0. Its current checksum is
`59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a`.
Acquire actual model-weight commercial redistribution terms or
replace it with commercially cleared, equivalent on-device weights.
Record the written evidence, source and specific SHA-256 separately.

Review the pinned SDK's complete transitive notices and privacy
manifests. Google's MediaPipe Tasks documentation discusses possible
performance/utilization metric processing; do **not** assume identical
behavior for each iOS build without independent offline/network
testing and privacy disclosure review. Model *source*, SDK *code*,
App *privacy* and product *claims* are separate gates.

## Implemented technical safeguards

`Mobile/iOS/project.yml` adds two scripts to the native
`MagicMirror` app target:
1. **Before Release build:** `paid_release_gate.py --mode release`
   checks a commercial ledger and every staged model byte. With the
   current `releaseApproved: false`, Release/Archive **fails
   intentionally**. Debug stays available for research and UI work.
2. **After Release build:** `--mode bundle --bundle <actual .app>`
   enumerates the build product for model/atlas binaries, rejects
   unexpected files, verifies exact declared SHA256 bytes and checks
   the hash of bundled `ThirdPartyNotices.txt`.

CI also runs `--mode source` on the checkout to stop accidentally
committed unreviewed binary anatomy. The script scans common geometry
and model extensions (`*.usdz`, `*.mmgeom`, `*.fbx`, `*.glb`,
`*.task`, `*.onnx`, skinning/manifests, etc.). It cannot detect
mislabelled/encrypted binaries or determine the legal authenticity
of a supplied document. Human signoff, actual App Store `.ipa`
inspection and branch/release protection remain mandatory.

Commands:

```bash
# Review developer resource state. PASS is NOT release approval.
python3 Mobile/iOS/Scripts/paid_release_gate.py --mode source

# Deliberately FAILS today because the rights ledger is NOT cleared.
python3 Mobile/iOS/Scripts/paid_release_gate.py --mode release

# When a signed/reviewed clearance actually exists:
python3 Mobile/iOS/Scripts/paid_release_gate.py \
  --mode bundle --bundle "/path/to/MagicMirror.app"

# Repeatable synthetic adversarial checks (NO actual license evidence):
python3 -m unittest discover -s Mobile/iOS/Scripts/tests -v
```

### Commercial clearance file

`Mobile/iOS/CommercialRelease/paid-app-clearance.json` is
deliberately unapproved. Each actual release candidate requires:

- **Named/date-stamped independent approval**, distribution area,
  evidence reference to real written licenses/assignments retained
  privately, and specific paid App Store / DRM review.
- **Each binary**: full relative bundle path, real SHA-256, original
  rightsholder, source/version, accurate attribution, commercial use,
  distribution and technical protection scope, plus documentary grant.
- **Third-party assets**: full upstream license chain, and a separate
  written grant for restricted/ShareAlike source material if used.
  Third-party anatomy requires a per-original-mesh rights audit and
  anatomical review of rig and final derived output.
- **Third-party runtime SDKs**: pinned revision, actual notices,
  dependency redistribution review, privacy disclosure.
- **Bundled ThirdPartyNotices.txt** with reviewed exact SHA-256.
  These notices must not be invented merely to make the gate pass.

Do not commit private contracts or personal/legal secrets to the public
repo; retain actual signed agreements securely and reference an
internal document ID/hash. Boolean flags and hashes are assertions,
**not proof of permission**.

## Commercial launch checklist — actual non-code release gates

- [ ] Choose the model commercial rights path and independently verify
      actual source geometry and license chain, not only attribution.
- [ ] Obtain lawyer-reviewed written commercial rights for **every**
      non-original anatomical/model component, including source weights.
- [ ] Obtain signed anatomical 3D deliverable (armature/weights, mobile
      LOD, source scene, audit records) under a suitable written grant.
- [ ] Audit MediaPipe SDK, exact `.task` weights, transitive licenses
      and all required notices.
- [ ] Finalize camera privacy disclosures; verify SDK network behavior
      and `PrivacyInfo.xcprivacy` on device in airplane mode.
- [ ] Have a lawyer review App Store DRM/CC compatibility, where relevant;
      no claim of a universal free exception.
- [ ] Audit product names/trademarks, icons, screenshots and marketing:
      call it an **illustrative reference**, not true X-ray or internal
      diagnostic imaging.
- [ ] Validate true skeletal 3D alignment, source matching, occlusion,
      physical iPhone performance and crash recovery before taking money.
- [ ] If offering premium digital features or subscriptions inside an
      app, implement Apple's required In-App Purchase flow and current
      price/renewal/cancellation disclosures. Paid upfront download is
      also a business option, but Apple review/payment rules still apply.
- [ ] Perform final archive/`.app` or `.ipa` asset inspection on
      the **exact uploaded build**, not only a local Debug build.
- [ ] Document/review all approvals on the final release commit,
      protect release branches and obtain written human ship signoff.

Nothing here eliminates all IP/privacy/commercial legal risk; it
ensures that **no unreviewed asset is silently treated as cleared**
through the standard XcodeGen paid Release path.

**Do NOT mark `releaseApproved` true or commit source assets merely
to make CI green. The paid product is still under development.**


## Official DBCLS BodyParts3D 4.0 as an alternative model source

There is a promising **lower-cost** route to legitimate anatomy geometry:
obtain the `isa_BP3D_4.0_obj_99.zip` / `partof_BP3D_4.0_obj_99.zip`
OBJ archives **directly** from the official DBCLS archive, which
currently publishes the database under **CC BY 4.0**. It does not have
the automatic ShareAlike requirement of a Z-Anatomy derivative, but
**CC BY 4.0 also contains a no-additional-effective-technical-restrictions
clause**. The exact source and Apple App Store/DRM distribution still
need independent review, required attribution and a documented lawful
distribution plan. This repository intentionally still blocks ordinary
CC BY-tagged third-party anatomical binaries from paid Release by default.

Never acquire a third-party *adapted* BodyParts3D model and label it
as direct original DBCLS model. The new route needs its own verified
archive/hash, source-specific geometry import, human-reviewed rig/weights
and mobile pipeline; no actual OBJ has yet been imported or granted
release clearance.

Compare the choices: `Docs/PAID_ANATOMY_MODEL_SOURCE_OPTIONS.md`.

## Alternative: PAID closed-source app + separately published CC BY-SA anatomy

**Owner-selected plan (2026-11-08):** if the *exact included* skeletal
parts are genuinely CC BY-SA 4.0 or compatible (and have no additional
NC/ND/unknown rights), a separate individual copyright grant from
Z-Anatomy authors may not be required. A CC public license already
permits commercial use; payment for the **app** and independent
licensing of adapted **model geometry** are different questions.
Whether the combination is legally separable and App Store DRM
compliant remains a matter for competent independent IP review.

This path is **an alternative, not a replacement**, for the original
written commercial grant path. The release gate now accepts
`rightsBasis: "cc-by-sa-public-license"` **only for named, reviewed
anatomy model + manifest + (where relevant) skinning files**.
Every original source mesh must carry a human-reviewed origin, real
HTTPS license evidence, attribution, original identity and confirmed
commercial reuse. NC/NC-SA/ND/unknown components cannot be converted
to BY-SA merely by exporting or relabelling files.

**Actionable process:**

1. Obtain the pinned *source* skeletal FBX for research; run the
   actual source inventory from Draft PR #51. Independently inspect
   **all actual incorporated original mesh sources**, including
   inherited third-party works. The base FBX has 1,952 source meshes,
   no existing skin weights, and is not yet a mobile rig.
2. Complete genuine rights-chain and human anatomical/rig audits.
   Keep the source review file and evidence; the source review per
   mesh will be embedded into the actual exported atlas manifest.
3. Prepare exact authored `skeleton_atlas.mmgeom`, matching
   `skeleton_atlas.manifest.json`, and reviewed skinning sidecar
   (if shipped), plus detailed credits and human modification log.
4. Generate a model-only, distributable ZIP and usable OBJ that anyone
   may reuse under CC BY-SA 4.0:
   ```bash
   python3 Mobile/iOS/Scripts/sharealike_publication.py \
     --model /private/reviewed/skeleton_atlas.mmgeom \
     --manifest /private/reviewed/skeleton_atlas.manifest.json \
     --skinning /private/reviewed/skeleton_atlas.skinning.json \
     --attribution /private/reviewed/ATTRIBUTION.md \
     --modifications /private/reviewed/MODIFICATIONS.md \
     --output Mobile/iOS/CommercialRelease/PublishedPacks/skeleton-open-v1.zip
   ```
   Omit `--skinning` only if the shipped model has no skinning
   sidecar. No original FBX, proprietary app source code or third-party
   PoseLandmarker weights are included in this model-only ZIP.
5. Publish the **exact generated ZIP** at a persistent public HTTPS
   direct download, usable without login, payment, DRM or app purchase.
   This is a **necessary** practical step, NOT sufficient proof that
   Apple imposes no prohibited effective technical measures on the
   app-bundled model.
6. Obtain independent legal review of the full original mesh rights
   chain and **actual** Apple App Store/DRM distribution conditions.
   Record source evidence and verified availability/date/URL/ZIP
   digest in `CommercialRelease/paid-app-clearance.json`;
   use the same `shareAlikePublicationId` for each model,
   manifest and skinning asset ledger row.
7. After signed real review, stage source citations and the public
   download link into the app's Field Notes:
   ```bash
   python3 Mobile/iOS/Scripts/stage_cc_model_attribution.py
   ```
   It writes `Resources/CCModelAttribution.json`, which is required
   to **exactly** match the human-approved public URL and ZIP SHA.
8. Run paid Release build and inspect the exact exported `.app` /
   signed archive. The existing gate checks original model SHA-256,
   per-mesh review, public archive exact bytes, readable OBJ,
   license/credits/modifications, SDK weights rights, and in-app
   public link identity. All are still subject to real human review.

**Today**: `releaseApproved: false`, no reviewed public model package,
no model download URL, no independent DRM clearance; Release remains
**intentionally blocked**. Debug research, original UI and procedural
proxy continue. This route does not by itself finish bone rigging,
registration, hardware testing or a lawful App Store launch.

using System;
using System.Collections.Generic;
using MagicMirror.Anatomy;
using MagicMirror.Tracking;
using UnityEngine;

namespace MagicMirror.Motion
{
    /// <summary>
    /// Drives a SINGLE intact anatomical atlas prefab, preserving original
    /// source mesh geometry, local coordinates and hierarchy.
    ///
    /// Selected rigid mesh renderers receive transforms computed from the
    /// source/rest pose, never accumulated previous-frame rotations.
    /// Unmapped atlas renderers follow the calibrated whole-body root only.
    ///
    /// Full-body 2D screen-plane demonstration, NOT 3D anatomy scanning.
    /// </summary>
    public enum FullBodyViewMode { FullBody, UpperBody, ArmsOnly, LegsOnly }

    public sealed class FullBodyAtlasRetargeter : MonoBehaviour
    {
        private const int AnatomyLayer = 30;

        [SerializeField] private PoseStreamReceiver poseSource;
        [SerializeField] private Camera anatomyCamera;
        [SerializeField] private FullBodyAtlasProfile profile;
        [SerializeField, Range(0.1f, 1f)] private float confidenceThreshold = 0.40f;
        [SerializeField, Min(0.1f)] private float projectedDepth = 2f;
        [SerializeField, Min(0.1f)] private float staleAfterSeconds = 0.75f;
        [Header("Pose stabilization (image-space, not clinical measurements)")]
        [SerializeField, Range(0.01f, 0.5f)] private float poseHalfLifeSeconds = 0.09f;
        [SerializeField, Range(0f, 0.6f)] private float dropoutGraceSeconds = 0.22f;
        [SerializeField, Range(0.03f, 0.9f)] private float maxNormalizedJump = 0.23f;

        private sealed class MovingMesh
        {
            public Transform transform;
            public FullBodyAtlasProfile.MotionGroup group;
            public Vector3 originalLocalPosition;
            public Quaternion originalLocalRotation;
            public Vector3 originalLocalScale;
            public Vector3 neutralAtlasPosition;
            public Quaternion neutralAtlasRotation;
            public int hierarchyDepth;
            public Vector3 computedPosition;
            public Quaternion computedRotation;
            public bool hasComputedPose;
        }

        private GameObject atlasContainer;
        private Transform atlasRoot;
        private readonly List<MovingMesh> movingMeshes = new List<MovingMesh>();
        private readonly Dictionary<BodySegment, SegmentMotion> solved =
            new Dictionary<BodySegment, SegmentMotion>();
        private FullBodyPoseSmoother poseSmoother;
        [Header("Debug anatomical focus")]
        [SerializeField] private FullBodyViewMode viewMode = FullBodyViewMode.FullBody;
        private readonly Dictionary<Renderer, bool> originalVisibility =
            new Dictionary<Renderer, bool>();
        private readonly Dictionary<Renderer, BodySegment> rendererRegion =
            new Dictionary<Renderer, BodySegment>();
        private bool hasPose;
        private float lastPoseTime = -100f;

        // M4/M5 diagnostic preview, NEVER automatically enabled by the
        // default 2D mirror or by a synthetic pose/camera. Three-dimensional
        // atlas motion stays in original FBX ROOT-LOCAL coordinates; its
        // visual placement over a live RGB camera still requires M5 hardware
        // registration and is NOT validated by this preview.
        private bool reviewed3DPreviewRequested;
        private bool reviewed3DPreviewAuthorized;
        private BodySimilarityCalibration frozen3DCalibration;
        private long last3DFrameId = -1;
        private long last3DTimestampMs = -1;
        [Header("Reviewed 3D diagnostic only (no camera alignment)")]
        [SerializeField, Range(0f, 20f)] private float minLimbFlexionDegrees = 0f;
        [SerializeField, Range(40f, 175f)] private float maxLimbFlexionDegrees = 150f;

        public bool IsReviewed3DPreviewActive
        {
            get { return reviewed3DPreviewRequested && reviewed3DPreviewAuthorized; }
        }

        /// <summary>
        /// Explicit review gate: the normal 2D renderer is not switched to
        /// model-world motion until ONE real intact FBX has been reviewed,
        /// the session has collected stable real PoseFrames, and an operator
        /// has approved diagnostic (NOT AR) playback. The returned 3D pose
        /// remains in FBX local coordinates; NO camera extrinsics implied.
        /// </summary>
        public bool TryEnableReviewed3DPreview(
            BodySimilarityCalibration frozenCalibration,
            PoseCaptureQuality capture,
            bool operatorApprovedDiagnosticPreview)
        {
            string error;
            if (!Application.isPlaying || atlasRoot == null ||
                profile == null || profile.schematicDemo ||
                !operatorApprovedDiagnosticPreview ||
                !frozenCalibration.IsValid || !frozenCalibration.PreservesHandedness ||
                capture.AcceptedFrames < 12 ||
                capture.FirstFrameId < 0 ||
                capture.LastFrameId <= capture.FirstFrameId ||
                capture.LastTimestampMs <= capture.FirstTimestampMs ||
                float.IsNaN(capture.MaximumJointDriftInShoulderWidths) ||
                capture.MaximumJointDriftInShoulderWidths < 0f ||
                capture.MaximumJointDriftInShoulderWidths > 0.06f ||
                !profile.Validate(out error) ||
                !profile.ValidateHierarchy(out error))
                return false;

            frozen3DCalibration = frozenCalibration;
            last3DFrameId = capture.LastFrameId;
            last3DTimestampMs = capture.LastTimestampMs;
            lastPoseTime = Time.realtimeSinceStartup;
            reviewed3DPreviewRequested = true;
            reviewed3DPreviewAuthorized = true;
            hasPose = false;
            if (atlasContainer != null) atlasContainer.SetActive(false);
            return true;
        }

        /// <summary>Explicitly leave the 3D diagnostic and return to 2D mode.</summary>
        public void DisableReviewed3DPreview()
        {
            reviewed3DPreviewRequested = false;
            reviewed3DPreviewAuthorized = false;
            frozen3DCalibration = default(BodySimilarityCalibration);
            last3DFrameId = last3DTimestampMs = -1;
            hasPose = false;
            if (atlasContainer != null) atlasContainer.SetActive(false);
        }

        public void Configure(PoseStreamReceiver source, Camera camera,
                              FullBodyAtlasProfile atlasProfile)
        {
            if (Application.isPlaying && poseSource != null)
                poseSource.FrameReceived -= OnPoseFrame;
            poseSource = source;
            anatomyCamera = camera;
            profile = atlasProfile;
            if (Application.isPlaying && isActiveAndEnabled && poseSource != null)
                poseSource.FrameReceived += OnPoseFrame;
        }

        private void Awake()
        {
            poseSmoother = new FullBodyPoseSmoother(
                poseHalfLifeSeconds, dropoutGraceSeconds, maxNormalizedJump);
            if (profile == null || anatomyCamera == null)
            {
                Debug.LogWarning("MagicMirror full-body atlas is not configured.");
                enabled = false;
                return;
            }

            string error;
            if (!profile.Validate(out error) ||
                !profile.ValidateHierarchy(out error))
            {
                Debug.LogWarning("MagicMirror atlas profile/hierarchy invalid: " + error);
                enabled = false;
                return;
            }

            atlasContainer = new GameObject("Full Atlas: " + profile.name);
            // World-space root avoids accidental double scaling/rotation from the
            // retargeter scene GameObject. The imported atlas hierarchy is preserved.
            atlasContainer.transform.localPosition = Vector3.zero;
            atlasContainer.transform.localRotation = Quaternion.identity;
            atlasContainer.transform.localScale = Vector3.one;

            // Full original prefab is instantiated exactly ONCE, unchanged.
            GameObject instance = Instantiate(profile.wholeSkeletonPrefab,
                atlasContainer.transform, false);
            instance.name = "Original Full Skeleton [Hierarchy Preserved]";
            atlasRoot = instance.transform;

            SetRenderLayer(atlasRoot, AnatomyLayer);
            if (!RegisterMeshBindings())
            {
                Debug.LogWarning("No valid motion bindings. Whole atlas will stay neutral.");
            }
            CacheRendererRegions();
            ApplyViewMode();
            atlasContainer.SetActive(false);
        }

        private void OnEnable()
        {
            if (poseSource != null) poseSource.FrameReceived += OnPoseFrame;
        }

        private void OnDisable()
        {
            if (poseSource != null) poseSource.FrameReceived -= OnPoseFrame;
            if (atlasContainer != null) atlasContainer.SetActive(false);
            if (poseSmoother != null) poseSmoother.Reset();
            DisableReviewed3DPreview();
            hasPose = false;
        }

        private void LateUpdate()
        {
            // Development controls: Focus views without modifying original FBX
            // hierarchy or destroying any anatomical structures.
#if ENABLE_LEGACY_INPUT_MANAGER
            if (Input.GetKeyDown(KeyCode.Alpha1)) SetViewMode(FullBodyViewMode.FullBody);
            if (Input.GetKeyDown(KeyCode.Alpha2)) SetViewMode(FullBodyViewMode.UpperBody);
            if (Input.GetKeyDown(KeyCode.Alpha3)) SetViewMode(FullBodyViewMode.ArmsOnly);
            if (Input.GetKeyDown(KeyCode.Alpha4)) SetViewMode(FullBodyViewMode.LegsOnly);
#endif

            bool stale = Time.realtimeSinceStartup - lastPoseTime > staleAfterSeconds;
            if (stale && reviewed3DPreviewRequested)
            {
                // Revoke even if a preceding low-confidence frame had hidden
                // the preview. Reacquisition needs a fresh reviewed capture.
                reviewed3DPreviewAuthorized = false;
                Hide3DPreview();
            }
            else if (hasPose && stale)
            {
                hasPose = false;
                if (atlasContainer != null) atlasContainer.SetActive(false);
            }
        }

        private void OnValidate()
        {
            if (Application.isPlaying && atlasRoot != null)
                ApplyViewMode();
        }

        public FullBodyViewMode CurrentViewMode { get { return viewMode; } }

        public void SetViewMode(FullBodyViewMode mode)
        {
            viewMode = mode;
            ApplyViewMode();
        }

        private void CacheRendererRegions()
        {
            originalVisibility.Clear();
            rendererRegion.Clear();
            foreach (Renderer renderer in atlasRoot.GetComponentsInChildren<Renderer>(true))
                originalVisibility[renderer] = renderer.enabled;

            foreach (MovingMesh entry in movingMeshes)
            {
                Renderer renderer = entry.transform.GetComponent<Renderer>();
                if (renderer != null)
                    rendererRegion[renderer] = entry.group.segment;
            }
        }

        private void ApplyViewMode()
        {
            if (atlasRoot == null) return;
            foreach (var pair in originalVisibility)
            {
                BodySegment segment;
                bool assigned = rendererRegion.TryGetValue(pair.Key, out segment);
                bool allowed = viewMode == FullBodyViewMode.FullBody ||
                               (assigned && MatchesMode(segment, viewMode));
                if (pair.Key != null)
                    pair.Key.enabled = pair.Value && allowed;
            }
        }

        private static bool MatchesMode(BodySegment segment, FullBodyViewMode mode)
        {
            switch (mode)
            {
                case FullBodyViewMode.UpperBody:
                    return segment == BodySegment.Head ||
                           segment == BodySegment.Torso ||
                           segment == BodySegment.LeftUpperArm ||
                           segment == BodySegment.RightUpperArm ||
                           segment == BodySegment.LeftForearm ||
                           segment == BodySegment.RightForearm ||
                           segment == BodySegment.LeftHand ||
                           segment == BodySegment.RightHand;
                case FullBodyViewMode.ArmsOnly:
                    return segment == BodySegment.LeftUpperArm ||
                           segment == BodySegment.RightUpperArm ||
                           segment == BodySegment.LeftForearm ||
                           segment == BodySegment.RightForearm ||
                           segment == BodySegment.LeftHand ||
                           segment == BodySegment.RightHand;
                case FullBodyViewMode.LegsOnly:
                    return segment == BodySegment.LeftThigh ||
                           segment == BodySegment.RightThigh ||
                           segment == BodySegment.LeftShin ||
                           segment == BodySegment.RightShin ||
                           segment == BodySegment.LeftFoot ||
                           segment == BodySegment.RightFoot;
                default:
                    return true;
            }
        }

        private static void SetRenderLayer(Transform root, int layer)
        {
            root.gameObject.layer = layer;
            foreach (Transform child in root)
                SetRenderLayer(child, layer);
        }

        private bool RegisterMeshBindings()
        {
            movingMeshes.Clear();
            var alreadyMapped = new HashSet<Transform>();
            foreach (var group in profile.groups)
            {
                foreach (string path in group.rendererRootPaths)
                {
                    Transform branch;
                    string problem;
                    if (!AtlasHierarchyPath.TryResolve(atlasRoot, path, out branch, out problem))
                    {
                        Debug.LogWarning("Atlas binding path rejected: " + problem);
                        continue;
                    }
                    var renderers = branch.GetComponentsInChildren<Renderer>(true);
                    foreach (Renderer renderer in renderers)
                    {
                        if (renderer is SkinnedMeshRenderer)
                        {
                            Debug.LogWarning("Skipping skinned renderer (not a rigid bone): " +
                                             renderer.name);
                            continue;
                        }
                        Transform mesh = renderer.transform;
                        if (!alreadyMapped.Add(mesh))
                        {
                            Debug.LogWarning("Duplicate/overlapping atlas bone mapping: " +
                                             mesh.name);
                            continue;
                        }
                        int depth = 0;
                        for (Transform parent = mesh.parent;
                             parent != null && parent != atlasRoot;
                             parent = parent.parent) depth++;

                        movingMeshes.Add(new MovingMesh
                        {
                            transform = mesh,
                            group = group,
                            originalLocalPosition = mesh.localPosition,
                            originalLocalRotation = mesh.localRotation,
                            originalLocalScale = mesh.localScale,
                            neutralAtlasPosition = atlasRoot.InverseTransformPoint(mesh.position),
                            neutralAtlasRotation =
                                Quaternion.Inverse(atlasRoot.rotation) * mesh.rotation,
                            hierarchyDepth = depth
                        });
                    }
                }
            }
            // If two bound renderers have an ancestor relationship, setting
            // parent's world transform FIRST, then child's prevents a later
            // inherited parent movement invalidating the child target.
            movingMeshes.Sort((a, b) => a.hierarchyDepth.CompareTo(b.hierarchyDepth));
            return movingMeshes.Count > 0;
        }

        private void OnPoseFrame(PoseFrame frame)
        {
            if (atlasRoot == null)
                return;
            if (reviewed3DPreviewRequested)
            {
                OnReviewed3DPreviewFrame(frame);
                return;
            }
            if (frame == null || !frame.IsValid)
                return;

            float receiveTime = Time.realtimeSinceStartup;
            Vector2 leftShoulder, rightShoulder;
            if (!poseSmoother.TryShoulders(
                frame, confidenceThreshold, receiveTime,
                out leftShoulder, out rightShoulder))
            {
                atlasContainer.SetActive(false);
                hasPose = false;
                return;
            }

            anatomyCamera.aspect = (float)frame.width / frame.height;
            Vector3 currentLeft = ProjectToAnatomyPlane(leftShoulder);
            Vector3 currentRight = ProjectToAnatomyPlane(rightShoulder);

            // Reset original local transforms every frame: zero accumulated
            // rotations, preserve all unanimated source anatomical geometry.
            foreach (var entry in movingMeshes)
            {
                entry.transform.localPosition = entry.originalLocalPosition;
                entry.transform.localRotation = entry.originalLocalRotation;
                entry.transform.localScale = entry.originalLocalScale;
                entry.hasComputedPose = false;
            }

            // Note imported FBX root can already contain transform/scale.
            // Use its own TransformPoint before calibrating parent container.
            atlasContainer.transform.localPosition = Vector3.zero;
            atlasContainer.transform.localRotation = Quaternion.identity;
            atlasContainer.transform.localScale = Vector3.one;

            Vector3 restLeft = atlasRoot.TransformPoint(profile.atlasLeftShoulderLocal);
            Vector3 restRight = atlasRoot.TransformPoint(profile.atlasRightShoulderLocal);
            AtlasRegistrationMath.Solution alignment;
            Quaternion anatomicalOrientation = anatomyCamera.transform.rotation *
                                               Quaternion.Euler(profile.atlasToCameraEuler);
            if (!AtlasRegistrationMath.TrySolve(
                restLeft, restRight, currentLeft, currentRight,
                anatomicalOrientation, out alignment))
            {
                atlasContainer.SetActive(false);
                hasPose = false;
                return;
            }

            // Prevent a suddenly invalid shoulder width from exploding the
            // original atlas. These are safety bounds, not anthropometry.
            if (alignment.scale < 0.001f || alignment.scale > 1000f)
            {
                atlasContainer.SetActive(false);
                hasPose = false;
                return;
            }

            // Both shoulders must register to the same source-space pair.
            // This is a planar similarity fit; we still cannot infer true depth.
            atlasContainer.transform.SetPositionAndRotation(
                alignment.position, alignment.rotation);
            atlasContainer.transform.localScale = Vector3.one * alignment.scale;

            solved.Clear();
            foreach (var group in profile.groups)
            {
                if (solved.ContainsKey(group.segment))
                    continue;
                BodySegment2D segment;
                if (!poseSmoother.TrySegment(frame, group.segment,
                                             confidenceThreshold, receiveTime, out segment))
                    continue;

                Vector3 targetStart = ProjectToAnatomyPlane(segment.start);
                Vector3 targetEnd = ProjectToAnatomyPlane(segment.end);
                Vector3 restStart = atlasRoot.TransformPoint(group.atlasStartLocal);
                Vector3 restEnd = atlasRoot.TransformPoint(group.atlasEndLocal);
                Vector3 restDirection = restEnd - restStart;
                Vector3 targetDirection = targetEnd - targetStart;
                if (restDirection.sqrMagnitude < 1e-8f ||
                    targetDirection.sqrMagnitude < 1e-8f)
                    continue;

                solved[group.segment] = new SegmentMotion
                {
                    start = targetStart,
                    restStart = restStart,
                    rotation = Quaternion.FromToRotation(restDirection, targetDirection)
                };
            }

            // Calculate targets from immutable atlas-space rest transforms
            // BEFORE moving any parent meshes.
            foreach (MovingMesh entry in movingMeshes)
            {
                SegmentMotion motion;
                if (!solved.TryGetValue(entry.group.segment, out motion))
                    continue;
                Vector3 restPosition = atlasRoot.TransformPoint(entry.neutralAtlasPosition);
                entry.computedPosition = motion.start +
                    motion.rotation * (restPosition - motion.restStart);
                entry.computedRotation = motion.rotation * atlasRoot.rotation *
                                          entry.neutralAtlasRotation;
                entry.hasComputedPose = true;
            }

            foreach (MovingMesh entry in movingMeshes)
            {
                if (entry.hasComputedPose)
                    entry.transform.SetPositionAndRotation(
                        entry.computedPosition, entry.computedRotation);
            }

            lastPoseTime = receiveTime;
            hasPose = true;
            atlasContainer.SetActive(true);
        }

        /// <summary>
        /// Diagnostic ONLY: one reviewed intact FBX in its own atlas root.
        /// This deliberately does not project bones into the current camera;
        /// per-person camera extrinsics and alpha overlay are separate gates.
        /// Never silently drop back to planar mode when a 3D packet fails.
        /// </summary>
        private void OnReviewed3DPreviewFrame(PoseFrame frame)
        {
            if (!reviewed3DPreviewAuthorized || atlasContainer == null ||
                frame == null || !frame.IsValid || frame.demo || frame.mirrored)
            {
                Hide3DPreview();
                return;
            }

            // A TCP reconnect can restart from frame ID 0. PoseStreamReceiver
            // will accept that new session, but this 3D calibration CANNOT
            // continue automatically with a potentially different person.
            if (frame.frameId <= last3DFrameId ||
                frame.timestampMs <= last3DTimestampMs ||
                frame.timestampMs - last3DTimestampMs > 250)
            {
                reviewed3DPreviewAuthorized = false;
                Hide3DPreview();
                return;
            }
            last3DFrameId = frame.frameId;
            last3DTimestampMs = frame.timestampMs;
            lastPoseTime = Time.realtimeSinceStartup;

            // Always start from the source's immutable original renderer
            // transforms, never integrate motion into a previous frame.
            foreach (MovingMesh entry in movingMeshes)
            {
                if (entry.transform == null) continue;
                entry.transform.localPosition = entry.originalLocalPosition;
                entry.transform.localRotation = entry.originalLocalRotation;
                entry.transform.localScale = entry.originalLocalScale;
                entry.hasComputedPose = false;
            }
            atlasContainer.transform.localPosition = Vector3.zero;
            atlasContainer.transform.localRotation = Quaternion.identity;
            atlasContainer.transform.localScale = Vector3.one;

            // Generate exact SAME-SOURCE-FRAME 3D commands, all in the atlas
            // ROOT-LOCAL frame. Abort the entire pose if one configured chain
            // has an invalid joint or an unreviewed/missing paired region.
            solved.Clear();
            int configuredChains = 0;
            if (!TryBuildReviewed3DLimb(
                    frame, TrackedTwoLinkLimb.LeftArm,
                    BodySegment.LeftUpperArm, BodySegment.LeftForearm,
                    ref configuredChains) ||
                !TryBuildReviewed3DLimb(
                    frame, TrackedTwoLinkLimb.RightArm,
                    BodySegment.RightUpperArm, BodySegment.RightForearm,
                    ref configuredChains) ||
                !TryBuildReviewed3DLimb(
                    frame, TrackedTwoLinkLimb.LeftLeg,
                    BodySegment.LeftThigh, BodySegment.LeftShin,
                    ref configuredChains) ||
                !TryBuildReviewed3DLimb(
                    frame, TrackedTwoLinkLimb.RightLeg,
                    BodySegment.RightThigh, BodySegment.RightShin,
                    ref configuredChains) ||
                configuredChains == 0)
            {
                Hide3DPreview();
                return;
            }

            // Calculate WORLD target transforms from original FBX geometry
            // before applying any parent's motion. Even if a renderer has
            // parent/child relationships, compute all from its neutral pose.
            foreach (MovingMesh entry in movingMeshes)
            {
                if (entry.transform == null) continue;
                SegmentMotion motion;
                if (!solved.TryGetValue(entry.group.segment, out motion))
                    continue;
                Vector3 neutralWorld =
                    atlasRoot.TransformPoint(entry.neutralAtlasPosition);
                entry.computedPosition = motion.start +
                    motion.rotation * (neutralWorld - motion.restStart);
                entry.computedRotation = motion.rotation * atlasRoot.rotation *
                                         entry.neutralAtlasRotation;
                if (!Finite3D(entry.computedPosition) ||
                    !FiniteQuaternion(entry.computedRotation))
                {
                    Hide3DPreview();
                    return;
                }
                entry.hasComputedPose = true;
            }

            // Parent-before-child world transforms prevent inherited motion
            // from changing the intended absolute target of bound meshes.
            foreach (MovingMesh entry in movingMeshes)
            {
                if (entry.transform != null && entry.hasComputedPose)
                    entry.transform.SetPositionAndRotation(
                        entry.computedPosition, entry.computedRotation);
            }
            hasPose = true;
            lastPoseTime = Time.realtimeSinceStartup;
            atlasContainer.SetActive(true);
        }

        private void Hide3DPreview()
        {
            hasPose = false;
            if (atlasContainer != null)
                atlasContainer.SetActive(false);
        }

        private bool TryBuildReviewed3DLimb(
            PoseFrame frame, TrackedTwoLinkLimb limb,
            BodySegment upperSegment, BodySegment lowerSegment,
            ref int configuredChains)
        {
            FullBodyAtlasProfile.MotionGroup upper = FindMotionGroup(upperSegment);
            FullBodyAtlasProfile.MotionGroup lower = FindMotionGroup(lowerSegment);
            if (upper == null && lower == null)
                return true; // An unmapped region stays at anatomical rest.
            if (upper == null || lower == null || !upper.reviewed || !lower.reviewed)
                return false; // A dangling upper/forearm is unsafe to animate.

            // A reviewed elbow or knee must have ONE shared anatomical
            // center. Never invent a bridge between misaligned source bones.
            float upperLength = (upper.atlasEndLocal -
                                 upper.atlasStartLocal).magnitude;
            float lowerLength = (lower.atlasEndLocal -
                                 lower.atlasStartLocal).magnitude;
            float hingeGap = Vector3.Distance(
                upper.atlasEndLocal, lower.atlasStartLocal);
            float allowedGap = Mathf.Min(upperLength, lowerLength) * 0.005f;
            if (!Finite3D(upper.atlasStartLocal) ||
                !Finite3D(upper.atlasEndLocal) ||
                !Finite3D(lower.atlasStartLocal) ||
                !Finite3D(lower.atlasEndLocal) ||
                upperLength < 1e-5f || lowerLength < 1e-5f ||
                hingeGap > allowedGap)
                return false;

            Vector3 restHinge =
                (upper.atlasEndLocal + lower.atlasStartLocal) * 0.5f;
            var reviewedChain = new ReviewedAtlasTwoLinkChain
            {
                proximalAtlasLocal = ToKinematic(upper.atlasStartLocal),
                hingeAtlasLocal = ToKinematic(restHinge),
                distalAtlasLocal = ToKinematic(lower.atlasEndLocal),
                upperRegionReviewed = upper.reviewed,
                lowerRegionReviewed = lower.reviewed
            };
            AtlasTwoLinkMotionCommand planned;
            if (!AtlasTwoLinkMotionPlanner.TryPlan(
                    frame, limb, frozen3DCalibration, reviewedChain,
                    confidenceThreshold, minLimbFlexionDegrees,
                    maxLimbFlexionDegrees, out planned) ||
                !planned.isValid ||
                planned.sourceFrameId != frame.frameId ||
                planned.sourceTimestampMs != frame.timestampMs)
                return false;

            SegmentMotion upperMotion, lowerMotion;
            if (!TryRegionWorldMotion(planned.upper, out upperMotion) ||
                !TryRegionWorldMotion(planned.lower, out lowerMotion))
                return false;
            solved[upperSegment] = upperMotion;
            solved[lowerSegment] = lowerMotion;
            configuredChains++;
            return true;
        }

        private FullBodyAtlasProfile.MotionGroup FindMotionGroup(
            BodySegment segment)
        {
            if (profile == null || profile.groups == null)
                return null;
            foreach (FullBodyAtlasProfile.MotionGroup group in profile.groups)
                if (group != null && group.segment == segment)
                    return group;
            return null;
        }

        private bool TryRegionWorldMotion(
            AtlasRigidRegionCommand command, out SegmentMotion result)
        {
            result = default(SegmentMotion);
            Vector3 restStart = atlasRoot.TransformPoint(
                ToUnity(command.restStartAtlasLocal));
            Vector3 restEnd = atlasRoot.TransformPoint(
                ToUnity(command.restEndAtlasLocal));
            Vector3 targetStart = atlasRoot.TransformPoint(
                ToUnity(command.targetStartAtlasLocal));
            Vector3 targetEnd = atlasRoot.TransformPoint(
                ToUnity(command.targetEndAtlasLocal));
            Vector3 restDirection = restEnd - restStart;
            Vector3 targetDirection = targetEnd - targetStart;
            if (!Finite3D(restStart) || !Finite3D(restEnd) ||
                !Finite3D(targetStart) || !Finite3D(targetEnd) ||
                restDirection.sqrMagnitude < 1e-10f ||
                targetDirection.sqrMagnitude < 1e-10f)
                return false;

            Quaternion rotation =
                Quaternion.FromToRotation(restDirection, targetDirection);
            if (!FiniteQuaternion(rotation))
                return false;
            result = new SegmentMotion
            {
                start = targetStart,
                restStart = restStart,
                rotation = rotation
            };
            return true;
        }

        private static KinematicVector3 ToKinematic(Vector3 p)
        {
            return new KinematicVector3(p.x, p.y, p.z);
        }

        private static Vector3 ToUnity(KinematicVector3 p)
        {
            return new Vector3(p.x, p.y, p.z);
        }

        private static bool Finite3D(Vector3 p)
        {
            return !float.IsNaN(p.x) && !float.IsInfinity(p.x) &&
                   !float.IsNaN(p.y) && !float.IsInfinity(p.y) &&
                   !float.IsNaN(p.z) && !float.IsInfinity(p.z);
        }

        private static bool FiniteQuaternion(Quaternion q)
        {
            return !float.IsNaN(q.x) && !float.IsInfinity(q.x) &&
                   !float.IsNaN(q.y) && !float.IsInfinity(q.y) &&
                   !float.IsNaN(q.z) && !float.IsInfinity(q.z) &&
                   !float.IsNaN(q.w) && !float.IsInfinity(q.w);
        }

        private struct SegmentMotion
        {
            public Vector3 start;
            public Vector3 restStart;
            public Quaternion rotation;
        }

        private Vector3 ProjectToAnatomyPlane(Vector2 normalizedSourcePoint)
        {
            return anatomyCamera.ViewportToWorldPoint(new Vector3(
                normalizedSourcePoint.x, 1f - normalizedSourcePoint.y, projectedDepth));
        }

        private void OnDestroy()
        {
            if (atlasContainer != null)
                Destroy(atlasContainer);
        }
    }
}

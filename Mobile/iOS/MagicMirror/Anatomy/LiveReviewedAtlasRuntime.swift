import CoreGraphics
import Foundation
import simd

/// A model bundle can be eligible for camera drawing only after BOTH
/// independently SHA-verified native resources are present. Metadata
/// flags are assertions from human reviewers, not a license grant.
struct ReviewedAtlasRuntimeResources {
    let mesh: VerifiedAnatomyAtlas
    let hierarchy: AnatomyAtlasManifest
    let skinning: [AtlasSkinInfluence]?

    let leftShoulder: SIMD3<Float>
    let rightShoulder: SIMD3<Float>
    let midHip: SIMD3<Float>

    enum ResourceError: Error {
        case mismatchedOrIncompleteBinding
    }

    /// Release builds must use this hash-verified, offline loader.
    static func load(bundle: Bundle = .main)
        throws -> ReviewedAtlasRuntimeResources {
        let mesh = try VerifiedAnatomyAtlas.load(bundle: bundle)
        let approved = try AnatomyAtlasStore.loadApproved(bundle: bundle)
        let influences = try AtlasSkinningPackage.load(
            bundle: bundle, atlas: mesh, hierarchy: approved.manifest
        )
        guard let resources = ReviewedAtlasRuntimeResources(
            mesh: mesh, hierarchy: approved.manifest,
            skinning: influences
        ) else { throw ResourceError.mismatchedOrIncompleteBinding }
        return resources
    }

    /// Synthetic XCTest fixtures can construct these objects directly;
    /// production must not bypass load(bundle:) when reading real assets.
    init?(
        mesh: VerifiedAnatomyAtlas,
        hierarchy: AnatomyAtlasManifest,
        skinning: [AtlasSkinInfluence]? = nil
    ) {
        guard (try? hierarchy.validateForUse()) != nil,
              mesh.manifest.reviewedForDistribution,
              mesh.manifest.reviewedJointBindings,
              mesh.manifest.sourceRevision == hierarchy.sourceRevision,
              !mesh.vertices.isEmpty else { return nil }

        let bones = hierarchy.bones
        guard bones.count == mesh.manifest.parts.count,
              Set(bones.map(\.nodePath))
                  == Set(mesh.manifest.parts.map(\.sourceHierarchyPath))
        else { return nil }

        // Rest-coordinate consistency across every occurrence of the
        // same MediaPipe anchor; no inferred left/right bone identities.
        var anchors: [Int: SIMD3<Float>] = [:]
        for bone in bones {
            guard let from = bone.restStartPoint,
                  let to = bone.restEndPoint else { return nil }
            for (index, position) in [
                (bone.proximalLandmark, from),
                (bone.distalLandmark, to)
            ] {
                if let old = anchors[index],
                   simd_length(old - position) > 1e-4 {
                    return nil
                }
                anchors[index] = position
            }
        }
        guard let ls = anchors[11], let rs = anchors[12],
              let leftHip = anchors[23], let rightHip = anchors[24],
              simd_length(rs - ls) > 1e-4 else { return nil }

        guard skinning == nil || (skinning!.count == mesh.vertices.count &&
            skinning!.allSatisfy({ $0.isValid(boneCount: bones.count) }))
        else { return nil }
        self.mesh = mesh
        self.hierarchy = hierarchy
        self.skinning = skinning
        leftShoulder = ls
        rightShoulder = rs
        midHip = (leftHip + rightHip) * 0.5
    }
}

/// Extrinsics must be independently reviewed for the exact capture frame.
/// In particular, AVFoundation intrinsics and MediaPipe world landmarks
/// cannot independently certify a body-to-camera transform.
///
/// Nothing in the shipping app currently supplies these records.
struct ReviewedSourceCameraFrame {
    let timestampMilliseconds: Int
    let imageSize: CGSize
    let intrinsics: BodyCameraIntrinsics
    let bodyToCamera: BodyToCameraTransform
    let independentReviewConfirmed: Bool

    func matches(_ frame: PoseSnapshot) -> Bool {
        guard independentReviewConfirmed,
              timestampMilliseconds == frame.timestampMilliseconds,
              imageSize == frame.imageSize,
              intrinsics.matches(image: frame.imageSize),
              bodyToCamera.isValid,
              let original = frame.cameraIntrinsics else { return false }
        return abs(intrinsics.fx - original.fx) <= 0.001 &&
            abs(intrinsics.fy - original.fy) <= 0.001 &&
            abs(intrinsics.cx - original.cx) <= 0.001 &&
            abs(intrinsics.cy - original.cy) <= 0.001 &&
            intrinsics.width == original.width &&
            intrinsics.height == original.height
    }
}

/// Actual on-device live coordinator joining frozen reference capture,
/// coherent FK, verified source-camera projection, and the Metal batch.
/// The installed app retains the proxy when any real review gate is absent.
@MainActor
final class LiveReviewedAtlasRuntime {
    let resources: ReviewedAtlasRuntimeResources

    private var capture = AnatomyReferenceCapture()
    private var registration: BodySimilarityRegistration?
    private(set) var skinnedFrame: SkinnedAtlasDrawBatch?
    private var lastTimestampMilliseconds = -1
    private var lastImageSize: CGSize?

    init(resources: ReviewedAtlasRuntimeResources) {
        self.resources = resources
    }

    func reset() {
        capture.reset()
        registration = nil
        skinnedFrame = nil
        lastTimestampMilliseconds = -1
        lastImageSize = nil
    }

    func render(
        frame: PoseSnapshot?,
        reviewedCamera: ReviewedSourceCameraFrame?,
        viewport: CGSize,
        focus: AnatomyFocus,
        opacity: Float
    ) -> CalibratedAtlasDrawBatch? {
        skinnedFrame = nil
        guard let frame, frame.hasTorsoAnchor,
              frame.worldPoints.count == 33,
              viewport.width.isFinite, viewport.height.isFinite,
              viewport.width > 0, viewport.height > 0,
              opacity.isFinite, opacity > 0,
              frame.timestampMilliseconds > lastTimestampMilliseconds
        else {
            reset()
            return nil
        }
        if (lastTimestampMilliseconds >= 0 &&
            frame.timestampMilliseconds - lastTimestampMilliseconds > 350) ||
            (lastImageSize != nil && lastImageSize != frame.imageSize) {
            capture.reset()
            registration = nil
        }
        lastTimestampMilliseconds = frame.timestampMilliseconds
        lastImageSize = frame.imageSize

        // Continue acquiring the reference even while camera review
        // data is unavailable; no anatomy is drawn until both exist.
        guard let reference = capture.ingest(frame) else { return nil }
        guard let reviewedCamera,
              reviewedCamera.matches(frame) else { return nil }

        if registration == nil {
            func point(_ i: Int) -> SIMD3<Float> {
                let p = reference.worldPoints[i]
                return SIMD3(p.x, p.y, p.z)
            }
            let midHip = (point(23) + point(24)) * 0.5
            registration = BodySimilarityRegistration.calibrate(
                sourceLeftShoulder: point(11),
                sourceRightShoulder: point(12),
                sourceMidHip: midHip,
                atlasLeftShoulder: resources.leftShoulder,
                atlasRightShoulder: resources.rightShoulder,
                atlasMidHip: resources.midHip,
                allowedScale: 0.25 ... 4,
                maximumPelvisResidual: 0.08
            )
        }
        guard let registration,
              let pose = CoherentAtlasRigPlanner.plan(
                manifest: resources.hierarchy,
                reference: reference,
                current: frame,
                registration: registration
              ),
              let projector = CoherentAtlasCameraProjection.prepare(
                pose: pose,
                matchingFrame: frame,
                registration: registration,
                intrinsics: reviewedCamera.intrinsics,
                extrinsics: reviewedCamera.bodyToCamera,
                independentCameraReviewConfirmed:
                    reviewedCamera.independentReviewConfirmed
              )
        else { return nil }

        if let weights = resources.skinning {
            skinnedFrame = SkinnedAtlasDrawBatch.build(
                atlas: resources.mesh,
                hierarchy: resources.hierarchy,
                projector: projector,
                influences: weights,
                viewport: viewport,
                focus: focus,
                opacity: opacity
            )
        }
        // Avoid CPU triangle regeneration when a complete reviewed
        // GPU-skinned draw has already been accepted for this frame.
        if skinnedFrame != nil { return nil }
        return CalibratedAtlasDrawBatch.build(
            atlas: resources.mesh,
            hierarchy: resources.hierarchy,
            projector: projector,
            viewport: viewport,
            opacity: opacity, focus: focus
        )
    }
}

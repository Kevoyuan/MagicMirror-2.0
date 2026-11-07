import CoreGraphics
import Foundation
import simd

/// Pixel-space pinhole camera calibration for a SINGLE, already oriented
/// source frame. All values refer to the exact same video dimensions used
/// for the MediaPipe PoseSnapshot. No guessed camera FoV/extrinsics.
struct BodyCameraIntrinsics: Sendable {
    let fx: Float
    let fy: Float
    let cx: Float
    let cy: Float
    let width: Float
    let height: Float

    var isValid: Bool {
        fx.isFinite && fy.isFinite && cx.isFinite && cy.isFinite &&
        width.isFinite && height.isFinite &&
        fx > 0 && fy > 0 && width > 0 && height > 0 &&
        cx >= 0 && cy >= 0 && cx <= width && cy <= height
    }

    func matches(image: CGSize) -> Bool {
        isValid &&
        abs(width - Float(image.width)) <= 0.5 &&
        abs(height - Float(image.height)) <= 0.5
    }
}

/// Explicit body-world -> image-oriented camera-space transform.
/// Camera coordinates here are +X to image right, +Y image DOWN,
/// +Z forward into the scene. World landmark coordinates are MediaPipe
/// estimates; only a separately derived/reviewed extrinsic is acceptable.
struct BodyToCameraTransform: Sendable {
    let rotation: simd_quatf
    let translation: SIMD3<Float>

    var isValid: Bool {
        let r = rotation.vector
        return r.x.isFinite && r.y.isFinite && r.z.isFinite &&
            r.w.isFinite && translation.x.isFinite &&
            translation.y.isFinite && translation.z.isFinite &&
            abs(simd_length(r) - 1) < 0.02
    }
}

struct ProjectedBodyPoint: Sendable {
    let normalizedX: Float
    let normalizedY: Float
    let depthMeters: Float
}

enum BodyCameraProjection {
    /// Returns nil for missing geometry, invalid rotation or points
    /// behind the camera. Offscreen image points are retained for the
    /// caller to judge, rather than silently clamped to the viewport.
    static func project(
        bodyWorld: SIMD3<Float>,
        camera: BodyCameraIntrinsics,
        bodyToCamera: BodyToCameraTransform
    ) -> ProjectedBodyPoint? {
        guard camera.isValid, bodyToCamera.isValid,
              bodyWorld.x.isFinite, bodyWorld.y.isFinite,
              bodyWorld.z.isFinite else { return nil }
        let p = simd_act(bodyToCamera.rotation, bodyWorld) +
            bodyToCamera.translation
        guard p.x.isFinite, p.y.isFinite, p.z.isFinite,
              p.z > 0.05 else { return nil }

        let u = camera.fx * p.x / p.z + camera.cx
        let v = camera.fy * p.y / p.z + camera.cy
        guard u.isFinite && v.isFinite else { return nil }
        return ProjectedBodyPoint(
            normalizedX: u / camera.width,
            normalizedY: v / camera.height,
            depthMeters: p.z
        )
    }
}

/// This is a source-landmark registration *diagnostic*, not evidence
/// that a generic atlas accurately represents a person's real bones.
struct BodyReprojectionReport: Sendable {
    let visibleCount: Int
    let p90ErrorFractionOfImageWidth: Float
    let maximumErrorFractionOfImageWidth: Float
    let accepted: Bool
}

enum BodyReprojectionGate {
    /// Rejects missing landmark pairs, image/frame mismatch, low confidence
    /// and an unverified body-camera transform. A hypothetical *known*
    /// calibration can be regression-tested without phone camera access.
    static func evaluate(
        snapshot: PoseSnapshot,
        camera: BodyCameraIntrinsics,
        transform: BodyToCameraTransform,
        requiredVisiblePoints: Int = 6,
        p90LimitFractionOfImageWidth: Float = 0.03,
        landmarkIndices: [Int]? = nil
    ) -> BodyReprojectionReport? {
        guard requiredVisiblePoints >= 4,
              p90LimitFractionOfImageWidth > 0,
              snapshot.isUsable,
              snapshot.worldPoints.count == 33,
              camera.matches(image: snapshot.imageSize),
              transform.isValid else { return nil }

        let indices = landmarkIndices ?? Array(0..<33)
        var errors: [Float] = []
        errors.reserveCapacity(indices.count)
        for index in indices where (0..<33).contains(index) {
            let observed = snapshot.points[index]
            let world = snapshot.worldPoints[index]
            guard observed.isUsable, world.isUsable,
                  let projected = BodyCameraProjection.project(
                      bodyWorld: SIMD3(world.x, world.y, world.z),
                      camera: camera, bodyToCamera: transform
                  ) else { continue }

            let dx = (projected.normalizedX - Float(observed.x))
            let dy = (projected.normalizedY - Float(observed.y))
            let errorInWidth = sqrt(
                dx * dx + dy * dy *
                (camera.height / camera.width) *
                (camera.height / camera.width)
            )
            guard errorInWidth.isFinite else { continue }
            errors.append(errorInWidth)
        }
        guard errors.count >= requiredVisiblePoints else { return nil }
        errors.sort()
        let p90Index = max(0, Int(ceil(Float(errors.count) * 0.90)) - 1)
        let p90 = errors[p90Index]
        return BodyReprojectionReport(
            visibleCount: errors.count,
            p90ErrorFractionOfImageWidth: p90,
            maximumErrorFractionOfImageWidth: errors[errors.count - 1],
            accepted: p90 <= p90LimitFractionOfImageWidth
        )
    }
}

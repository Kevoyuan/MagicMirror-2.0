import Foundation
import simd

/// A single camera-space half-space cut of approved GPU-skinned reference
/// anatomy. Fragment clipping exposes a mesh surface cut but DOES NOT
/// generate watertight section caps or real tissue cross-sectional data.
struct AnatomySectionCut {
    let plane: SIMD4<Float> // normal.xyz, signed plane offset

    /// Body axes are estimated from the visible shoulders and hips. Their
    /// exact anatomical direction/facing is not established by RGB video.
    /// Review of source-specific camera extrinsics is still mandatory.
    static func make(
        section: AnatomySectionPlane,
        offsetInShoulderWidths: Float,
        frame: PoseSnapshot,
        camera: ReviewedSourceCameraFrame
    ) -> AnatomySectionCut? {
        guard camera.matches(frame),
              frame.hasTorsoAnchor,
              frame.worldPoints.count == 33,
              offsetInShoulderWidths.isFinite,
              (-0.5 ... 0.5).contains(offsetInShoulderWidths)
        else { return nil }

        func p(_ id: Int) -> SIMD3<Float>? {
            let point = frame.worldPoints[id]
            guard point.isUsable else { return nil }
            return SIMD3(point.x, point.y, point.z)
        }
        guard let ls = p(11), let rs = p(12),
              let lh = p(23), let rh = p(24) else { return nil }

        let shoulder = (ls + rs) * 0.5
        let hip = (lh + rh) * 0.5
        let sideVector = rs - ls
        let shoulderWidth = simd_length(sideVector)
        guard shoulderWidth.isFinite, shoulderWidth > 0.12,
              shoulderWidth < 1.2 else { return nil }
        let side = sideVector / shoulderWidth
        let downRaw = hip - shoulder
        let downCorrected = downRaw - simd_dot(downRaw, side) * side
        let downLength = simd_length(downCorrected)
        guard downLength.isFinite, downLength > 0.12 else { return nil }
        let down = downCorrected / downLength
        let front = simd_cross(side, down)
        guard simd_length_squared(front) > 0.8 else { return nil }

        let normalBody: SIMD3<Float>
        switch section {
        case .axial: normalBody = down
        case .sagittal: normalBody = side
        case .coronal: normalBody = simd_normalize(front)
        }
        let cameraNormal = simd_act(
            camera.bodyToCamera.rotation, normalBody
        )
        let centerWorld = (shoulder + hip) * 0.5 +
            normalBody * (offsetInShoulderWidths * shoulderWidth)
        let cameraPoint = simd_act(
            camera.bodyToCamera.rotation, centerWorld
        ) + camera.bodyToCamera.translation

        guard cameraNormal.x.isFinite,
              cameraNormal.y.isFinite,
              cameraNormal.z.isFinite,
              cameraPoint.x.isFinite,
              cameraPoint.y.isFinite,
              cameraPoint.z.isFinite else { return nil }
        let n = simd_normalize(cameraNormal)
        let d = -simd_dot(n, cameraPoint)
        guard d.isFinite else { return nil }
        return AnatomySectionCut(plane: SIMD4(n, d))
    }
}

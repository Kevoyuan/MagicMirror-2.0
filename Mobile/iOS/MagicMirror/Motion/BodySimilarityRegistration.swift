import Foundation
import simd

/// A right-handed, uniform-scale rigid mapping between a MediaPipe-derived
/// reference BODY world frame and a human-reviewed anatomical atlas frame.
/// Needs frozen reference capture, consistent axis conventions and verified
/// anatomical correspondence. Three anchors do NOT prove front/back facing.
struct BodySimilarityRegistration {
    let scale: Float
    let pelvisResidualInShoulderWidths: Float

    private let sourceOrigin: SIMD3<Float>
    private let atlasOrigin: SIMD3<Float>
    private let sourceAxes: (x: SIMD3<Float>, y: SIMD3<Float>, z: SIMD3<Float>)
    private let atlasAxes: (x: SIMD3<Float>, y: SIMD3<Float>, z: SIMD3<Float>)

    static func calibrate(
        sourceLeftShoulder: SIMD3<Float>,
        sourceRightShoulder: SIMD3<Float>,
        sourceMidHip: SIMD3<Float>,
        atlasLeftShoulder: SIMD3<Float>,
        atlasRightShoulder: SIMD3<Float>,
        atlasMidHip: SIMD3<Float>,
        allowedScale: ClosedRange<Float>,
        maximumPelvisResidual: Float
    ) -> BodySimilarityRegistration? {
        guard allowedScale.lowerBound.isFinite, allowedScale.upperBound.isFinite,
              allowedScale.lowerBound > 1e-6,
              maximumPelvisResidual.isFinite,
              (0...3).contains(maximumPelvisResidual) else { return nil }

        guard let source = frame(
            left: sourceLeftShoulder, right: sourceRightShoulder,
            hip: sourceMidHip
        ), let atlas = frame(
            left: atlasLeftShoulder, right: atlasRightShoulder,
            hip: atlasMidHip
        ) else { return nil }

        let scale = atlas.width / source.width
        guard scale.isFinite, allowedScale.contains(scale) else { return nil }
        let poseTorso = sourceMidHip - source.origin
        let predicted = rotate(
            poseTorso, from: source.axes, to: atlas.axes
        ) * scale
        let atlasTorso = atlasMidHip - atlas.origin
        let residual = simd_length(predicted - atlasTorso) / atlas.width
        guard residual.isFinite, residual <= maximumPelvisResidual else {
            return nil
        }
        return BodySimilarityRegistration(
            scale: scale,
            pelvisResidualInShoulderWidths: residual,
            sourceOrigin: source.origin, atlasOrigin: atlas.origin,
            sourceAxes: source.axes, atlasAxes: atlas.axes
        )
    }

    func bodyToAtlas(_ source: SIMD3<Float>) -> SIMD3<Float>? {
        guard Self.finite(source) else { return nil }
        let value = atlasOrigin + Self.rotate(
            source - sourceOrigin, from: sourceAxes, to: atlasAxes
        ) * scale
        return Self.finite(value) ? value : nil
    }

    func atlasToBody(_ source: SIMD3<Float>) -> SIMD3<Float>? {
        guard Self.finite(source) else { return nil }
        let value = sourceOrigin + Self.rotate(
            source - atlasOrigin, from: atlasAxes, to: sourceAxes
        ) / scale
        return Self.finite(value) ? value : nil
    }

    private typealias Axes = (
        x: SIMD3<Float>, y: SIMD3<Float>, z: SIMD3<Float>
    )

    private static func finite(_ p: SIMD3<Float>) -> Bool {
        p.x.isFinite && p.y.isFinite && p.z.isFinite
    }

    private static func frame(
        left: SIMD3<Float>, right: SIMD3<Float>,
        hip: SIMD3<Float>
    ) -> (origin: SIMD3<Float>, axes: Axes, width: Float)? {
        guard finite(left), finite(right), finite(hip) else { return nil }
        let width = simd_length(right - left)
        guard width.isFinite, width > 1e-6 else { return nil }
        let x = (right - left) / width
        let origin = (left + right) * 0.5
        let torso = hip - origin
        let up = torso - x * simd_dot(torso, x)
        let height = simd_length(up)
        guard height.isFinite, height > width * 0.1, height > 1e-6
        else { return nil }
        let y = up / height
        let z = simd_normalize(simd_cross(x, y))
        guard finite(z) else { return nil }
        return (origin, (x: x, y: y, z: z), width)
    }

    private static func rotate(
        _ v: SIMD3<Float>, from: Axes, to: Axes
    ) -> SIMD3<Float> {
        to.x * simd_dot(v, from.x) +
        to.y * simd_dot(v, from.y) +
        to.z * simd_dot(v, from.z)
    }
}

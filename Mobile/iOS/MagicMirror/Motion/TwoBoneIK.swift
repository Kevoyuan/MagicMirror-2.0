import Foundation
import simd

/// Conservative, coordinate-system-independent two-link IK.
/// Port of the tested C# M4 geometry; works only when EVERY input is
/// expressed in one compatible, reviewed 3D coordinate system.
/// It is NOT a monocular camera extrinsics estimator.
struct TwoBoneIKSolution {
    let proximal: SIMD3<Float>
    let joint: SIMD3<Float>
    let distal: SIMD3<Float>
    let flexionDegrees: Float
    let targetWasClamped: Bool
}

enum TwoBoneIK {
    private static let epsilon: Float = 1e-6

    static func solve(
        proximal: SIMD3<Float>,
        observedDistal: SIMD3<Float>,
        bendPole: SIMD3<Float>,
        firstLength: Float,
        secondLength: Float,
        minFlexionDegrees: Float,
        maxFlexionDegrees: Float
    ) -> TwoBoneIKSolution? {
        func finite(_ p: SIMD3<Float>) -> Bool {
            p.x.isFinite && p.y.isFinite && p.z.isFinite
        }
        guard finite(proximal), finite(observedDistal), finite(bendPole),
              firstLength.isFinite, secondLength.isFinite,
              firstLength > epsilon, secondLength > epsilon,
              minFlexionDegrees.isFinite, maxFlexionDegrees.isFinite,
              minFlexionDegrees >= 0, maxFlexionDegrees <= 175,
              minFlexionDegrees <= maxFlexionDegrees else { return nil }

        let delta = observedDistal - proximal
        let distance = simd_length(delta)
        guard distance.isFinite, distance > epsilon else { return nil }
        let direction = delta / distance
        let pole = bendPole - proximal
        let projectedPole = pole - direction * simd_dot(pole, direction)
        let poleLength = simd_length(projectedPole)
        guard poleLength.isFinite, poleLength > epsilon else { return nil }
        let bendDirection = projectedPole / poleLength

        let a = firstLength, b = secondLength
        func reach(_ flexion: Float) -> Float {
            let radians = flexion * .pi / 180
            return sqrt(max(0, a * a + b * b + 2 * a * b * cos(radians)))
        }
        let minimumDistance = reach(maxFlexionDegrees)
        let maximumDistance = reach(minFlexionDegrees)
        guard minimumDistance.isFinite, maximumDistance.isFinite,
              minimumDistance > epsilon,
              maximumDistance >= minimumDistance else { return nil }

        let achievedDistance = max(
            minimumDistance, min(maximumDistance, distance)
        )
        let along = (a * a - b * b + achievedDistance * achievedDistance)
            / (2 * achievedDistance)
        let heightSquared = a * a - along * along
        guard along.isFinite, heightSquared.isFinite,
              heightSquared >= -1e-4 * max(1, a * a) else { return nil }
        let height = sqrt(max(0, heightSquared))
        let joint = proximal + direction * along + bendDirection * height
        let distal = proximal + direction * achievedDistance

        let cosFlexion = max(
            -1, min(1, (achievedDistance * achievedDistance - a * a - b * b)
                     / (2 * a * b))
        )
        let flexion = acos(cosFlexion) * 180 / Float.pi
        guard finite(joint), finite(distal), flexion.isFinite else {
            return nil
        }
        return TwoBoneIKSolution(
            proximal: proximal, joint: joint, distal: distal,
            flexionDegrees: flexion,
            targetWasClamped: abs(achievedDistance - distance) > 1e-5
        )
    }
}

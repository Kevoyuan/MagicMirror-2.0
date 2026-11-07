import CoreGraphics
import Foundation
import simd

struct BodyCameraPoseEstimate {
    let transform: BodyToCameraTransform
    let reprojection: BodyReprojectionReport
    let acceptedIterations: Int
}

/// Experimental monocular 6-DOF estimator from estimated MediaPipe world
/// joints and their observed 2D positions. It does NOT make the camera a
/// calibrated X-ray and it does not recover an individual's actual bones.
///
/// Requires real source-frame camera intrinsics. Uses a robust damped
/// Gauss-Newton fit with numeric derivatives, explicit degeneracy checks,
/// positive-Z projection, bounded steps and the P90 reprojection gate.
/// Fail closed when correspondence confidence or geometry is insufficient.
///
/// Runtime owner must additionally guard facing/mirroring, abrupt identity
/// swaps and temporal camera registration before driving a reviewed atlas.
enum BodyCameraPoseEstimator {
    private struct Match {
        let world: SIMD3<Float>
        let observedX: Float
        let observedY: Float
    }

    static let bodyIndices: [Int] = [
        11, 12, 13, 14, 15, 16,
        23, 24, 25, 26, 27, 28, 29, 30, 31, 32
    ]

    static func estimate(
        snapshot: PoseSnapshot,
        p90LimitFractionOfImageWidth: Float = 0.03
    ) -> BodyCameraPoseEstimate? {
        guard snapshot.isUsable,
              let camera = snapshot.cameraIntrinsics,
              camera.matches(image: snapshot.imageSize),
              snapshot.worldPoints.count == 33,
              p90LimitFractionOfImageWidth > 0 else { return nil }

        var matches: [Match] = []
        for index in bodyIndices {
            let observation = snapshot.points[index]
            let estimated = snapshot.worldPoints[index]
            guard observation.isUsable, estimated.isUsable,
                  observation.visibility >= 0.70,
                  estimated.visibility >= 0.70 else { continue }
            matches.append(Match(
                world: SIMD3<Float>(
                    estimated.x, estimated.y, estimated.z
                ),
                observedX: Float(observation.x) * camera.width,
                observedY: Float(observation.y) * camera.height
            ))
        }
        guard matches.count >= 12 else { return nil }

        // Degenerate, near-collinear 3D landmarks cannot establish six
        // independent camera pose parameters reliably.
        let xs = matches.map { $0.world.x }
        let ys = matches.map { $0.world.y }
        let zs = matches.map { $0.world.z }
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max(),
              let minZ = zs.min(), let maxZ = zs.max(),
              maxX - minX > 0.14,
              maxY - minY > 0.18,
              maxZ - minZ > 0.025 else { return nil }

        let left = snapshot.worldPoints[11]
        let right = snapshot.worldPoints[12]
        let screenLeft = snapshot.points[11]
        let screenRight = snapshot.points[12]
        guard left.isUsable, right.isUsable,
              screenLeft.isUsable, screenRight.isUsable else {
            return nil
        }
        let shoulder3D = simd_length(
            SIMD3<Float>(
                right.x - left.x, right.y - left.y, right.z - left.z
            )
        )
        let sx = (Float(screenRight.x) - Float(screenLeft.x)) *
            camera.width
        let sy = (Float(screenRight.y) - Float(screenLeft.y)) *
            camera.height
        let shoulderPixels = sqrt(sx * sx + sy * sy)
        guard shoulder3D >= 0.08,
              shoulderPixels >= 12, shoulderPixels.isFinite else {
            return nil
        }

        // Frontal/approximately front-aligned seed only; the optimizer
        // must reduce reprojection error. It cannot invent correct facing.
        let approximateDepth = min(
            Float(8), max(Float(0.45),
                camera.fx * shoulder3D / shoulderPixels
            )
        )
        let count = Float(matches.count)
        let centerWorld = matches.reduce(
            SIMD3<Float>(repeating: 0)
        ) { $0 + $1.world } / count
        let centerPixel = matches.reduce(
            SIMD2<Float>(repeating: 0)
        ) { total, current in
            total + SIMD2<Float>(
                current.observedX, current.observedY
            )
        } / count

        var current = BodyToCameraTransform(
            rotation: simd_quatf(
                angle: 0, axis: SIMD3<Float>(0, 1, 0)
            ),
            translation: SIMD3<Float>(
                (centerPixel.x - camera.cx) *
                    approximateDepth / camera.fx - centerWorld.x,
                (centerPixel.y - camera.cy) *
                    approximateDepth / camera.fy - centerWorld.y,
                approximateDepth - centerWorld.z
            )
        )
        guard current.isValid else { return nil }

        var damping = 0.01
        var acceptedIterations = 0
        for _ in 0..<22 {
            guard let original = residuals(
                current, matches: matches, camera: camera
            ) else { return nil }
            let baseCost = robustCost(original)

            // Six columns: rotations about camera x/y/z, then translation
            // x/y/z. Use scale-aware finite differences to avoid fragile
            // handwritten quaternion derivatives.
            var jacobian: [[SIMD2<Double>]] = []
            for parameter in 0..<6 {
                let epsilon: Float = parameter < 3 ? 0.0001 : 0.001
                let modified = perturb(
                    current, parameter: parameter,
                    increment: epsilon
                )
                guard let changed = residuals(
                    modified, matches: matches, camera: camera
                ) else { return nil }
                let derivative = zip(original, changed).map {
                    (baseline, changedValue) in
                    (changedValue - baseline) / Double(epsilon)
                }
                jacobian.append(derivative)
            }

            var matrix = Array(
                repeating: Array(repeating: 0.0, count: 6), count: 6
            )
            var gradient = Array(repeating: 0.0, count: 6)
            for i in 0..<original.count {
                let error = original[i]
                let distance = simd_length(error)
                let weight = min(1.0, 12.0 / max(distance, 1e-6))
                for j in 0..<6 {
                    let derivativeJ = jacobian[j][i]
                    gradient[j] += weight * simd_dot(derivativeJ, error)
                    for k in 0..<6 {
                        matrix[j][k] += weight *
                            simd_dot(derivativeJ, jacobian[k][i])
                    }
                }
            }
            for j in 0..<6 {
                matrix[j][j] += damping * max(1, matrix[j][j])
                gradient[j] *= -1
            }
            guard let steps = solveLinear6(
                matrix, rightHandSide: gradient
            ) else { break }

            var bounded = steps
            for i in 0..<3 {
                bounded[i] = max(-0.2, min(0.2, bounded[i]))
            }
            for i in 3..<6 {
                bounded[i] = max(-0.35, min(0.35, bounded[i]))
            }
            let candidate = apply(current, steps: bounded)
            guard let proposed = residuals(
                candidate, matches: matches, camera: camera
            ) else {
                damping = min(50, damping * 4)
                continue
            }
            if robustCost(proposed) + 1e-8 < baseCost {
                current = candidate
                acceptedIterations += 1
                damping = max(1e-7, damping * 0.5)
                if simd_length(
                    SIMD3<Double>(bounded[0], bounded[1], bounded[2])
                ) < 1e-5 &&
                   simd_length(
                       SIMD3<Double>(bounded[3], bounded[4], bounded[5])
                   ) < 1e-5 {
                    break
                }
            } else {
                damping = min(50, damping * 4)
            }
        }

        guard let report = BodyReprojectionGate.evaluate(
            snapshot: snapshot, camera: camera, transform: current,
            requiredVisiblePoints: 12,
            p90LimitFractionOfImageWidth:
                p90LimitFractionOfImageWidth,
            landmarkIndices: bodyIndices
        ), report.accepted else { return nil }

        return BodyCameraPoseEstimate(
            transform: current,
            reprojection: report,
            acceptedIterations: acceptedIterations
        )
    }

    private static func residuals(
        _ transform: BodyToCameraTransform,
        matches: [Match],
        camera: BodyCameraIntrinsics
    ) -> [SIMD2<Double>]? {
        var errors: [SIMD2<Double>] = []
        errors.reserveCapacity(matches.count)
        for match in matches {
            guard let result = BodyCameraProjection.project(
                bodyWorld: match.world,
                camera: camera, bodyToCamera: transform
            ) else { return nil }
            let xPixel = result.normalizedX * camera.width
            let yPixel = result.normalizedY * camera.height
            errors.append(SIMD2<Double>(
                Double(xPixel - match.observedX),
                Double(yPixel - match.observedY)
            ))
        }
        return errors
    }

    private static func robustCost(_ errors: [SIMD2<Double>]) -> Double {
        var cost = 0.0
        for value in errors {
            let distance = simd_length(value)
            if distance <= 12 {
                cost += 0.5 * distance * distance
            } else {
                cost += 12 * (distance - 6)
            }
        }
        return cost
    }

    private static func perturb(
        _ transform: BodyToCameraTransform,
        parameter: Int, increment: Float
    ) -> BodyToCameraTransform {
        if parameter < 3 {
            let axis: SIMD3<Float>
            switch parameter {
            case 0: axis = SIMD3(1, 0, 0)
            case 1: axis = SIMD3(0, 1, 0)
            default: axis = SIMD3(0, 0, 1)
            }
            return BodyToCameraTransform(
                rotation: simd_quatf(
                    angle: increment, axis: axis
                ) * transform.rotation,
                translation: transform.translation
            )
        }
        var shifted = transform.translation
        shifted[parameter - 3] += increment
        return BodyToCameraTransform(
            rotation: transform.rotation,
            translation: shifted
        )
    }

    private static func apply(
        _ transform: BodyToCameraTransform,
        steps: [Double]
    ) -> BodyToCameraTransform {
        let omega = SIMD3<Float>(
            Float(steps[0]), Float(steps[1]), Float(steps[2])
        )
        let angle = simd_length(omega)
        let rotation: simd_quatf
        if angle > 1e-8 {
            rotation = simd_quatf(
                angle: angle, axis: omega / angle
            ) * transform.rotation
        } else {
            rotation = transform.rotation
        }
        let shifted = transform.translation + SIMD3<Float>(
            Float(steps[3]), Float(steps[4]), Float(steps[5])
        )
        return BodyToCameraTransform(
            rotation: rotation, translation: shifted
        )
    }

    /// Six-by-six Gaussian elimination with partial pivoting. Returns
    /// nil for singular, ill-conditioned or non-finite normal equations.
    private static func solveLinear6(
        _ matrix: [[Double]], rightHandSide: [Double]
    ) -> [Double]? {
        guard matrix.count == 6,
              matrix.allSatisfy({ $0.count == 6 }),
              rightHandSide.count == 6 else { return nil }
        var a = (0..<6).map { row in
            matrix[row] + [rightHandSide[row]]
        }
        for column in 0..<6 {
            var pivot = column
            for row in column..<6 {
                if abs(a[row][column]) > abs(a[pivot][column]) {
                    pivot = row
                }
            }
            let magnitude = abs(a[pivot][column])
            guard magnitude.isFinite, magnitude > 1e-10 else { return nil }
            if pivot != column { a.swapAt(column, pivot) }
            let diagonal = a[column][column]
            for k in column...6 { a[column][k] /= diagonal }
            for row in 0..<6 where row != column {
                let multiplier = a[row][column]
                for k in column...6 {
                    a[row][k] -= multiplier * a[column][k]
                }
            }
        }
        let solution = a.map { $0[6] }
        return solution.allSatisfy(\.isFinite) ? solution : nil
    }
}

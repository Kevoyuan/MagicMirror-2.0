import CoreGraphics
import Foundation
import simd

/// A provisional PnP-like 6DoF estimate from MediaPipe's *estimated*
/// body-world landmarks and the corresponding camera image landmarks.
/// It is NOT independently verified camera extrinsics or a measurement
/// of a person's actual internal bone positions.
struct AutomaticCameraPoseCandidate: Sendable {
    let timestampMilliseconds: Int
    let imageSize: CGSize
    let transform: BodyToCameraTransform
    let landmarkCount: Int
    let p90ReprojectionErrorFractionOfWidth: Float
}

/// All computation is local. Damped nonlinear least squares estimates
/// rotation and translation using an observed 2D/3D pose and exact-frame
/// AVFoundation intrinsics. Numerical Jacobians avoid third-party solvers.
/// Strict gates reject missing depth structure, poor reprojection and
/// invalid/ambiguous fits. Results are *diagnostic candidates only*.
enum AutomaticCameraPoseEstimator {
    private struct Observation {
        let body: SIMD3<Float>
        let pixel: SIMD2<Float>
        let confidence: Double
    }

    private static let landmarkIDs = [
        0, 7, 8, 11, 12, 13, 14, 15, 16,
        23, 24, 25, 26, 27, 28
    ]
    private static let axes = [
        SIMD3<Float>(1, 0, 0),
        SIMD3<Float>(0, 1, 0),
        SIMD3<Float>(0, 0, 1)
    ]

    static func estimate(
        snapshot: PoseSnapshot,
        maxP90FractionOfImageWidth: Float = 0.03
    ) -> AutomaticCameraPoseCandidate? {
        guard snapshot.hasTorsoAnchor,
              let intrinsics = snapshot.cameraIntrinsics,
              intrinsics.matches(image: snapshot.imageSize),
              snapshot.worldPoints.count == 33,
              maxP90FractionOfImageWidth.isFinite,
              (0.005...0.05).contains(maxP90FractionOfImageWidth)
        else { return nil }

        var observed: [Observation] = []
        for id in landmarkIDs {
            let w = snapshot.worldPoints[id]
            let p = snapshot.points[id]
            guard w.isUsable, p.isUsable else { continue }
            observed.append(Observation(
                body: SIMD3(w.x, w.y, w.z),
                pixel: SIMD2(
                    Float(p.x) * intrinsics.width,
                    Float(p.y) * intrinsics.height
                ),
                confidence: Double(min(w.visibility, p.visibility))
            ))
        }
        guard observed.count >= 9 else { return nil }

        let bodies = observed.map(\.body)
        let boundsZ = bodies.map(\.z)
        guard let low = boundsZ.min(), let high = boundsZ.max(),
              high - low >= 0.025 else { return nil }

        // Two almost-collinear shoulder/hip directions cannot establish
        // a stable world frame, even with a very low fitted pixel error.
        let shoulderL = snapshot.worldPoints[11]
        let shoulderR = snapshot.worldPoints[12]
        let hipL = snapshot.worldPoints[23]
        let side = SIMD3(
            shoulderR.x - shoulderL.x,
            shoulderR.y - shoulderL.y,
            shoulderR.z - shoulderL.z
        )
        let down = SIMD3(
            hipL.x - shoulderL.x,
            hipL.y - shoulderL.y,
            hipL.z - shoulderL.z
        )
        guard simd_length(simd_cross(side, down)) > 0.008
        else { return nil }

        var best: BodyToCameraTransform?
        var bestLoss = Double.infinity
        // Several initial yaw values avoid declaring one mirrored or
        // locally stationary guess correct without reprojection evidence.
        for yaw in [Float(0), 0.65, -0.65, 1.3, -1.3, 2.4, -2.4] {
            let rotation = simd_quatf(
                angle: yaw, axis: SIMD3<Float>(0, 1, 0)
            )
            let sampleCount = Float(observed.count)
            var worldMean = SIMD3<Float>(repeating: 0)
            var pixelMean = SIMD2<Float>(repeating: 0)
            for sample in observed {
                worldMean += sample.body
                pixelMean += sample.pixel
            }
            worldMean /= sampleCount
            pixelMean /= sampleCount
            let rotatedMean = simd_act(rotation, worldMean)
            let initialDepth: Float = 2.5
            let translation = SIMD3<Float>(
                (pixelMean.x - intrinsics.cx) *
                    initialDepth / intrinsics.fx - rotatedMean.x,
                (pixelMean.y - intrinsics.cy) *
                    initialDepth / intrinsics.fy - rotatedMean.y,
                initialDepth - rotatedMean.z
            )
            let initial = BodyToCameraTransform(
                rotation: rotation, translation: translation
            )
            guard let candidate = refine(
                initial: initial,
                samples: observed,
                camera: intrinsics
            ), let loss = totalLoss(
                candidate, samples: observed, camera: intrinsics
            ) else { continue }
            if loss < bestLoss {
                bestLoss = loss
                best = candidate
            }
        }
        guard let transform = best,
              transform.isValid,
              let report = BodyReprojectionGate.evaluate(
                snapshot: snapshot, camera: intrinsics,
                transform: transform, requiredVisiblePoints: 9,
                p90LimitFractionOfImageWidth:
                    maxP90FractionOfImageWidth
              ), report.accepted,
              report.visibleCount >= 9
        else { return nil }

        return AutomaticCameraPoseCandidate(
            timestampMilliseconds: snapshot.timestampMilliseconds,
            imageSize: snapshot.imageSize,
            transform: transform,
            landmarkCount: report.visibleCount,
            p90ReprojectionErrorFractionOfWidth:
                report.p90ErrorFractionOfImageWidth
        )
    }

    private static func pixels(
        _ sample: Observation,
        transform: BodyToCameraTransform,
        camera: BodyCameraIntrinsics
    ) -> SIMD2<Float>? {
        guard let projection = BodyCameraProjection.project(
            bodyWorld: sample.body, camera: camera,
            bodyToCamera: transform
        ) else { return nil }
        return SIMD2<Float>(
            projection.normalizedX * camera.width,
            projection.normalizedY * camera.height
        )
    }

    private static func perturbed(
        _ transform: BodyToCameraTransform,
        component: Int, value: Float
    ) -> BodyToCameraTransform {
        if component < 3 {
            let delta = simd_quatf(
                angle: value, axis: axes[component]
            )
            return BodyToCameraTransform(
                rotation: delta * transform.rotation,
                translation: transform.translation
            )
        }
        var t = transform.translation
        t[component - 3] += value
        return BodyToCameraTransform(
            rotation: transform.rotation, translation: t
        )
    }

    private static func totalLoss(
        _ transform: BodyToCameraTransform,
        samples: [Observation],
        camera: BodyCameraIntrinsics
    ) -> Double? {
        guard transform.isValid,
              (0.10...20).contains(transform.translation.z)
        else { return nil }
        var cost = 0.0
        for sample in samples {
            guard let pixel = pixels(
                sample, transform: transform, camera: camera
            ) else { return nil }
            let difference = pixel - sample.pixel
            let distance = Double(simd_length(difference))
            let huber = 22.0
            cost += sample.confidence * (distance <= huber
                ? 0.5 * distance * distance
                : huber * (distance - huber * 0.5))
        }
        return cost.isFinite ? cost : nil
    }

    private static func refine(
        initial: BodyToCameraTransform,
        samples: [Observation],
        camera: BodyCameraIntrinsics
    ) -> BodyToCameraTransform? {
        var pose = initial
        var damping = 0.002
        guard var cost = totalLoss(
            pose, samples: samples, camera: camera
        ) else { return nil }
        let steps = [Float(0.00015), 0.00015, 0.00015,
                     0.0005, 0.0005, 0.0005]
        for _ in 0..<18 {
            var normal = Array(
                repeating: Array(repeating: 0.0, count: 6), count: 6
            )
            var gradient = Array(repeating: 0.0, count: 6)
            var valid = true
            for sample in samples {
                guard let image = pixels(
                    sample, transform: pose, camera: camera
                ) else {
                    valid = false
                    break
                }
                let error = image - sample.pixel
                let distance = max(Double(simd_length(error)), 1e-5)
                let robust = sample.confidence * min(1, 22 / distance)
                var dx = Array(repeating: 0.0, count: 6)
                var dy = Array(repeating: 0.0, count: 6)
                for component in 0..<6 {
                    guard let nudged = pixels(
                        sample,
                        transform: perturbed(
                            pose, component: component,
                            value: steps[component]
                        ),
                        camera: camera
                    ) else {
                        valid = false
                        break
                    }
                    dx[component] = Double(
                        (nudged.x - image.x) / steps[component]
                    )
                    dy[component] = Double(
                        (nudged.y - image.y) / steps[component]
                    )
                }
                if !valid { break }
                for a in 0..<6 {
                    gradient[a] -= robust * (
                        dx[a] * Double(error.x) +
                        dy[a] * Double(error.y)
                    )
                    for b in 0..<6 {
                        normal[a][b] += robust * (
                            dx[a] * dx[b] + dy[a] * dy[b]
                        )
                    }
                }
            }
            guard valid else { return nil }
            for i in 0..<6 {
                normal[i][i] += damping * max(1, normal[i][i])
            }
            guard let delta = solve(normal, gradient)
            else { return nil }
            var trial = pose
            for index in 0..<6 {
                trial = perturbed(
                    trial, component: index, value: Float(delta[index])
                )
            }
            guard let trialCost = totalLoss(
                trial, samples: samples, camera: camera
            ) else {
                damping = min(1_000, damping * 5)
                continue
            }
            if trialCost < cost {
                pose = trial
                cost = trialCost
                damping = max(1e-7, damping * 0.4)
                if delta.map(abs).max() ?? 0 < 1e-5 {
                    break
                }
            } else {
                damping = min(1_000, damping * 5)
            }
        }
        return pose
    }

    private static func solve(
        _ matrix: [[Double]], _ rhs: [Double]
    ) -> [Double]? {
        var rows = (0..<6).map { matrix[$0] + [rhs[$0]] }
        for col in 0..<6 {
            let pivot = (col..<6).max {
                abs(rows[$0][col]) < abs(rows[$1][col])
            }!
            if pivot != col { rows.swapAt(pivot, col) }
            let divisor = rows[col][col]
            guard divisor.isFinite, abs(divisor) > 1e-12 else {
                return nil
            }
            for k in col..<7 { rows[col][k] /= divisor }
            for row in 0..<6 where row != col {
                let factor = rows[row][col]
                for k in col..<7 {
                    rows[row][k] -= factor * rows[col][k]
                }
            }
        }
        let result = (0..<6).map { rows[$0][6] }
        return result.allSatisfy(\.isFinite) ? result : nil
    }
}

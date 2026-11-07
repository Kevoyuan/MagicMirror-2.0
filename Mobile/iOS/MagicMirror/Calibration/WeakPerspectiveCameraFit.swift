import CoreGraphics
import Foundation
import simd

/// One-camera, source-image-pixel weak-perspective mapping of estimated
/// MediaPipe BODY-world points onto the *same captured image* landmarks.
///
/// This is a local, source-quality-gated approximation, not a camera
/// intrinsics/extrinsics solver and NOT an observation of internal bones.
/// The fitted rows are orthogonal and have equal positive scale; the
/// third axis is their cross product, avoiding an implicit 3D reflection.
struct WeakPerspectiveCameraFit {
    let worldOrigin: SIMD3<Float>
    let imageOriginPixels: SIMD2<Float>
    let rowX: SIMD3<Float>
    let rowY: SIMD3<Float>
    let p90ResidualPixels: Float
    let inlierCount: Int

    func imagePixel(for world: SIMD3<Float>) -> SIMD2<Float>? {
        guard Self.finite(world) else { return nil }
        let relative = world - worldOrigin
        let pixel = imageOriginPixels + SIMD2<Float>(
            simd_dot(relative, rowX),
            simd_dot(relative, rowY)
        )
        return pixel.x.isFinite && pixel.y.isFinite ? pixel : nil
    }

    func screenPixel(
        for world: SIMD3<Float>, sourceImageSize: CGSize,
        viewport: CGSize
    ) -> SIMD2<Float>? {
        guard let pixel = imagePixel(for: world),
              sourceImageSize.width > 0, sourceImageSize.height > 0,
              viewport.width > 0, viewport.height > 0 else { return nil }
        let scale = Float(max(
            viewport.width / sourceImageSize.width,
            viewport.height / sourceImageSize.height
        ))
        let drawnWidth = Float(sourceImageSize.width) * scale
        let drawnHeight = Float(sourceImageSize.height) * scale
        return SIMD2<Float>(
            (Float(viewport.width) - drawnWidth) * 0.5 + pixel.x * scale,
            (Float(viewport.height) - drawnHeight) * 0.5 + pixel.y * scale
        )
    }

    static func estimate(
        snapshot: PoseSnapshot, maxP90FractionOfImageWidth: Float = 0.09
    ) -> WeakPerspectiveCameraFit? {
        guard snapshot.isUsable, snapshot.worldPoints.count == 33,
              snapshot.imageSize.width > 0, snapshot.imageSize.height > 0,
              maxP90FractionOfImageWidth.isFinite,
              maxP90FractionOfImageWidth > 0,
              maxP90FractionOfImageWidth <= 0.25 else { return nil }

        let jointIDs = [11,12,13,14,15,16,23,24,25,26,27,28,0,7,8]
        var observations: [Observation] = []
        let w = Float(snapshot.imageSize.width)
        let h = Float(snapshot.imageSize.height)
        for i in jointIDs {
            let image = snapshot.points[i]
            let world = snapshot.worldPoints[i]
            guard image.isUsable, world.isUsable else { continue }
            observations.append(Observation(
                world: SIMD3<Float>(world.x, world.y, world.z),
                image: SIMD2<Float>(Float(image.x) * w, Float(image.y) * h),
                weight: min(image.visibility, world.visibility)
            ))
        }
        guard observations.count >= 6,
              let rough = fit(observations) else { return nil }
        let initialErrors = observations.map {
            error(point: $0, fit: rough)
        }.sorted()
        let median = initialErrors[initialErrors.count / 2]
        let cutoff = max(18, median * 2.5)
        let inliers = observations.filter {
            error(point: $0, fit: rough) <= cutoff
        }
        guard inliers.count >= 6,
              let refined = fit(inliers) else { return nil }
        let errors = inliers.map {
            error(point: $0, fit: refined)
        }.sorted()
        let p90Index = max(0, Int(ceil(Float(errors.count) * 0.9)) - 1)
        let p90 = errors[p90Index]
        guard p90.isFinite,
              p90 <= maxP90FractionOfImageWidth * w else { return nil }
        return WeakPerspectiveCameraFit(
            worldOrigin: refined.worldOrigin,
            imageOriginPixels: refined.imageOriginPixels,
            rowX: refined.rowX,
            rowY: refined.rowY,
            p90ResidualPixels: p90,
            inlierCount: inliers.count
        )
    }

    private struct Observation {
        let world: SIMD3<Float>
        let image: SIMD2<Float>
        let weight: Float
    }

    private static func finite(_ p: SIMD3<Float>) -> Bool {
        p.x.isFinite && p.y.isFinite && p.z.isFinite
    }

    private static func error(
        point: Observation, fit: WeakPerspectiveCameraFit
    ) -> Float {
        guard let actual = fit.imagePixel(for: point.world) else {
            return .infinity
        }
        return simd_length(actual - point.image)
    }

    private static func fit(
        _ points: [Observation]
    ) -> WeakPerspectiveCameraFit? {
        let total = points.reduce(Float(0)) { $0 + $1.weight }
        guard total.isFinite, total > 0 else { return nil }
        var worldMean = SIMD3<Float>(repeating: 0)
        var imageMean = SIMD2<Float>(repeating: 0)
        for p in points {
            worldMean += p.world * p.weight
            imageMean += p.image * p.weight
        }
        worldMean /= total
        imageMean /= total

        var gram = Array(
            repeating: Array(repeating: Float(0), count: 3), count: 3
        )
        var rx = Array(repeating: Float(0), count: 3)
        var ry = Array(repeating: Float(0), count: 3)
        for p in points {
            let d = p.world - worldMean
            let target = p.image - imageMean
            for i in 0..<3 {
                rx[i] += p.weight * d[i] * target.x
                ry[i] += p.weight * d[i] * target.y
                for j in 0..<3 {
                    gram[i][j] += p.weight * d[i] * d[j]
                }
            }
        }
        let regularizer = max(
            1e-8, (gram[0][0] + gram[1][1] + gram[2][2]) * 0.0001
        )
        for i in 0..<3 { gram[i][i] += regularizer }
        guard let xc = solve3(gram, rx), let yc = solve3(gram, ry) else {
            return nil
        }
        let xRaw = SIMD3<Float>(xc[0], xc[1], xc[2])
        let yRaw = SIMD3<Float>(yc[0], yc[1], yc[2])
        let xLength = simd_length(xRaw)
        let yLength = simd_length(yRaw)
        guard xLength.isFinite, yLength.isFinite,
              xLength > 1e-3, yLength > 1e-3 else { return nil }

        let xAxis = xRaw / xLength
        let yOrthogonal = yRaw - xAxis * simd_dot(yRaw, xAxis)
        let yLengthOrthogonal = simd_length(yOrthogonal)
        guard yLengthOrthogonal.isFinite,
              yLengthOrthogonal > yLength * 0.18 else { return nil }
        let yAxis = yOrthogonal / yLengthOrthogonal
        let zAxis = simd_cross(xAxis, yAxis)
        guard finite(zAxis), simd_length_squared(zAxis) > 0.9 else {
            return nil
        }
        let scale = (xLength + yLengthOrthogonal) * 0.5
        guard scale.isFinite, scale > 0 else { return nil }
        return WeakPerspectiveCameraFit(
            worldOrigin: worldMean, imageOriginPixels: imageMean,
            rowX: xAxis * scale, rowY: yAxis * scale,
            p90ResidualPixels: 0, inlierCount: points.count
        )
    }

    private static func solve3(
        _ matrix: [[Float]], _ vector: [Float]
    ) -> [Float]? {
        var a = (0..<3).map { matrix[$0] + [vector[$0]] }
        for col in 0..<3 {
            let pivot = (col..<3).max {
                abs(a[$0][col]) < abs(a[$1][col])
            }!
            if pivot != col { a.swapAt(pivot, col) }
            let divisor = a[col][col]
            guard divisor.isFinite, abs(divisor) > 1e-10 else { return nil }
            for j in col..<4 { a[col][j] /= divisor }
            for row in 0..<3 where row != col {
                let multiplier = a[row][col]
                for j in col..<4 {
                    a[row][j] -= multiplier * a[col][j]
                }
            }
        }
        let result = [a[0][3], a[1][3], a[2][3]]
        return result.allSatisfy(\.isFinite) ? result : nil
    }
}

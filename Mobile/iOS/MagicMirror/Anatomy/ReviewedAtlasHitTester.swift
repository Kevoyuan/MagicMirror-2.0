import CoreGraphics
import Foundation
import simd

/// Selected source-authored model node, not a claim that RGB video
/// localized the corresponding internal structure in the person.
struct ReviewedAnatomySelection: Equatable {
    let system: AnatomyDisplayLayer
    let sourceHierarchyPath: String
    let displayName: String
    let sourceRevision: String

    var detail: String {
        "Reviewed reference mesh · " + system.title +
        ". A camera image cannot measure your internal anatomy."
    }
}

/// CPU tap-time ray picking against the SAME source-frame GPU-skinned
/// triangles, using the Metal shader's camera matrices, perspective and
/// video aspect-fill crop. Only invoked on user taps, never each frame.
enum ReviewedAtlasHitTester {
    static func select(
        at tap: CGPoint,
        batch: SkinnedAtlasDrawBatch,
        system: AnatomyDisplayLayer
    ) -> ReviewedAnatomySelection? {
        guard system != .referenceProxy,
              !batch.vertices.isEmpty,
              !batch.renderedParts.isEmpty,
              batch.vertices.count.isMultiple(of: 3),
              tap.x.isFinite, tap.y.isFinite,
              tap.x >= 0, tap.y >= 0,
              tap.x <= batch.viewportSize.width,
              tap.y <= batch.viewportSize.height,
              batch.viewportSize.width > 0,
              batch.viewportSize.height > 0,
              batch.cameraMatrices.count > 0,
              batch.cameraParameters.x > 0,
              batch.cameraParameters.y > 0,
              batch.viewportParameters.x > 0
        else { return nil }

        let screenTap = SIMD2<Float>(Float(tap.x), Float(tap.y))
        var closestZ = Float.infinity
        var selected: AtlasRenderedPart?
        for part in batch.renderedParts {
            guard part.vertexStart >= 0,
                  part.vertexCount >= 3,
                  part.vertexCount.isMultiple(of: 3),
                  part.vertexCount <= batch.vertices.count - part.vertexStart
            else { return nil }
            let last = part.vertexStart + part.vertexCount
            for i in stride(from: part.vertexStart, to: last, by: 3) {
                guard let a = cameraPoint(batch.vertices[i], batch),
                      let b = cameraPoint(batch.vertices[i + 1], batch),
                      let c = cameraPoint(batch.vertices[i + 2], batch),
                      let ap = project(a, batch),
                      let bp = project(b, batch),
                      let cp = project(c, batch),
                      let bary = barycentric(
                        at: screenTap, a: ap, b: bp, c: cp
                      ) else { continue }

                // Perspective-correct interpolation matches Metal's
                // smooth camera-space varyings under rasterization.
                let aWeight = bary.x / a.z
                let bWeight = bary.y / b.z
                let cWeight = bary.z / c.z
                let denom = aWeight + bWeight + cWeight
                guard denom.isFinite, denom > 0 else { continue }
                let point = (a * aWeight + b * bWeight +
                             c * cWeight) / denom
                let cut = batch.sectionPlane
                if simd_length_squared(
                    SIMD3<Float>(cut.x, cut.y, cut.z)
                ) > 0.5 &&
                   simd_dot(
                    SIMD3<Float>(cut.x, cut.y, cut.z), point
                   ) + cut.w < 0 {
                    continue
                }
                guard point.z.isFinite, point.z > 0.05,
                      point.z < closestZ else { continue }
                closestZ = point.z
                selected = part
            }
        }
        guard let selected else { return nil }
        return ReviewedAnatomySelection(
            system: system,
            sourceHierarchyPath: selected.sourceHierarchyPath,
            displayName: selected.displayName,
            sourceRevision: batch.sourceRevision
        )
    }

    private static func cameraPoint(
        _ v: SkinnedAtlasVertex,
        _ batch: SkinnedAtlasDrawBatch
    ) -> SIMD3<Float>? {
        var point = SIMD4<Float>(repeating: 0)
        for slot in 0..<4 {
            let weight = v.weights[slot]
            guard weight.isFinite, weight >= 0,
                  Int(v.joints[slot]) < batch.cameraMatrices.count
            else { return nil }
            if weight == 0 { continue }
            point += batch.cameraMatrices[Int(v.joints[slot])] *
                v.position * weight
        }
        let p = SIMD3<Float>(point.x, point.y, point.z)
        guard p.x.isFinite, p.y.isFinite, p.z.isFinite,
              p.z > 0.05, p.z <= 20 else { return nil }
        return p
    }

    private static func project(
        _ camera: SIMD3<Float>,
        _ batch: SkinnedAtlasDrawBatch
    ) -> SIMD2<Float>? {
        let intrinsic = batch.cameraParameters
        let crop = batch.viewportParameters
        let px = intrinsic.x * camera.x / camera.z + intrinsic.z
        let py = intrinsic.y * camera.y / camera.z + intrinsic.w
        let p = SIMD2<Float>(
            px * crop.x + crop.y,
            py * crop.x + crop.z
        )
        return p.x.isFinite && p.y.isFinite ? p : nil
    }

    private static func barycentric(
        at p: SIMD2<Float>,
        a: SIMD2<Float>, b: SIMD2<Float>, c: SIMD2<Float>
    ) -> SIMD3<Float>? {
        let v0 = b - a
        let v1 = c - a
        let v2 = p - a
        let d = v0.x * v1.y - v1.x * v0.y
        guard d.isFinite, abs(d) > 1e-6 else { return nil }
        let u = (v2.x * v1.y - v1.x * v2.y) / d
        let v = (v0.x * v2.y - v2.x * v0.y) / d
        let w = 1 - u - v
        guard u >= -1e-5, v >= -1e-5, w >= -1e-5
        else { return nil }
        return SIMD3(w, u, v)
    }
}

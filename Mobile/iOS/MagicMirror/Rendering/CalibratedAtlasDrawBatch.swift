import CoreGraphics
import Foundation
import simd

/// A verified, frame-bound GPU vertex batch. It cannot be constructed
/// directly from arbitrary screen-space positions by application code.
/// A batch is available only after full reviewed-manifest and calibrated
/// same-frame atlas projection checks have passed.
struct CalibratedAtlasDrawBatch {
    let sourceTimestampMilliseconds: Int
    let sourceImageSize: CGSize
    let viewportSize: CGSize
    let sourceRevision: String
    let focus: AnatomyFocus
    let opacity: Float
    let vertices: [BoneMeshVertex]

    private init(
        sourceTimestampMilliseconds: Int,
        sourceImageSize: CGSize,
        viewportSize: CGSize,
        sourceRevision: String,
        focus: AnatomyFocus,
        opacity: Float,
        vertices: [BoneMeshVertex]
    ) {
        self.sourceTimestampMilliseconds = sourceTimestampMilliseconds
        self.sourceImageSize = sourceImageSize
        self.viewportSize = viewportSize
        self.sourceRevision = sourceRevision
        self.focus = focus
        self.opacity = opacity
        self.vertices = vertices
    }

    /// Avoid displaying geometry computed for another camera image or
    /// screen layout, even when the two poses look superficially similar.
    func matches(
        frame: PoseSnapshot, viewport: CGSize,
        focus: AnatomyFocus, opacity: Float
    ) -> Bool {
        sourceTimestampMilliseconds == frame.timestampMilliseconds &&
        sourceImageSize == frame.imageSize &&
        viewportSize == viewport &&
        self.focus == focus && self.opacity == opacity &&
        frame.hasTorsoAnchor &&
        !vertices.isEmpty
    }

    /// This builder is intentionally NOT called by the default camera path:
    /// it requires a human-reviewed atlas and an independently calibrated,
    /// frame-bound projector from the caller.
    static func build(
        atlas: VerifiedAnatomyAtlas,
        hierarchy: AnatomyAtlasManifest,
        projector: CoherentAtlasCameraProjection,
        viewport: CGSize,
        opacity: Float,
        focus: AnatomyFocus
    ) -> CalibratedAtlasDrawBatch? {
        guard opacity.isFinite, opacity > 0,
              viewport.width.isFinite, viewport.height.isFinite,
              viewport.width > 0, viewport.height > 0,
              let triangles = CoherentAtlasMeshProjection.project(
                atlas: atlas, hierarchy: hierarchy,
                projector: projector, viewport: viewport, focus: focus
              ),
              !triangles.isEmpty,
              triangles.count <= 60_000
        else { return nil }

        let width = Float(viewport.width)
        let height = Float(viewport.height)
        let alpha = max(0, min(1, opacity)) * 0.58
        var vertices: [BoneMeshVertex] = []
        vertices.reserveCapacity(triangles.count * 3)

        for triangle in triangles {
            guard triangle.vertices.count == 3,
                  triangle.cameraNormals.count == 3 else { return nil }
            var projected: [SIMD4<Float>] = []
            projected.reserveCapacity(3)
            for vertex in triangle.vertices {
                let p = vertex.displayPosition
                let depth = vertex.cameraDepthMeters
                guard p.x.isFinite, p.y.isFinite,
                      depth.isFinite, depth > 0 else { return nil }
                // The pixel position is calibrated; relative clip depth
                // is for illustrative layering only, not medical distance.
                let clip = SIMD4<Float>(
                    2 * Float(p.x) / width - 1,
                    1 - 2 * Float(p.y) / height,
                    max(0, min(1, (depth - 0.05) / 19.95)),
                    1
                )
                guard clip.x.isFinite, clip.y.isFinite,
                      clip.z.isFinite else { return nil }
                projected.append(clip)
            }

            let a = SIMD3<Float>(
                projected[0].x, projected[0].y, projected[0].z
            )
            let b = SIMD3<Float>(
                projected[1].x, projected[1].y, projected[1].z
            )
            let c = SIMD3<Float>(
                projected[2].x, projected[2].y, projected[2].z
            )
            let area = simd_length_squared(simd_cross(b - a, c - a))
            guard area.isFinite, area > 1e-12 else { return nil }

            // Camera-oriented source surface normals rotate with
            // each approved rigid bone instead of using a flat billboard
            // normal. These are reference-mesh normals, never person
            // surface measurements.
            let color = SIMD4<Float>(0.93, 0.89, 0.78, alpha)
            for index in 0..<3 {
                let n = triangle.cameraNormals[index]
                guard n.x.isFinite, n.y.isFinite, n.z.isFinite,
                      abs(simd_length(n) - 1) < 0.005 else { return nil }
                let normal = SIMD4<Float>(n.x, n.y, n.z, 0)
                vertices.append(BoneMeshVertex(
                    position: projected[index], normal: normal, color: color
                ))
            }
        }
        return CalibratedAtlasDrawBatch(
            sourceTimestampMilliseconds:
                projector.pose.sourceTimestampMilliseconds,
            sourceImageSize: projector.pose.sourceImageSize,
            viewportSize: viewport,
            sourceRevision: atlas.manifest.sourceRevision,
            focus: focus, opacity: opacity,
            vertices: vertices
        )
    }
}

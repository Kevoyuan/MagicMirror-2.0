import CoreGraphics
import Foundation
import simd

/// One interleaved Metal vertex: fixed SIMD4 alignment makes the Swift and
/// Metal layouts identical (three float4s = 48 bytes).
struct BoneMeshVertex {
    var position: SIMD4<Float>
    var normal: SIMD4<Float>
    var color: SIMD4<Float>
}

/// A deliberately generic **3D volumetric proxy** generated from observed
/// surface joints. This is not an atlas, a medical bone surface, or proof
/// of calibrated camera extrinsics. All geometry is local to the phone.
enum AnatomyFocus: String, CaseIterable, Identifiable {
    case full = "Whole"
    case arms = "Arms"
    case legs = "Legs"

    var id: String { rawValue }
}

enum VolumetricBoneMesh {
    private static let sides = 10
    private static let profile: [Float] = [0.48, 0.98, 0.82, 0.82, 0.98, 0.48]
    private static let ivory = SIMD3<Float>(0.82, 0.94, 1.0)

    /// Converts camera image landmark coordinates to pixels after the exact
    /// same aspect-fill crop used by the native AVCaptureVideoPreviewLayer.
    static func sourcePoint(
        index: Int, snapshot: PoseSnapshot, viewport: CGSize
    ) -> SIMD3<Float>? {
        guard snapshot.isUsable,
              (0..<snapshot.points.count).contains(index),
              let screen = PoseSkeleton.pointInPreview(
                  snapshot.points[index],
                  imageSize: snapshot.imageSize, viewSize: viewport
              ) else { return nil }

        // MediaPipe 3D world landmarks are estimated and hip-relative, not
        // a measured depth map. Use a bounded *illustrative* depth only.
        let depthMeters: Float
        if snapshot.worldPoints.count == 33,
           snapshot.worldPoints[index].isUsable {
            depthMeters = max(-0.65, min(0.65, snapshot.worldPoints[index].z))
        } else {
            depthMeters = 0
        }
        return SIMD3(Float(screen.x), Float(screen.y), depthMeters * 110)
    }

    static func make(
        snapshot: PoseSnapshot?, viewport: CGSize, opacity: Float,
        focus: AnatomyFocus = .full
    ) -> [BoneMeshVertex] {
        guard let snapshot, snapshot.isUsable,
              viewport.width > 0, viewport.height > 0,
              opacity > 0 else { return [] }
        let alpha = max(0, min(1, opacity))
        var vertices: [BoneMeshVertex] = []
        vertices.reserveCapacity(9_000)

        func bone(_ a: Int, _ b: Int, radius: Float) {
            guard let start = sourcePoint(
                index: a, snapshot: snapshot, viewport: viewport
            ), let end = sourcePoint(
                index: b, snapshot: snapshot, viewport: viewport
            ) else { return }
            addSpindle(
                start: start, end: end, radius: radius,
                viewport: viewport, opacity: alpha, into: &vertices
            )
        }

        // Complete limb chains plus shoulder/hip anchors.
        // Thickness is in display points; designed for reference reading
        // rather than personal bone dimensions.
        if focus == .full || focus == .arms {
            bone(11, 13, radius: 7.2); bone(13, 15, radius: 5.4)
            bone(12, 14, radius: 7.2); bone(14, 16, radius: 5.4)
        }
        if focus == .full || focus == .legs {
            bone(23, 25, radius: 10.2); bone(25, 27, radius: 7.4)
            bone(24, 26, radius: 10.2); bone(26, 28, radius: 7.4)
            bone(27, 31, radius: 4.5); bone(28, 32, radius: 4.5)
        }
        if focus == .full {
            bone(11, 12, radius: 5.2); bone(23, 24, radius: 8)

            // Visual torso center is synthesized, not observed vertebrae.
            if let ls = sourcePoint(
                index: 11, snapshot: snapshot, viewport: viewport
            ), let rs = sourcePoint(
                index: 12, snapshot: snapshot, viewport: viewport
            ), let lh = sourcePoint(
                index: 23, snapshot: snapshot, viewport: viewport
            ), let rh = sourcePoint(
                index: 24, snapshot: snapshot, viewport: viewport
            ) {
                addSpindle(
                    start: (ls + rs) * 0.5, end: (lh + rh) * 0.5,
                    radius: 7.8, viewport: viewport,
                    opacity: alpha, into: &vertices
                )
            }
        }

        if focus == .full {
            // Original procedural educational *silhouettes*, NOT a
            // reviewed Z-Anatomy mesh or an image of internal structures.
            addReferenceRibs(
                snapshot: snapshot, viewport: viewport,
                opacity: alpha, into: &vertices
            )
            addReferenceCranium(
                snapshot: snapshot, viewport: viewport,
                opacity: alpha, into: &vertices
            )
        }

        return vertices
    }

    private static func addSpindle(
        start: SIMD3<Float>, end: SIMD3<Float>, radius: Float,
        viewport: CGSize, opacity: Float, into vertices: inout [BoneMeshVertex]
    ) {
        let diff = end - start
        let length = simd_length(diff)
        guard length > 2, length.isFinite, radius.isFinite, radius > 0 else { return }
        let axis = diff / length
        let helper = abs(axis.z) > 0.85
            ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(0, 0, 1)
        let right = simd_cross(axis, helper)
        guard simd_length_squared(right) > 1e-7 else { return }
        let radialU = simd_normalize(right)
        let radialV = simd_normalize(simd_cross(axis, radialU))
        let tint = SIMD4<Float>(ivory.x, ivory.y, ivory.z, opacity * 0.62)

        for ring in 0..<(profile.count - 1) {
            let t0 = Float(ring) / Float(profile.count - 1)
            let t1 = Float(ring + 1) / Float(profile.count - 1)
            for side in 0..<sides {
                let a0 = Float(side) * 2 * .pi / Float(sides)
                let a1 = Float(side + 1) * 2 * .pi / Float(sides)
                let normal0 = radialU * cos(a0) + radialV * sin(a0)
                let normal1 = radialU * cos(a1) + radialV * sin(a1)
                let p00 = start + diff * t0 + normal0 * radius * profile[ring]
                let p01 = start + diff * t0 + normal1 * radius * profile[ring]
                let p10 = start + diff * t1 + normal0 * radius * profile[ring + 1]
                let p11 = start + diff * t1 + normal1 * radius * profile[ring + 1]
                emit(p00, normal0, tint, viewport, into: &vertices)
                emit(p10, normal0, tint, viewport, into: &vertices)
                emit(p11, normal1, tint, viewport, into: &vertices)
                emit(p00, normal0, tint, viewport, into: &vertices)
                emit(p11, normal1, tint, viewport, into: &vertices)
                emit(p01, normal1, tint, viewport, into: &vertices)
            }
        }
    }

    /// The first usable mobile app must look like a skeleton, rather than
    /// an unlabeled collection of rods. These ribs are intentionally
    /// *procedural visual guides* registered to shoulder/hip pose anchors.
    /// No individual rib or spinal vertebra is actually detected.
    private static func addReferenceRibs(
        snapshot: PoseSnapshot, viewport: CGSize, opacity: Float,
        into vertices: inout [BoneMeshVertex]
    ) {
        guard let left = sourcePoint(
            index: 11, snapshot: snapshot, viewport: viewport
        ), let right = sourcePoint(
            index: 12, snapshot: snapshot, viewport: viewport
        ), let hipLeft = sourcePoint(
            index: 23, snapshot: snapshot, viewport: viewport
        ), let hipRight = sourcePoint(
            index: 24, snapshot: snapshot, viewport: viewport
        ) else { return }

        let shoulderCenter = (left + right) * 0.5
        let hipCenter = (hipLeft + hipRight) * 0.5
        let torso = hipCenter - shoulderCenter
        let width = simd_length(right - left)
        guard width > 18, width.isFinite,
              simd_length(torso) > 20 else { return }
        let lateral = simd_normalize(right - left)
        let depthAxis = SIMD3<Float>(0, 0, 1)
        let tint = SIMD4<Float>(0.90, 0.96, 1.0, opacity * 0.43)

        // Seven stylized paired arcs form a lightweight, recognizable
        // rib-cage silhouette. Not mapped to numbered real human ribs.
        for row in 0..<7 {
            let fraction = Float(row) / 6
            let center = shoulderCenter +
                torso * (0.19 + 0.55 * fraction)
            let halfWidth = width * (0.33 - 0.085 * fraction)
            let depth = halfWidth * 0.46
            let tubeRadius = max(1.25, min(3.0, width * 0.016))
            for sign: Float in [-1.0, 1.0] {
                let sections = 11
                for step in 0..<sections {
                    func position(_ index: Int) -> SIMD3<Float> {
                        let angle = Float(index) / Float(sections) * .pi
                        return center +
                            lateral * (sign * halfWidth * sin(angle)) +
                            depthAxis * (depth * cos(angle)) +
                            torso * (0.025 * sin(angle))
                    }
                    addThinTube(
                        start: position(step), end: position(step + 1),
                        radius: tubeRadius, color: tint,
                        viewport: viewport, into: &vertices
                    )
                }
            }
        }

        // A broad pelvic ring gives the hips a connected anatomical
        // reference even before any source-reviewed iliac mesh is shipped.
        let pelvisWidth = simd_length(hipRight - hipLeft) * 0.5
        if pelvisWidth > 10 && pelvisWidth.isFinite {
            let tint = SIMD4<Float>(0.85, 0.94, 1.0, opacity * 0.49)
            for sign: Float in [-1.0, 1.0] {
                let pieces = 12
                for step in 0..<pieces {
                    func sample(_ index: Int) -> SIMD3<Float> {
                        let t = Float(index) / Float(pieces) * .pi
                        return hipCenter +
                            lateral * (sign * pelvisWidth * sin(t)) +
                            depthAxis * (pelvisWidth * 0.32 * cos(t)) +
                            torso * (0.085 * sin(t))
                    }
                    addThinTube(
                        start: sample(step), end: sample(step + 1),
                        radius: max(1.5, pelvisWidth * 0.07),
                        color: tint, viewport: viewport,
                        into: &vertices
                    )
                }
            }
        }
    }

    /// Sparse cranium arcs are shown ONLY when both ear landmarks are
    /// confidently observed. No hidden face/cranial bone locations are
    /// inferred from absent keypoints.
    private static func addReferenceCranium(
        snapshot: PoseSnapshot, viewport: CGSize, opacity: Float,
        into vertices: inout [BoneMeshVertex]
    ) {
        guard let left = sourcePoint(
            index: 7, snapshot: snapshot, viewport: viewport
        ), let right = sourcePoint(
            index: 8, snapshot: snapshot, viewport: viewport
        ), let shoulderLeft = sourcePoint(
            index: 11, snapshot: snapshot, viewport: viewport
        ), let shoulderRight = sourcePoint(
            index: 12, snapshot: snapshot, viewport: viewport
        ), let hipLeft = sourcePoint(
            index: 23, snapshot: snapshot, viewport: viewport
        ), let hipRight = sourcePoint(
            index: 24, snapshot: snapshot, viewport: viewport
        ) else { return }
        let span = right - left
        let earSpan = simd_length(span)
        let shoulderCenter = (shoulderLeft + shoulderRight) * 0.5
        let hipCenter = (hipLeft + hipRight) * 0.5
        let torso = hipCenter - shoulderCenter
        guard earSpan > 16, earSpan < 400, earSpan.isFinite,
              simd_length(torso) > 15 else { return }

        let lateral = simd_normalize(span)
        let down = simd_normalize(torso)
        let depthAxis = SIMD3<Float>(0, 0, 1)
        let rx = earSpan * 0.64
        let ry = rx * 1.20
        let rz = rx * 0.70
        let center = (left + right) * 0.5 - down * ry * 0.25
        let tint = SIMD4<Float>(0.94, 0.97, 1.0, opacity * 0.41)

        for level: Float in [-0.48, 0.12, 0.65] {
            let sectionRadius = sqrt(max(0, 1 - level * level))
            let steps = 18
            for index in 0..<steps {
                func sample(_ step: Int) -> SIMD3<Float> {
                    let angle = Float(step) / Float(steps) * 2 * .pi
                    return center + down * (level * ry) +
                        lateral * (rx * sectionRadius * cos(angle)) +
                        depthAxis * (rz * sectionRadius * sin(angle))
                }
                addThinTube(
                    start: sample(index), end: sample(index + 1),
                    radius: max(1.3, rx * 0.035),
                    color: tint, viewport: viewport, into: &vertices
                )
            }
        }
    }

    /// Efficient six-sided capped-free cylinder. Compared with the full
    /// spindle it uses one ring interval per curve segment (36 vertices).
    /// A single screen-aligned light pass shades the resulting GPU mesh.
    private static func addThinTube(
        start: SIMD3<Float>, end: SIMD3<Float>, radius: Float,
        color: SIMD4<Float>, viewport: CGSize,
        into vertices: inout [BoneMeshVertex]
    ) {
        let delta = end - start
        let length = simd_length(delta)
        guard length > 0.2, length.isFinite,
              radius > 0, radius.isFinite else { return }
        let axis = delta / length
        let helper = abs(axis.z) > 0.85
            ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(0, 0, 1)
        let side = simd_cross(axis, helper)
        guard simd_length_squared(side) > 1e-6 else { return }
        let u = simd_normalize(side)
        let v = simd_normalize(simd_cross(axis, u))
        let sides = 6
        for k in 0..<sides {
            let a0 = Float(k) * 2 * .pi / Float(sides)
            let a1 = Float(k + 1) * 2 * .pi / Float(sides)
            let n0 = u * cos(a0) + v * sin(a0)
            let n1 = u * cos(a1) + v * sin(a1)
            let p0 = start + n0 * radius
            let p1 = start + n1 * radius
            let p2 = end + n0 * radius
            let p3 = end + n1 * radius
            emit(p0, n0, color, viewport, into: &vertices)
            emit(p2, n0, color, viewport, into: &vertices)
            emit(p3, n1, color, viewport, into: &vertices)
            emit(p0, n0, color, viewport, into: &vertices)
            emit(p3, n1, color, viewport, into: &vertices)
            emit(p1, n1, color, viewport, into: &vertices)
        }
    }

    private static func emit(
        _ point: SIMD3<Float>, _ normal: SIMD3<Float>,
        _ color: SIMD4<Float>, _ viewport: CGSize,
        into vertices: inout [BoneMeshVertex]
    ) {
        let w = Float(viewport.width), h = Float(viewport.height)
        let clip = SIMD4<Float>(
            2 * point.x / w - 1,
            1 - 2 * point.y / h,
            max(-0.8, min(0.8, point.z / h)),
            1
        )
        vertices.append(BoneMeshVertex(
            position: clip,
            normal: SIMD4(normal.x, -normal.y, normal.z, 0),
            color: color
        ))
    }
}

import CoreGraphics
import Foundation

/// Immutable, locally copied per-frame PERSON confidence from MediaPipe.
///
/// The SDK owns the original mask buffer only during the inference callback.
/// Never retain its pointer across threads or source frames. Copy at the same
/// moment as the matching pose/video, without saving or uploading pixels.
///
/// This is a silhouette **alpha clip**, NOT depth-based self-occlusion,
/// transparent-X-ray imaging or a guarantee of correct anatomy.
struct PersonSilhouetteMask: Sendable {
    let width: Int
    let height: Int
    let confidence: [Float]

    init?(
        width: Int, height: Int,
        confidence: [Float], sourceSize: CGSize
    ) {
        guard (1...2048).contains(width),
              (1...2048).contains(height),
              width <= 4_194_304 / height,
              confidence.count == width * height,
              sourceSize.width.isFinite, sourceSize.height.isFinite,
              sourceSize.width > 0, sourceSize.height > 0 else { return nil }

        // Never attach an incorrectly rotated, letterboxed or stretched
        // mask to a source frame. Explicit geometry mapping will be needed
        // if a future MediaPipe model returns differently shaped masks.
        let sourceAspect = sourceSize.width / sourceSize.height
        let maskAspect = CGFloat(width) / CGFloat(height)
        guard abs(maskAspect / sourceAspect - 1) <= 0.025,
              confidence.allSatisfy(\.isFinite) else { return nil }

        self.width = width
        self.height = height
        self.confidence = confidence.map { max(0, min(1, $0)) }
    }

    /// Used by deterministic crop/alignment tests. The real mask is
    /// sampled on GPU with bilinear filtering in source-image UV space.
    func confidenceAt(sourceX: Float, sourceY: Float) -> Float? {
        guard sourceX.isFinite, sourceY.isFinite,
              (0...1).contains(sourceX),
              (0...1).contains(sourceY) else { return nil }
        let x = min(width - 1, Int(sourceX * Float(width)))
        let y = min(height - 1, Int(sourceY * Float(height)))
        return confidence[y * width + x]
    }

    /// Explicit source UV from a DISPLAY normalized coordinate, shared
    /// with the video's aspect-fill bounds and masked bone shader.
    static func sourceUV(
        displayX: Float, displayY: Float,
        crop: SIMD4<Float>
    ) -> SIMD2<Float>? {
        guard [displayX, displayY, crop.x, crop.y, crop.z, crop.w]
            .allSatisfy(\.isFinite),
              (0...1).contains(displayX),
              (0...1).contains(displayY),
              crop.z > crop.x, crop.w > crop.y,
              crop.x >= 0, crop.y >= 0,
              crop.z <= 1, crop.w <= 1 else { return nil }
        return SIMD2(
            crop.x + displayX * (crop.z - crop.x),
            crop.y + displayY * (crop.w - crop.y)
        )
    }
}

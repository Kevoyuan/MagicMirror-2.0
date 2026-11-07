import CoreGraphics
import simd

/// Coordinates of the visible (aspectFill-cropped) BGRA source image.
/// x/y values are normalized texture coordinates, top-left origin:
/// (u0,v0,u1,v1), in the SAME portrait orientation as MediaPipe input.
///
/// A Metal camera quad and an overlaid pose share one exact captured
/// pixelBuffer and the same aspect-fill transform. No view-wide display
/// orientation heuristics or manual mirroring are introduced.
enum VideoAspectFillCrop {
    static func bounds(
        source: CGSize, viewport: CGSize
    ) -> SIMD4<Float>? {
        let sw = Double(source.width), sh = Double(source.height)
        let vw = Double(viewport.width), vh = Double(viewport.height)
        guard sw.isFinite, sh.isFinite, vw.isFinite, vh.isFinite,
              sw > 0, sh > 0, vw > 0, vh > 0 else { return nil }

        let scale = max(vw / sw, vh / sh)
        let renderedWidth = sw * scale
        let renderedHeight = sh * scale
        guard renderedWidth.isFinite, renderedHeight.isFinite,
              renderedWidth > 0, renderedHeight > 0 else { return nil }
        let left = (vw - renderedWidth) * 0.5
        let top = (vh - renderedHeight) * 0.5

        let u0 = (0 - left) / renderedWidth
        let v0 = (0 - top) / renderedHeight
        let u1 = (vw - left) / renderedWidth
        let v1 = (vh - top) / renderedHeight
        let values = [u0, v0, u1, v1]
        guard values.allSatisfy({ $0.isFinite && $0 >= -0.0001 && $0 <= 1.0001 })
        else { return nil }
        return SIMD4(Float(u0), Float(v0), Float(u1), Float(v1))
    }
}

import Foundation
import MediaPipeTasksVision

/// Owned copy of the ONE-person, same-timestamp MediaPipe foreground mask.
/// Task-owned mask memory must not escape the liveStream callback.
/// This is 2D subject-silhouette confidence, NOT human depth/occlusion.
struct PoseSilhouetteMask {
    enum PixelStorage {
        case uint8
        case float32

        var bytesPerPixel: Int {
            switch self {
            case .uint8: return 1
            case .float32: return 4
            }
        }
    }

    let width: Int
    let height: Int
    let storage: PixelStorage
    let pixels: Data

    init?(
        width: Int, height: Int,
        storage: PixelStorage, pixels: Data
    ) {
        guard (16...2048).contains(width),
              (16...2048).contains(height),
              width * height * storage.bytesPerPixel <= 16_777_216,
              pixels.count == width * height * storage.bytesPerPixel
        else { return nil }
        self.width = width
        self.height = height
        self.storage = storage
        self.pixels = pixels
    }

    static func copy(from mask: Mask) -> PoseSilhouetteMask? {
        guard (16...2048).contains(mask.width),
              (16...2048).contains(mask.height) else { return nil }
        let count = mask.width * mask.height
        guard count <= 4_194_304 else { return nil }

        switch mask.dataType {
        case .uInt8:
            return PoseSilhouetteMask(
                width: mask.width,
                height: mask.height,
                storage: .uint8,
                pixels: Data(bytes: mask.uint8Data, count: count)
            )
        case .float32:
            return PoseSilhouetteMask(
                width: mask.width,
                height: mask.height,
                storage: .float32,
                pixels: Data(bytes: mask.float32Data, count: count * 4)
            )
        @unknown default:
            return nil
        }
    }
}

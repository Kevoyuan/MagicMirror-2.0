import CoreGraphics
import Foundation

/// Device-local observations only. The first MVP draws a *proxy* anatomical
/// skeleton over 2D video, NOT actual internal bones or a 3D Z-Anatomy rig.
struct PosePoint: Sendable, Equatable {
    let x: CGFloat
    let y: CGFloat
    let visibility: Float

    var isUsable: Bool {
        x.isFinite && y.isFinite && visibility >= 0.55 &&
        (-0.15 ... 1.15).contains(x) && (-0.15 ... 1.15).contains(y)
    }
}

/// MediaPipe body-relative world estimate, in approximate meters.
/// It does not provide accurate camera extrinsics or actual bone coordinates.
struct PoseWorldPoint: Sendable, Equatable {
    let x: Float
    let y: Float
    let z: Float
    let visibility: Float

    var isUsable: Bool {
        x.isFinite && y.isFinite && z.isFinite && visibility >= 0.55 &&
        abs(x) < 10 && abs(y) < 10 && abs(z) < 10
    }
}

struct PoseSnapshot: Sendable {
    let timestampMilliseconds: Int
    let imageSize: CGSize
    let points: [PosePoint]
    let worldPoints: [PoseWorldPoint]
    /// Optional per-capture intrinsic matrix. Never copied from a later
    /// frame or inferred from screen dimensions.
    let cameraIntrinsics: BodyCameraIntrinsics?

    init(
        timestampMilliseconds: Int, imageSize: CGSize,
        points: [PosePoint], worldPoints: [PoseWorldPoint] = [],
        cameraIntrinsics: BodyCameraIntrinsics? = nil
    ) {
        self.timestampMilliseconds = timestampMilliseconds
        self.imageSize = imageSize
        self.points = points
        self.worldPoints = worldPoints
        self.cameraIntrinsics = cameraIntrinsics
    }

    var isUsable: Bool {
        points.count == 33 &&
        [11, 12, 23, 24].allSatisfy { points[$0].isUsable } &&
        imageSize.width > 0 && imageSize.height > 0
    }
}

struct PoseSegment: Sendable {
    let from: Int
    let to: Int
}

enum PoseSkeleton {
    /// MediaPipe 33-landmark indices, preserving anatomical left/right.
    /// These are approximate *surface joints*, not internal bone centers.
    static let segments: [PoseSegment] = [
        .init(from: 11, to: 12), .init(from: 11, to: 23),
        .init(from: 12, to: 24), .init(from: 23, to: 24),
        .init(from: 11, to: 13), .init(from: 13, to: 15),
        .init(from: 12, to: 14), .init(from: 14, to: 16),
        .init(from: 23, to: 25), .init(from: 25, to: 27),
        .init(from: 24, to: 26), .init(from: 26, to: 28),
        .init(from: 27, to: 29), .init(from: 29, to: 31),
        .init(from: 28, to: 30), .init(from: 30, to: 32)
    ]

    /// Mirrors AVCaptureVideoPreviewLayer.videoGravity = .resizeAspectFill.
    /// Inference input is a portrait-rotated unmirrored BGRA frame.
    /// Preview and overlay MUST use the exact same aspectFill crop.
    static func pointInPreview(
        _ point: PosePoint, imageSize: CGSize, viewSize: CGSize
    ) -> CGPoint? {
        guard point.isUsable, imageSize.width > 0, imageSize.height > 0,
              viewSize.width > 0, viewSize.height > 0 else {
            return nil
        }
        let scale = max(viewSize.width / imageSize.width,
                        viewSize.height / imageSize.height)
        let renderedWidth = imageSize.width * scale
        let renderedHeight = imageSize.height * scale
        return CGPoint(
            x: (viewSize.width - renderedWidth) / 2 + point.x * renderedWidth,
            y: (viewSize.height - renderedHeight) / 2 + point.y * renderedHeight
        )
    }
}

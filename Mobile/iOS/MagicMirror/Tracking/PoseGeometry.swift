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

/// A valid pose can be partially observed without a reliable torso anchor.
enum PoseCoverage: Sendable, Equatable {
    case none
    case partial
    case torsoAnchored
}

enum PoseBodyRegion: Sendable, CaseIterable {
    case torso
    case arms
    case legs
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

    /// Basic shape and capture-size validation; does not require a full body.
    var hasValidLandmarks: Bool {
        points.count == 33 &&
        imageSize.width.isFinite && imageSize.height.isFinite &&
        imageSize.width > 0 && imageSize.height > 0
    }

    /// Stronger gate for anatomy alignment and reference-pose acquisition.
    /// Never infer an unseen torso from a single visible arm or leg.
    var hasTorsoAnchor: Bool {
        hasValidLandmarks &&
        [11, 12, 23, 24].allSatisfy { points[$0].isUsable }
    }

    /// Confidence is calculated only from drawable segments in this region.
    /// Zero means there is no observed, reliable segment there.
    func confidence(for region: PoseBodyRegion) -> Float {
        guard hasValidLandmarks else { return 0 }
        let scores = PoseSkeleton.segments(for: region).compactMap { segment -> Float? in
            let a = points[segment.from]
            let b = points[segment.to]
            return a.isUsable && b.isUsable
                ? min(a.visibility, b.visibility) : nil
        }
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Float(scores.count)
    }

    var drawableSegments: [PoseSegment] {
        guard hasValidLandmarks else { return [] }
        return PoseSkeleton.segments.filter {
            points[$0.from].isUsable && points[$0.to].isUsable
        }
    }

    /// A partial skeleton is usable when at least one complete segment
    /// is reliable; confidence is still checked independently per joint.
    var isUsable: Bool {
        hasValidLandmarks && PoseSkeleton.segments.contains {
            points[$0.from].isUsable && points[$0.to].isUsable
        }
    }

    var coverage: PoseCoverage {
        guard isUsable else { return .none }
        return hasTorsoAnchor ? .torsoAnchored : .partial
    }
}

struct PoseSegment: Sendable {
    let from: Int
    let to: Int
}

enum PoseSkeleton {
    /// MediaPipe 33-landmark indices, preserving anatomical left/right.
    /// These are approximate *surface joints*, not internal bone centers.
    private static let torsoSegments: [PoseSegment] = [
        .init(from: 11, to: 12), .init(from: 11, to: 23),
        .init(from: 12, to: 24), .init(from: 23, to: 24)
    ]
    private static let armSegments: [PoseSegment] = [
        .init(from: 11, to: 13), .init(from: 13, to: 15),
        .init(from: 12, to: 14), .init(from: 14, to: 16)
    ]
    private static let legSegments: [PoseSegment] = [
        .init(from: 23, to: 25), .init(from: 25, to: 27),
        .init(from: 24, to: 26), .init(from: 26, to: 28),
        .init(from: 27, to: 29), .init(from: 29, to: 31),
        .init(from: 28, to: 30), .init(from: 30, to: 32)
    ]
    static let segments = torsoSegments + armSegments + legSegments

    static func segments(for region: PoseBodyRegion) -> [PoseSegment] {
        switch region {
        case .torso: return torsoSegments
        case .arms: return armSegments
        case .legs: return legSegments
        }
    }

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

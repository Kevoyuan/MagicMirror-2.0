import CoreGraphics
import Foundation
import simd

/// Session-local, original procedural *reference proxy* retargeting.
/// Captures a stable estimated body-world reference, then uses the native
/// two-bone IK kernel to maintain fixed reference lengths for visible
/// arm/leg pairs. It cannot detect real bones or calibrate camera extrinsics.
///
/// A successfully retargeted pose is ONLY intended for drawing geometry;
/// the original PoseSnapshot remains the authoritative camera observation.
@MainActor
struct LiveProxyRigRetargeter {
    private var capture = AnatomyReferenceCapture()
    private var lastTimestampMilliseconds = -1
    private var lastImageSize: CGSize?

    mutating func reset() {
        capture.reset()
        lastTimestampMilliseconds = -1
        lastImageSize = nil
    }

    /// Returns a pose for reference geometry on the SAME source frame.
    /// Nil means the renderer should use its existing partial-body proxy.
    /// No unseen or low-confidence joint is reconstructed.
    mutating func update(_ frame: PoseSnapshot?) -> PoseSnapshot? {
        guard let frame, frame.hasTorsoAnchor,
              frame.worldPoints.count == 33,
              frame.timestampMilliseconds > lastTimestampMilliseconds else {
            reset()
            return nil
        }
        if (lastTimestampMilliseconds >= 0 &&
            frame.timestampMilliseconds - lastTimestampMilliseconds > 350) ||
           (lastImageSize != nil && lastImageSize != frame.imageSize) {
            capture.reset()
        }
        lastTimestampMilliseconds = frame.timestampMilliseconds
        lastImageSize = frame.imageSize
        guard let reference = capture.ingest(frame),
              reference.imageSize == frame.imageSize,
              let fit = WeakPerspectiveCameraFit.estimate(
                snapshot: frame, maxP90FractionOfImageWidth: 0.045
              ) else { return nil }

        var points = frame.points
        var world = frame.worldPoints
        var solvedChains = 0
        for (proximal, joint, distal) in [
            (11, 13, 15), (12, 14, 16),
            (23, 25, 27), (24, 26, 28)
        ] {
            guard let updated = retargetChain(
                indices: (proximal, joint, distal),
                reference: reference,
                current: frame,
                fit: fit
            ) else { continue }
            points[joint] = updated.jointImage
            points[distal] = updated.distalImage
            world[joint] = updated.jointWorld
            world[distal] = updated.distalWorld
            solvedChains += 1
        }
        guard solvedChains > 0 else { return nil }

        return PoseSnapshot(
            timestampMilliseconds: frame.timestampMilliseconds,
            imageSize: frame.imageSize,
            points: points, worldPoints: world,
            cameraIntrinsics: frame.cameraIntrinsics
        )
    }

    private struct RetargetedChain {
        let jointImage: PosePoint
        let distalImage: PosePoint
        let jointWorld: PoseWorldPoint
        let distalWorld: PoseWorldPoint
    }

    private func retargetChain(
        indices: (Int, Int, Int),
        reference: PoseSnapshot,
        current: PoseSnapshot,
        fit: WeakPerspectiveCameraFit
    ) -> RetargetedChain? {
        let (rootID, jointID, endID) = indices
        for id in [rootID, jointID, endID] {
            guard reference.worldPoints[id].isUsable,
                  current.worldPoints[id].isUsable,
                  current.points[id].isUsable else { return nil }
        }
        func vector(_ point: PoseWorldPoint) -> SIMD3<Float> {
            SIMD3(point.x, point.y, point.z)
        }
        let anchor = vector(current.worldPoints[rootID])
        let middle = vector(current.worldPoints[jointID])
        let target = vector(current.worldPoints[endID])
        let restRoot = vector(reference.worldPoints[rootID])
        let restMiddle = vector(reference.worldPoints[jointID])
        let restEnd = vector(reference.worldPoints[endID])
        let upperLength = simd_length(restMiddle - restRoot)
        let lowerLength = simd_length(restEnd - restMiddle)
        guard (0.08 ... 0.95).contains(upperLength),
              (0.08 ... 0.95).contains(lowerLength),
              abs(simd_length(middle - anchor) - upperLength)
                <= 0.40 * upperLength,
              abs(simd_length(target - middle) - lowerLength)
                <= 0.40 * lowerLength,
              let solution = TwoBoneIK.solve(
                proximal: anchor,
                observedDistal: target,
                bendPole: middle,
                firstLength: upperLength,
                secondLength: lowerLength,
                minFlexionDegrees: 0,
                maxFlexionDegrees: 165
              ),
              simd_length(solution.distal - target) <= 0.10
        else { return nil }

        let width = Float(current.imageSize.width)
        let height = Float(current.imageSize.height)
        guard width > 0, height > 0 else { return nil }

        func mapped(
            _ body: SIMD3<Float>, index: Int
        ) -> (PosePoint, PoseWorldPoint)? {
            guard let pixel = fit.imagePixel(for: body),
                  pixel.x.isFinite, pixel.y.isFinite else { return nil }
            let original = current.points[index]
            let oldPixel = SIMD2<Float>(
                Float(original.x) * width,
                Float(original.y) * height
            )
            // A fit can pass global P90 yet fail at a particular joint.
            // Never snap a visibly attached proxy onto a distant fit.
            guard simd_length(pixel - oldPixel) <= 0.035 * width else {
                return nil
            }
            let image = PosePoint(
                x: CGFloat(pixel.x / width),
                y: CGFloat(pixel.y / height),
                visibility: original.visibility
            )
            let observedWorld = current.worldPoints[index]
            let projectedWorld = PoseWorldPoint(
                x: body.x, y: body.y, z: body.z,
                visibility: observedWorld.visibility
            )
            guard image.isUsable, projectedWorld.isUsable else { return nil }
            return (image, projectedWorld)
        }
        guard let (jointImage, jointWorld) = mapped(
                solution.joint, index: jointID
              ),
              let (distalImage, distalWorld) = mapped(
                solution.distal, index: endID
              ) else { return nil }
        return RetargetedChain(
            jointImage: jointImage,
            distalImage: distalImage,
            jointWorld: jointWorld,
            distalWorld: distalWorld
        )
    }
}

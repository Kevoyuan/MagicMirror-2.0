import CoreGraphics
import Foundation

/// One selected, actually observed proxy limb (never an inferred bone).
struct AnatomyReferenceSelection: Equatable {
    let fromLandmark: Int
    let toLandmark: Int
    let title: String
    let explanation: String

    func visible(in snapshot: PoseSnapshot) -> Bool {
        snapshot.hasValidLandmarks &&
        snapshot.points[fromLandmark].isUsable &&
        snapshot.points[toLandmark].isUsable
    }
}

/// Tap targets match the procedural spindle bones that really appear in
/// Metal; this never presents skin landmarks as verified anatomy.
enum AnatomyReferenceHitTester {
    private struct Entry {
        let from: Int
        let to: Int
        let title: String
        let explanation: String
        let focus: AnatomyFocus
    }

    private static let entries: [Entry] = [
        Entry(from: 11, to: 13, title: "Left upper arm",
              explanation: "An illustrative pose-linked upper-arm segment. It is not the person's measured humerus.",
              focus: .arms),
        Entry(from: 13, to: 15, title: "Left forearm",
              explanation: "Illustrative elbow-to-wrist reference. Radius and ulna are not individually reconstructed.",
              focus: .arms),
        Entry(from: 12, to: 14, title: "Right upper arm",
              explanation: "An illustrative pose-linked upper-arm segment. It is not the person's measured humerus.",
              focus: .arms),
        Entry(from: 14, to: 16, title: "Right forearm",
              explanation: "Illustrative elbow-to-wrist reference. Radius and ulna are not individually reconstructed.",
              focus: .arms),
        Entry(from: 23, to: 25, title: "Left thigh",
              explanation: "Illustrative hip-to-knee reference; the underlying femur is not visible to the camera.",
              focus: .legs),
        Entry(from: 25, to: 27, title: "Left lower leg",
              explanation: "Pose-linked knee-to-ankle reference, not a measured tibia or fibula.",
              focus: .legs),
        Entry(from: 24, to: 26, title: "Right thigh",
              explanation: "Illustrative hip-to-knee reference; the underlying femur is not visible to the camera.",
              focus: .legs),
        Entry(from: 26, to: 28, title: "Right lower leg",
              explanation: "Pose-linked knee-to-ankle reference, not a measured tibia or fibula.",
              focus: .legs),
        Entry(from: 27, to: 31, title: "Left foot reference",
              explanation: "A simplified ankle-to-foot guide. Foot bones are not individually shown.",
              focus: .legs),
        Entry(from: 28, to: 32, title: "Right foot reference",
              explanation: "A simplified ankle-to-foot guide. Foot bones are not individually shown.",
              focus: .legs),
        Entry(from: 11, to: 12, title: "Shoulder line",
              explanation: "Shoulder landmarks define a torso orientation guide, not the clavicles themselves.",
              focus: .full),
        Entry(from: 23, to: 24, title: "Pelvis line",
              explanation: "Visible hip landmarks define a proxy pelvis guide, not the actual pelvic bones.",
              focus: .full)
    ]

    static func select(
        at tap: CGPoint,
        snapshot: PoseSnapshot?,
        viewport: CGSize,
        focus: AnatomyFocus,
        maximumDistance: CGFloat = 28
    ) -> AnatomyReferenceSelection? {
        guard let snapshot,
              snapshot.hasValidLandmarks,
              viewport.width > 0, viewport.height > 0,
              tap.x.isFinite, tap.y.isFinite,
              maximumDistance.isFinite, maximumDistance > 0
        else { return nil }

        var bestDistance = maximumDistance
        var result: AnatomyReferenceSelection?
        for entry in entries {
            guard focus == .full || focus == entry.focus,
                  let start = PoseSkeleton.pointInPreview(
                    snapshot.points[entry.from],
                    imageSize: snapshot.imageSize,
                    viewSize: viewport
                  ),
                  let end = PoseSkeleton.pointInPreview(
                    snapshot.points[entry.to],
                    imageSize: snapshot.imageSize,
                    viewSize: viewport
                  )
            else { continue }

            let deltaX = end.x - start.x
            let deltaY = end.y - start.y
            let lengthSq = deltaX * deltaX + deltaY * deltaY
            guard lengthSq > 0.5 else { continue }
            let position = max(0, min(1, (
                (tap.x - start.x) * deltaX +
                (tap.y - start.y) * deltaY
            ) / lengthSq))
            let dx = tap.x - (start.x + position * deltaX)
            let dy = tap.y - (start.y + position * deltaY)
            let distance = hypot(dx, dy)
            if distance < bestDistance {
                bestDistance = distance
                result = AnatomyReferenceSelection(
                    fromLandmark: entry.from,
                    toLandmark: entry.to,
                    title: entry.title,
                    explanation: entry.explanation
                )
            }
        }
        return result
    }
}

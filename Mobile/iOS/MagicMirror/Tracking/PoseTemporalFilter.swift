import Foundation

/// Time-based joint smoothing. 80 ms half-life is a starting assumption,
/// not a measured optimal result; fast motion / identity changes still need
/// physical phone validation. Every filter update remains on the main actor.
@MainActor
struct PoseTemporalFilter {
    private var previous: PoseSnapshot?
    private let halfLifeMilliseconds: Double = 80

    mutating func reset() {
        previous = nil
    }

    mutating func apply(_ next: PoseSnapshot?) -> PoseSnapshot? {
        guard let next, next.isUsable else {
            reset()
            return nil
        }
        guard let previous,
              previous.isUsable,
              next.timestampMilliseconds > previous.timestampMilliseconds,
              next.timestampMilliseconds - previous.timestampMilliseconds < 350,
              previous.imageSize == next.imageSize else {
            self.previous = next
            return next
        }

        let dt = Double(next.timestampMilliseconds - previous.timestampMilliseconds)
        let weight = 1 - pow(0.5, dt / halfLifeMilliseconds)
        let blend = CGFloat(max(0, min(1, weight)))
        let blend3D = Float(blend)

        // Filter each reliable joint independently. An occluded joint uses
        // its current low-confidence observation, never a stale visible one.
        let points = zip(previous.points, next.points).map { old, current in
            guard old.isUsable && current.isUsable else { return current }
            return PosePoint(
                x: old.x + (current.x - old.x) * blend,
                y: old.y + (current.y - old.y) * blend,
                visibility: current.visibility
            )
        }
        let worldPoints: [PoseWorldPoint]
        if previous.worldPoints.count == 33, next.worldPoints.count == 33 {
            worldPoints = zip(previous.worldPoints, next.worldPoints).map {
                old, current in
                guard old.isUsable && current.isUsable else { return current }
                return PoseWorldPoint(
                    x: old.x + (current.x - old.x) * blend3D,
                    y: old.y + (current.y - old.y) * blend3D,
                    z: old.z + (current.z - old.z) * blend3D,
                    visibility: current.visibility
                )
            }
        } else {
            worldPoints = next.worldPoints
        }

        let result = PoseSnapshot(
            timestampMilliseconds: next.timestampMilliseconds,
            imageSize: next.imageSize,
            points: points, worldPoints: worldPoints,
            cameraIntrinsics: next.cameraIntrinsics
        )
        self.previous = result
        return result
    }
}

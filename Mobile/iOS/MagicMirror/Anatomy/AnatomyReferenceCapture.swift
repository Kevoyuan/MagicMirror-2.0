import Foundation
import simd

/// Pure on-phone reference-pose acquisition for future reviewed atlas rigs.
/// 12 consecutive stable world-landmark frames are required before motion
/// commands become eligible. No camera buffer, identity or video is stored.
/// Stable shoulders/hips are a quality gate, NOT calibrated camera extrinsics.
@MainActor
struct AnatomyReferenceCapture {
    private(set) var reference: PoseSnapshot?
    private var window: [PoseSnapshot] = []

    let requiredFrames: Int
    let maximumCoreMotionMeters: Float

    init(requiredFrames: Int = 12, maximumCoreMotionMeters: Float = 0.09) {
        precondition(requiredFrames >= 3)
        precondition(maximumCoreMotionMeters > 0)
        self.requiredFrames = requiredFrames
        self.maximumCoreMotionMeters = maximumCoreMotionMeters
    }

    mutating func reset() {
        reference = nil
        window.removeAll(keepingCapacity: true)
    }

    /// Once captured, the reference stays fixed for this session. This
    /// prevents gradual model-size or body-space drift while moving.
    @discardableResult
    mutating func ingest(_ frame: PoseSnapshot?) -> PoseSnapshot? {
        if let reference { return reference }
        guard let frame, frame.isUsable,
              frame.worldPoints.count == 33,
              [11, 12, 23, 24].allSatisfy({
                  frame.worldPoints[$0].isUsable
              }) else {
            window.removeAll(keepingCapacity: true)
            return nil
        }
        if let previous = window.last {
            if frame.timestampMilliseconds <= previous.timestampMilliseconds ||
               frame.timestampMilliseconds - previous.timestampMilliseconds > 180 ||
               frame.imageSize != previous.imageSize ||
               !coreIsStable(reference: previous, current: frame) {
                window.removeAll(keepingCapacity: true)
            }
        }
        window.append(frame)
        guard window.count >= requiredFrames else { return nil }

        var medianWorld: [PoseWorldPoint] = []
        medianWorld.reserveCapacity(33)
        for index in 0..<33 {
            let values = window.map { $0.worldPoints[index] }
            let valid = values.filter { $0.isUsable }
            guard valid.count >= requiredFrames / 2 + 1 else {
                window.removeAll(keepingCapacity: true)
                return nil
            }
            let xs = valid.map(\.x).sorted()
            let ys = valid.map(\.y).sorted()
            let zs = valid.map(\.z).sorted()
            let medianIndex = valid.count / 2
            medianWorld.append(PoseWorldPoint(
                x: xs[medianIndex], y: ys[medianIndex],
                z: zs[medianIndex],
                visibility: valid.map(\.visibility).min() ?? 0
            ))
        }
        let last = window[window.count - 1]
        reference = PoseSnapshot(
            timestampMilliseconds: last.timestampMilliseconds,
            imageSize: last.imageSize,
            points: last.points, worldPoints: medianWorld
        )
        window.removeAll(keepingCapacity: true)
        return reference
    }

    private func coreIsStable(
        reference: PoseSnapshot, current: PoseSnapshot
    ) -> Bool {
        for index in [11, 12, 23, 24] {
            let a = reference.worldPoints[index]
            let b = current.worldPoints[index]
            let delta = SIMD3(b.x - a.x, b.y - a.y, b.z - a.z)
            if !a.isUsable || !b.isUsable ||
               simd_length(delta) > maximumCoreMotionMeters {
                return false
            }
        }
        return true
    }
}

import CoreGraphics
import CoreVideo
import Foundation

/// Only used to render the camera image and its own MediaPipe result in
/// the SAME Metal drawable. The CVPixelBuffer is retained in memory only;
/// no photos, frames or health data are stored or uploaded.
struct AlignedPoseVideoFrame {
    let pose: PoseSnapshot
    let pixelBuffer: CVPixelBuffer
}

/// Bounded, session-scoped pixel buffer ownership while MediaPipe performs
/// asynchronous inference. Does not accept out-of-order timestamps, and
/// never retains more than maxPendingCount captured buffers.
///
/// This complements PoseFrameAssociationGate (metadata only). It is not
/// a substitute for measuring actual camera-to-display latency on iPhone.
final class BoundedVideoFrameStore {
    private let lock = NSLock()
    private let maxPendingCount: Int
    private let maxAgeMilliseconds: Int
    private var active = false
    private var lastCaptured = -1
    private var lastConsumed = -1
    private var frames: [Int: CVPixelBuffer] = [:]
    private var order: [Int] = []

    init(maxPendingCount: Int = 6, maxAgeMilliseconds: Int = 160) {
        precondition(maxPendingCount > 0)
        precondition(maxAgeMilliseconds > 0)
        self.maxPendingCount = maxPendingCount
        self.maxAgeMilliseconds = maxAgeMilliseconds
    }

    func reset(active: Bool) {
        lock.lock()
        defer { lock.unlock() }
        self.active = active
        lastCaptured = -1
        lastConsumed = -1
        frames.removeAll(keepingCapacity: true)
        order.removeAll(keepingCapacity: true)
    }

    @discardableResult
    func retain(
        timestampMilliseconds timestamp: Int,
        pixelBuffer: CVPixelBuffer
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard active, timestamp >= 0, timestamp > lastCaptured,
              CVPixelBufferGetWidth(pixelBuffer) > 0,
              CVPixelBufferGetHeight(pixelBuffer) > 0,
              CVPixelBufferGetPixelFormatType(pixelBuffer)
                  == kCVPixelFormatType_32BGRA else { return false }

        lastCaptured = timestamp
        frames[timestamp] = pixelBuffer
        order.append(timestamp)

        while order.count > maxPendingCount {
            frames.removeValue(forKey: order.removeFirst())
        }
        while let first = order.first,
              timestamp - first > maxAgeMilliseconds {
            frames.removeValue(forKey: order.removeFirst())
        }
        return true
    }

    /// Removes all older images after matching. A late callback can never
    /// display a frame whose memory has already been evicted/reused.
    func take(timestampMilliseconds timestamp: Int) -> CVPixelBuffer? {
        lock.lock()
        defer { lock.unlock() }
        guard active, timestamp > lastConsumed,
              lastCaptured >= timestamp,
              lastCaptured - timestamp <= maxAgeMilliseconds,
              let buffer = frames[timestamp] else { return nil }

        lastConsumed = timestamp
        while let first = order.first, first <= timestamp {
            frames.removeValue(forKey: order.removeFirst())
        }
        return buffer
    }
}

import CoreGraphics
import Foundation

struct PoseFrameMetadata: Sendable {
    let imageSize: CGSize
    let intrinsics: BodyCameraIntrinsics?
}

/// Binds a MediaPipe asynchronous result to the exact *capture metadata*
/// of the submitted AVFoundation frame. This is deliberately NOT a copy
/// of any pixel buffer or an assertion that AVCaptureVideoPreviewLayer has
/// rendered exactly that frame on screen.
///
/// Thread-safe: capture callback, MediaPipe callback and session lifecycle
/// can run on different queues. A reset invalidates previous pending frames.
final class PoseFrameAssociationGate {
    private let lock = NSLock()
    private let maximumResultAgeMilliseconds: Int
    private let maximumPendingCount: Int

    private var active = false
    private var latestCapturedTimestamp = -1
    private var lastConsumedTimestamp = -1
    private var frameMetadata: [Int: PoseFrameMetadata] = [:]
    private var pendingOrder: [Int] = []

    init(maximumResultAgeMilliseconds: Int = 160, maximumPendingCount: Int = 12) {
        precondition(maximumResultAgeMilliseconds > 0)
        precondition(maximumPendingCount > 0)
        self.maximumResultAgeMilliseconds = maximumResultAgeMilliseconds
        self.maximumPendingCount = maximumPendingCount
    }

    /// Call on every session start/stop. Clearing the timestamp map makes
    /// any late callback from a stopped camera session unpublishable.
    func reset(active: Bool) {
        lock.lock()
        defer { lock.unlock() }
        self.active = active
        latestCapturedTimestamp = -1
        lastConsumedTimestamp = -1
        frameMetadata.removeAll(keepingCapacity: true)
        pendingOrder.removeAll(keepingCapacity: true)
    }

    /// Registers only monotonically increasing, unmirrored capture-frame
    /// metadata. Never stores image pixels or camera images in memory.
    @discardableResult
    func register(
        timestampMilliseconds: Int, imageSize: CGSize,
        intrinsics: BodyCameraIntrinsics? = nil
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard active, timestampMilliseconds >= 0,
              timestampMilliseconds > latestCapturedTimestamp,
              imageSize.width.isFinite, imageSize.height.isFinite,
              imageSize.width > 0, imageSize.height > 0 else {
            return false
        }
        latestCapturedTimestamp = timestampMilliseconds
        frameMetadata[timestampMilliseconds] = PoseFrameMetadata(
            imageSize: imageSize,
            intrinsics: intrinsics?.matches(image: imageSize) == true
                ? intrinsics : nil
        )
        pendingOrder.append(timestampMilliseconds)

        // The MediaPipe LIVE_STREAM queue must never grow without bound.
        // If inference falls behind, old frames are no longer eligible.
        while pendingOrder.count > maximumPendingCount {
            let expired = pendingOrder.removeFirst()
            frameMetadata.removeValue(forKey: expired)
        }
        while let first = pendingOrder.first,
              timestampMilliseconds - first > maximumResultAgeMilliseconds {
            pendingOrder.removeFirst()
            frameMetadata.removeValue(forKey: first)
        }
        return true
    }

    /// Returns dimensions from THAT frame, not the most recent frame's
    /// dimensions. Out-of-order, stale, replayed or previously dropped
    /// results are ignored even if their 33 landmark values look plausible.
    func consume(timestampMilliseconds: Int) -> CGSize? {
        consumeMetadata(timestampMilliseconds: timestampMilliseconds)?.imageSize
    }

    /// Exact frame dimensions AND optional camera intrinsics.
    func consumeMetadata(timestampMilliseconds: Int) -> PoseFrameMetadata? {
        lock.lock()
        defer { lock.unlock() }

        guard active,
              timestampMilliseconds > lastConsumedTimestamp,
              latestCapturedTimestamp >= timestampMilliseconds,
              latestCapturedTimestamp - timestampMilliseconds
                  <= maximumResultAgeMilliseconds,
              let metadata = frameMetadata[timestampMilliseconds] else {
            return nil
        }
        lastConsumedTimestamp = timestampMilliseconds
        while let first = pendingOrder.first,
              first <= timestampMilliseconds {
            pendingOrder.removeFirst()
            frameMetadata.removeValue(forKey: first)
        }
        return metadata
    }
}

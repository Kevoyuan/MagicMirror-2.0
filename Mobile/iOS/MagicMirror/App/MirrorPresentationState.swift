import Foundation

/// Pure UI state: never treat a camera session or an old pose as a current
/// detection. Separate from the per-frame tracking and renderer pipeline.
enum MirrorPresentationState: Equatable {
    case preparing
    case cameraAccess
    case searching
    case partial
    case tracking
    case paused
    case permissionDenied
    case unavailable(String)

    init(phase: MirrorPhase, coverage: PoseCoverage, isPaused: Bool) {
        // Camera permission and lifecycle outrank the user's overlay-pause
        // preference. Otherwise a revoked permission could look "PAUSED" and
        // hide the only Settings recovery path.
        switch phase {
        case .idle:
            self = .preparing
            return
        case .permissionRequested:
            self = .cameraAccess
            return
        case .permissionDenied:
            self = .permissionDenied
            return
        case .unavailable(let message):
            self = .unavailable(message)
            return
        case .searching, .partialTracking, .tracking:
            break
        }
        if isPaused {
            self = .paused
            return
        }
        switch coverage {
        case .none: self = .searching
        case .partial: self = .partial
        case .torsoAnchored: self = .tracking
        }
    }

    var statusTitle: String {
        switch self {
        case .preparing: return "PREPARING"
        case .cameraAccess: return "CAMERA ACCESS"
        case .searching: return "SEARCHING"
        case .partial: return "PARTIAL"
        case .tracking: return "TRACKING"
        case .paused: return "PAUSED"
        case .permissionDenied: return "CAMERA OFF"
        case .unavailable: return "INTERRUPTED"
        }
    }

    var statusSymbol: String {
        switch self {
        case .preparing, .cameraAccess: return "camera"
        case .searching: return "viewfinder"
        case .partial, .tracking: return "figure.stand"
        case .paused: return "pause.circle"
        case .permissionDenied, .unavailable:
            return "exclamationmark.circle"
        }
    }

    /// No guidance over an already identified person. A dismissed pose
    /// immediately falls back to searching, regardless of stale phase text.
    var guidance: String? {
        switch self {
        case .preparing:
            return "Preparing your camera…"
        case .cameraAccess:
            return "Allow camera access to explore reference anatomy."
        case .searching:
            return "Point at one person. Show shoulders or a visible limb."
        case .partial:
            return "A partial reference is visible. Move back for more coverage."
        case .tracking:
            return nil
        case .paused:
            return "Overlay paused. Camera preview remains active."
        case .permissionDenied:
            return "Camera permission is off. You can enable it in iOS Settings."
        case .unavailable(let message):
            return message.isEmpty
                ? "Camera temporarily unavailable. Try reopening the app."
                : message
        }
    }

    var canOpenCameraSettings: Bool {
        if case .permissionDenied = self { return true }
        return false
    }
}

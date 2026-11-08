import Foundation

/// UI-only interpretation of the current registered resource gate.
/// A requested but unregistered system must NEVER look enabled while
/// the camera still displays the fallback reference proxy.
struct AnatomyLayerPresentation: Equatable {
    let available: Bool
    let selected: Bool

    init(
        layer: AnatomyDisplayLayer,
        enabled: Set<AnatomyDisplayLayer>,
        ready: Set<AnatomyDisplayLayer>
    ) {
        let activeSystems = enabled.intersection(ready)
        if layer == .referenceProxy {
            available = true
            selected = activeSystems.isEmpty
        } else {
            available = ready.contains(layer)
            selected = activeSystems.contains(layer)
        }
    }

    /// Only an independently registered system may become the sole displayed
    /// anatomy layer. The proxy is a separate explicit clear/reset action.
    static func soloSelection(
        for layer: AnatomyDisplayLayer,
        ready: Set<AnatomyDisplayLayer>
    ) -> Set<AnatomyDisplayLayer>? {
        guard layer != .referenceProxy, ready.contains(layer) else {
            return nil
        }
        return [layer]
    }

    var statusKey: String {
        available ? (selected ? "SELECTED" : "READY") : "LOCKED"
    }
}

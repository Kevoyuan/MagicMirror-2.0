import Foundation

/// Each visible atlas remains a distinct approved source asset, rig and
/// skinning set. One camera frame may draw several verified systems;
/// no fallback proxy is mislabeled as a muscle, organ or nerve.
struct ReviewedSkinnedLayerFrame {
    let layer: AnatomyDisplayLayer
    let batch: SkinnedAtlasDrawBatch
}

/// A separately reviewed source layer without audited four-weight
/// skinning can still appear as its rigid reference mesh.
struct ReviewedRigidLayerFrame {
    let layer: AnatomyDisplayLayer
    let batch: CalibratedAtlasDrawBatch
}

/// Pure selection policy; user intent survives temporary tracking loss.
/// Availability is still checked on every new camera frame by the
/// separately source- and calibration-gated atlas runtime.
enum AnatomyLayerVisibilityPolicy {
    static func toggled(
        layer: AnatomyDisplayLayer,
        ready: Set<AnatomyDisplayLayer>,
        visible: Set<AnatomyDisplayLayer>
    ) -> Set<AnatomyDisplayLayer> {
        if layer == .referenceProxy { return [] }
        guard ready.contains(layer) else { return visible }
        var updated = visible
        if !updated.insert(layer).inserted {
            updated.remove(layer)
        }
        return updated
    }

    static func primary(
        preferred: AnatomyDisplayLayer,
        visible: Set<AnatomyDisplayLayer>
    ) -> AnatomyDisplayLayer {
        if visible.contains(preferred) { return preferred }
        return AnatomyDisplayLayer.allCases.first {
            visible.contains($0)
        } ?? .referenceProxy
    }
}

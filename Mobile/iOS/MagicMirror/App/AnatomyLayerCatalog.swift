import Foundation

/// Product-facing availability, deliberately separate from anatomical
/// rendering capabilities. No unreviewed asset or medical layer is unlocked.
enum AnatomyDisplayLayer: String, CaseIterable, Identifiable {
    case referenceProxy
    case skeleton
    case muscles
    case organs
    case vessels
    case nerves
    case joints

    var id: String { rawValue }

    var title: String {
        switch self {
        case .referenceProxy: return "Reference proxy"
        case .skeleton: return "Anatomical skeleton"
        case .muscles: return "Muscles"
        case .organs: return "Organs"
        case .vessels: return "Blood vessels"
        case .nerves: return "Nerves"
        case .joints: return "Joints & ligaments"
        }
    }

    var isAvailable: Bool { self == .referenceProxy }

    var detail: String {
        switch self {
        case .referenceProxy:
            return "Illustrative geometry from visible pose landmarks"
        default:
            return "Requires reviewed, licensed and registered 3D anatomy"
        }
    }
}

enum AnatomySectionPlane: String, CaseIterable, Identifiable {
    case axial
    case sagittal
    case coronal

    var id: String { rawValue }
    var title: String {
        switch self {
        case .axial: return "Axial"
        case .sagittal: return "Sagittal"
        case .coronal: return "Coronal"
        }
    }

    /// True clipping/capping of reviewed registered anatomy is not present.
    var isAvailable: Bool { false }
}

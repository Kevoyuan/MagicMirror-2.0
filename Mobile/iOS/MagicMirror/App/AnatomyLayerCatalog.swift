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

    /// Explicit offline source prefix. Each system has its own verified
    /// MMATLAS1, USDZ hierarchy and, optionally, skinning weights.
    /// No generic skeleton asset is passed off as muscle/organ anatomy.
    var resourceBaseName: String? {
        switch self {
        case .referenceProxy: return nil
        case .skeleton: return "skeleton_atlas"
        case .muscles: return "muscles_atlas"
        case .organs: return "organs_atlas"
        case .vessels: return "vessels_atlas"
        case .nerves: return "nerves_atlas"
        case .joints: return "joints_atlas"
        }
    }

    var hierarchyManifestName: String? {
        guard let resourceBaseName else { return nil }
        return self == .skeleton
            ? "anatomy_atlas_manifest"
            : "\(resourceBaseName)_manifest"
    }

    /// Static availability describes this repository's distributed assets.
    /// Runtime switches use a separate independently verified resource gate.
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

    /// No reviewed GPU-skinned atlas is bundled. The live section sheet
    /// uses MirrorViewModel.canSectionReviewedAtlas for runtime unlocking;
    /// this static product-catalog flag remains disabled by default.
    var isAvailable: Bool { false }
}

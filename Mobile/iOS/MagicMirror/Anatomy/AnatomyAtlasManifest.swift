import CryptoKit
import Foundation
import simd

/// Reviewed skeletal-mesh provenance. This manifest is a gate to connecting
/// a future, bundled USDZ/glTF-derived native atlas to the phone renderer.
/// The original FBX is NOT embedded, fetched or redistributed here.
///
/// A manifest saying "reviewed" is a human approval record, not evidence of
/// ownership or licensing; release still requires the recorded attribution
/// and copyright/share-alike obligations to be independently checked.
struct AnatomyAtlasManifest: Codable {
    struct BoneBinding: Codable {
        let id: String
        let nodePath: String
        let parentId: String?
        let proximalLandmark: Int
        let distalLandmark: Int
        let restStart: [Float]
        let restEnd: [Float]
        let anchorsReviewed: Bool

        var restStartPoint: SIMD3<Float>? { Self.vector(restStart) }
        var restEndPoint: SIMD3<Float>? { Self.vector(restEnd) }

        private static func vector(_ array: [Float]) -> SIMD3<Float>? {
            guard array.count == 3,
                  array.allSatisfy({ $0.isFinite && abs($0) < 10_000 }) else {
                return nil
            }
            return SIMD3(array[0], array[1], array[2])
        }
    }

    let atlasId: String
    let sourceURL: String
    let sourceRevision: String
    let attribution: String
    let licenseIdentifier: String
    let assetFilename: String
    let assetSHA256: String
    let licenseReviewed: Bool
    let anatomyReviewed: Bool
    let bones: [BoneBinding]

    enum ValidationError: Error, Equatable {
        case missingProvenance
        case missingReview
        case unsafeAssetPath
        case invalidDigest
        case emptyOrInvalidBones
        case duplicateBoneId
        case duplicateNodePath
        case unknownParent
        case cyclicHierarchy
        case unreviewedAnchors
        case invalidRestGeometry
    }

    /// Validate metadata BEFORE checking the installed binary. Never
    /// automatically mark a candidate as anatomically or legally reviewed.
    func validateForUse() throws {
        guard !atlasId.isEmpty, !sourceURL.isEmpty,
              !sourceRevision.isEmpty, !attribution.isEmpty,
              !licenseIdentifier.isEmpty else {
            throw ValidationError.missingProvenance
        }
        guard licenseReviewed && anatomyReviewed else {
            throw ValidationError.missingReview
        }
        guard !assetFilename.isEmpty, !assetFilename.contains("/"),
              !assetFilename.contains("\\"),
              !assetFilename.contains(".."),
              assetFilename.hasSuffix(".usdz") else {
            throw ValidationError.unsafeAssetPath
        }
        guard assetSHA256.count == 64,
              assetSHA256.utf8.allSatisfy({
                  (48...57).contains($0) || (97...102).contains($0)
              }) else {
            throw ValidationError.invalidDigest
        }
        guard !bones.isEmpty else {
            throw ValidationError.emptyOrInvalidBones
        }
        var ids = Set<String>()
        var paths = Set<String>()
        for bone in bones {
            guard !bone.id.isEmpty,
                  (0..<33).contains(bone.proximalLandmark),
                  (0..<33).contains(bone.distalLandmark),
                  bone.proximalLandmark != bone.distalLandmark,
                  !bone.nodePath.isEmpty,
                  !bone.nodePath.hasPrefix("/"),
                  !bone.nodePath.contains("..") else {
                throw ValidationError.emptyOrInvalidBones
            }
            guard ids.insert(bone.id).inserted else {
                throw ValidationError.duplicateBoneId
            }
            guard paths.insert(bone.nodePath).inserted else {
                throw ValidationError.duplicateNodePath
            }
            guard bone.anchorsReviewed else {
                throw ValidationError.unreviewedAnchors
            }
            guard let start = bone.restStartPoint,
                  let end = bone.restEndPoint,
                  simd_length_squared(end - start) > 1e-8 else {
                throw ValidationError.invalidRestGeometry
            }
        }
        let lookup = Dictionary(uniqueKeysWithValues: bones.map { ($0.id, $0) })
        for bone in bones {
            if let parent = bone.parentId {
                guard parent != bone.id, lookup[parent] != nil else {
                    throw ValidationError.unknownParent
                }
            }
            var seen: Set<String> = [bone.id]
            var parent = bone.parentId
            while let next = parent {
                guard seen.insert(next).inserted else {
                    throw ValidationError.cyclicHierarchy
                }
                parent = lookup[next]?.parentId
            }
        }
    }
}

enum AnatomyAtlasStore {
    enum LoadingError: Error {
        case manifestMissing
        case assetMissing
        case checksumMismatch
    }

    /// No network, no dynamic downloads. The only valid runtime atlas is an
    /// explicitly reviewed resource bundled into the installed application.
    static func loadApproved(
        manifestName: String = "anatomy_atlas_manifest",
        bundle: Bundle = .main
    ) throws -> (manifest: AnatomyAtlasManifest, resourceURL: URL) {
        guard let manifestURL = bundle.url(
            forResource: manifestName, withExtension: "json"
        ) else { throw LoadingError.manifestMissing }
        let raw = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(
            AnatomyAtlasManifest.self, from: raw
        )
        try manifest.validateForUse()
        guard let assetURL = bundle.url(
            forResource: (manifest.assetFilename as NSString).deletingPathExtension,
            withExtension: "usdz"
        ) else { throw LoadingError.assetMissing }
        let binary = try Data(contentsOf: assetURL)
        let digest = SHA256.hash(data: binary)
            .map { String(format: "%02x", $0) }.joined()
        guard digest == manifest.assetSHA256 else {
            throw LoadingError.checksumMismatch
        }
        return (manifest, assetURL)
    }
}

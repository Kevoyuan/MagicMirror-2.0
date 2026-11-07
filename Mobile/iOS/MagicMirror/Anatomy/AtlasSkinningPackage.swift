import Foundation

/// Optional developer-authored, individually reviewed MMATLAS1 skinning
/// bindings. No file is provided by the repository. Any supplied file
/// must match the exact binary hash and the approved hierarchy bone IDs.
/// This is never generated from proximity or unreviewed object names.
struct ReviewedAtlasSkinningFile: Decodable {
    struct Vertex: Decodable {
        let boneIds: [String]
        let weights: [Float]
    }

    let schemaVersion: Int
    let sourceRevision: String
    let modelSHA256: String
    let reviewedJointWeights: Bool
    let vertices: [Vertex]
}

enum AtlasSkinningPackage {
    enum Failure: Error {
        case malformed
        case missing
    }

    static func load(
        bundle: Bundle = .main,
        atlas: VerifiedAnatomyAtlas,
        hierarchy: AnatomyAtlasManifest
    ) throws -> [AtlasSkinInfluence]? {
        guard let url = bundle.url(
            forResource: "skeleton_atlas.skinning", withExtension: "json"
        ) else { return nil }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count <= 32_000_000 else { throw Failure.malformed }
        let skin = try JSONDecoder().decode(
            ReviewedAtlasSkinningFile.self, from: data
        )
        return try validate(
            skin, atlas: atlas, hierarchy: hierarchy
        )
    }

    static func validate(
        _ file: ReviewedAtlasSkinningFile,
        atlas: VerifiedAnatomyAtlas,
        hierarchy: AnatomyAtlasManifest
    ) throws -> [AtlasSkinInfluence] {
        guard (try? hierarchy.validateForUse()) != nil,
              file.schemaVersion == 1,
              file.reviewedJointWeights,
              file.sourceRevision == atlas.manifest.sourceRevision,
              file.sourceRevision == hierarchy.sourceRevision,
              file.modelSHA256 == atlas.manifest.modelSHA256,
              file.vertices.count == atlas.vertices.count,
              !file.vertices.isEmpty,
              hierarchy.bones.count <= 256 else { throw Failure.malformed }

        var ids: [String: UInt32] = [:]
        for (index, bone) in hierarchy.bones.enumerated() {
            guard ids.updateValue(UInt32(index), forKey: bone.id) == nil
            else { throw Failure.malformed }
        }
        var result: [AtlasSkinInfluence] = []
        result.reserveCapacity(file.vertices.count)
        for vertex in file.vertices {
            guard vertex.boneIds.count == 4,
                  vertex.weights.count == 4 else { throw Failure.malformed }
            var index = SIMD4<UInt32>(repeating: 0)
            var weight = SIMD4<Float>(repeating: 0)
            for slot in 0..<4 {
                guard let joint = ids[vertex.boneIds[slot]]
                else { throw Failure.malformed }
                index[slot] = joint
                weight[slot] = vertex.weights[slot]
            }
            let influence = AtlasSkinInfluence(
                joints: index, weights: weight
            )
            guard influence.isValid(boneCount: ids.count)
            else { throw Failure.malformed }
            result.append(influence)
        }
        return result
    }
}

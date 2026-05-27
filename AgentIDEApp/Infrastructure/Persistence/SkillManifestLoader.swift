import Foundation

final class SkillManifestLoader {
    private let decoder = JSONDecoder()

    func load(from data: Data) throws -> [SkillManifest] {
        if let manifests = try? decoder.decode([SkillManifest].self, from: data) {
            return manifests
        }
        return [try decoder.decode(SkillManifest.self, from: data)]
    }
}

import XCTest
@testable import AgentIDEApp

final class SkillManifestLoaderTests: XCTestCase {
    func testLoadsManifestArray() throws {
        let json = """
        [
          {
            "id": "s1",
            "name": "Skill 1",
            "version": "1.0.0",
            "triggers": [{ "type": "keyword", "value": "fix" }],
            "tools": ["workspace_read"],
            "promptTemplate": "test",
            "permissions": ["workspace.read"]
          }
        ]
        """
        let loader = SkillManifestLoader()
        let manifests = try loader.load(from: Data(json.utf8))
        XCTAssertEqual(manifests.count, 1)
        XCTAssertEqual(manifests.first?.id, "s1")
    }
}

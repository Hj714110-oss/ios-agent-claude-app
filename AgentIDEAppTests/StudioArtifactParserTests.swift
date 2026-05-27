import XCTest
@testable import AgentIDEApp

final class StudioArtifactParserTests: XCTestCase {
    func testStudioRequestSupportsM15Fields() {
        let request = StudioRequest(
            mode: .codeGeneration,
            prompt: "Generate view",
            platform: "iOS",
            language: "Swift",
            systemPromptPreset: "mobile",
            targetFiles: ["Views/Home.swift"],
            outputContractVersion: "v1"
        )
        XCTAssertEqual(request.outputContractVersion, "v1")
        XCTAssertEqual(request.targetFiles?.first, "Views/Home.swift")
    }

    func testStudioArtifactCarriesApplyFields() {
        let artifact = StudioArtifact(
            id: UUID(),
            kind: .code,
            title: "Home Screen",
            content: "struct Home: View {}",
            targetPath: "Views/Home.swift",
            language: "swift",
            applyHint: "replace file"
        )
        XCTAssertEqual(artifact.targetPath, "Views/Home.swift")
        XCTAssertEqual(artifact.applyHint, "replace file")
    }
}

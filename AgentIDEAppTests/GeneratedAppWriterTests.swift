import XCTest
@testable import AgentIDEApp

final class GeneratedAppWriterTests: XCTestCase {
    func testGenerateWritesUnderGeneratedAppsSubdirectory() throws {
        let service = WorkspaceWriteServiceImpl()
        let writer = GeneratedAppWriterImpl(writeService: service)
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let artifacts = [
            StudioArtifact(
                id: UUID(),
                kind: .code,
                title: "Main",
                content: "print('hello')\n",
                targetPath: "Sources/main.py",
                language: "python",
                applyHint: "create"
            )
        ]

        let summary = writer.generate(workspaceRoot: rootURL.path, appName: "Demo App", artifacts: artifacts)
        XCTAssertEqual(summary.appliedFiles, 1)
        XCTAssertTrue(summary.outputPath.contains("GeneratedApps"))
    }
}

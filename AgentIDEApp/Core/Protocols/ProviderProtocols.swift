import Foundation

protocol LLMProvider {
    func stream(messages: [ChatMessage], tools: [ToolSpec]) -> AsyncThrowingStream<LLMEvent, Error>
}

protocol ExecutionProvider {
    func run(request: RunRequest) async -> RunResult
}

protocol WorkspaceProvider {
    func listFiles(at path: String) throws -> [WorkspaceFile]
    func readFile(at path: String) throws -> String
    func writeFile(at path: String, content: String) throws
    func search(in root: String, query: String) throws -> [String]
}

protocol GitProvider {
    func status(at root: String) throws -> [String]
    func diff(at root: String, filePath: String?) throws -> String
    func commit(at root: String, message: String) throws
}

protocol SecretStore {
    func set(_ value: String, for key: String) throws
    func get(_ key: String) throws -> String?
}

protocol StudioGenerationProvider {
    func stream(request: StudioRequest) -> AsyncThrowingStream<StudioEvent, Error>
}

protocol WorkspaceWriteService {
    func previewWrite(root: String, targetPath: String, newContent: String) throws -> WritePreview
    func applyWrite(root: String, preview: WritePreview) throws
    func rollbackLast() throws
}

protocol GeneratedAppWriter {
    func generate(
        workspaceRoot: String,
        appName: String,
        artifacts: [StudioArtifact]
    ) -> GeneratedAppSummary
}

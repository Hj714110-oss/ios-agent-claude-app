import Foundation

final class StudioGenerationProviderImpl: StudioGenerationProvider {
    private let client: OpenAIStreamingClient
    private let configProvider: () -> OpenAIServiceConfig
    private let apiKeyProvider: () -> String

    init(
        client: OpenAIStreamingClient = OpenAIStreamingClient(),
        configProvider: @escaping () -> OpenAIServiceConfig,
        apiKeyProvider: @escaping () -> String
    ) {
        self.client = client
        self.configProvider = configProvider
        self.apiKeyProvider = apiKeyProvider
    }

    func stream(request: StudioRequest) -> AsyncThrowingStream<StudioEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    continuation.yield(.marker("studio.start"))
                    let streamPrompt = Self.contractPrompt(for: request)
                    let messages = [
                        ["role": "system", "content": streamPrompt.system],
                        ["role": "user", "content": streamPrompt.user]
                    ]
                    let config = configProvider()
                    let apiKey = apiKeyProvider()
                    var buffer = ""

                    for try await token in client.streamChatCompletions(
                        config: config,
                        apiKey: apiKey,
                        messages: messages
                    ) {
                        continuation.yield(.token(token))
                        buffer += token
                    }

                    let artifacts = Self.parseArtifacts(from: buffer)
                    if artifacts.isEmpty {
                        continuation.yield(.error("No structured artifacts parsed from model output."))
                    } else {
                        continuation.yield(.marker("studio.artifacts"))
                        for artifact in artifacts {
                            continuation.yield(.artifact(artifact))
                        }
                    }

                    continuation.yield(.completed)
                    continuation.finish()
                } catch {
                    continuation.yield(.error(error.localizedDescription))
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private static func contractPrompt(for request: StudioRequest) -> (system: String, user: String) {
        let modeGuide: String
        switch request.mode {
        case .designSketch:
            modeGuide = "Output design structure and component hierarchy."
        case .codeGeneration:
            modeGuide = "Output implementation-ready code artifacts."
        case .fullApp:
            modeGuide = "Output multi-file app blueprint artifacts."
        }
        let userPreset = request.systemPromptPreset ?? ""
        let persona = parsePresetValue(userPreset, key: "persona") ?? "General Creative Engineer"
        let customSystem = parsePresetValue(userPreset, key: "custom_system")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let baseSystem = customSystem.isEmpty ? "You are \(persona)." : customSystem
        let system = """
        \(baseSystem)
        Return content using strict artifact blocks:
        <<<ARTIFACT
        kind: markdown|code|plan|patch
        title: <short title>
        path: <optional relative path>
        language: <optional language>
        apply_hint: <optional apply hint>
        ---
        <content>
        >>>ARTIFACT
        No extra prose outside blocks.
        """
        let user = """
        Mode: \(request.mode.rawValue)
        Platform: \(request.platform)
        Language: \(request.language)
        Contract: \(request.outputContractVersion ?? "v1")
        Target Files: \((request.targetFiles ?? []).joined(separator: ", "))
        Preset: \(userPreset)
        Task:
        \(request.prompt)
        \(modeGuide)
        """
        return (system, user)
    }

    private static func parsePresetValue(_ preset: String, key: String) -> String? {
        let lines = preset.split(separator: "\n").map(String.init)
        for line in lines {
            let pair = line.split(separator: "=", maxSplits: 1).map(String.init)
            if pair.count == 2 && pair[0].trimmingCharacters(in: .whitespacesAndNewlines) == key {
                return pair[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private static func parseArtifacts(from fullText: String) -> [StudioArtifact] {
        let startTag = "<<<ARTIFACT"
        let endTag = ">>>ARTIFACT"
        var cursor = fullText.startIndex
        var artifacts: [StudioArtifact] = []

        while let startRange = fullText.range(of: startTag, range: cursor..<fullText.endIndex) {
            guard let endRange = fullText.range(of: endTag, range: startRange.upperBound..<fullText.endIndex) else {
                break
            }
            let body = String(fullText[startRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if let artifact = parseSingleArtifact(body: body) {
                artifacts.append(artifact)
            }
            cursor = endRange.upperBound
        }
        return artifacts
    }

    private static func parseSingleArtifact(body: String) -> StudioArtifact? {
        let parts = body.components(separatedBy: "\n---\n")
        guard parts.count >= 2 else { return nil }
        let headerLines = parts[0].split(separator: "\n").map(String.init)
        let content = parts.dropFirst().joined(separator: "\n---\n").trimmingCharacters(in: .whitespacesAndNewlines)

        var dict: [String: String] = [:]
        for line in headerLines {
            let pair = line.split(separator: ":", maxSplits: 1).map(String.init)
            if pair.count == 2 {
                dict[pair[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] =
                    pair[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        let kind = StudioArtifact.Kind(rawValue: dict["kind"]?.lowercased() ?? "markdown") ?? .markdown
        let title = dict["title"] ?? "Untitled Artifact"
        return StudioArtifact(
            id: UUID(),
            kind: kind,
            title: title,
            content: content,
            targetPath: dict["path"],
            language: dict["language"],
            applyHint: dict["apply_hint"]
        )
    }
}

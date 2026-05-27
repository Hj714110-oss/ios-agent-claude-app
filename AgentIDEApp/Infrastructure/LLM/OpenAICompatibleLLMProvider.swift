import Foundation

struct OpenAICompatibleConfig {
    let service: OpenAIServiceConfig
    let apiKey: String
}

final class OpenAICompatibleLLMProvider: LLMProvider {
    private let configProvider: () -> OpenAICompatibleConfig
    private let client: OpenAIStreamingClient

    init(
        configProvider: @escaping () -> OpenAICompatibleConfig,
        client: OpenAIStreamingClient = OpenAIStreamingClient()
    ) {
        self.configProvider = configProvider
        self.client = client
    }

    func stream(messages: [ChatMessage], tools: [ToolSpec]) -> AsyncThrowingStream<LLMEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let config = configProvider()
                let systemPrompt = config.service.customSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalSystem = systemPrompt.isEmpty
                    ? "You are \(config.service.personaName)."
                    : systemPrompt
                var wireMessages = [[String: String]]()
                wireMessages.append(["role": "system", "content": finalSystem])
                wireMessages.append(contentsOf: messages.map { ["role": $0.role.rawValue, "content": $0.content] })
                do {
                    for try await token in client.streamChatCompletions(
                        config: config.service,
                        apiKey: config.apiKey,
                        messages: wireMessages
                    ) {
                        continuation.yield(.token(token))
                    }
                    if !tools.isEmpty {
                        continuation.yield(.toolCall(name: tools[0].name, payload: "{\"reason\":\"selected\"}"))
                    }
                    continuation.yield(.completed)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

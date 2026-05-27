import Foundation

enum OpenAIStreamingError: LocalizedError {
    case invalidBaseURL
    case missingAPIKey
    case invalidResponse
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Invalid OpenAI-compatible base URL."
        case .missingAPIKey:
            return "Missing API key."
        case .invalidResponse:
            return "Invalid response from model API."
        case let .httpError(code, body):
            return "HTTP \(code): \(body)"
        }
    }
}

final class OpenAIStreamingClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func streamChatCompletions(
        config: OpenAIServiceConfig,
        apiKey: String,
        messages: [[String: String]]
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedKey.isEmpty else {
                        throw OpenAIStreamingError.missingAPIKey
                    }
                    guard let base = URL(string: config.baseURL) else {
                        throw OpenAIStreamingError.invalidBaseURL
                    }
                    let endpoint = base.appendingPathComponent("chat/completions")

                    var request = URLRequest(url: endpoint)
                    request.httpMethod = "POST"
                    request.timeoutInterval = 60
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
                    let body: [String: Any] = [
                        "model": config.model,
                        "temperature": config.temperature,
                        "top_p": config.topP,
                        "presence_penalty": config.presencePenalty,
                        "frequency_penalty": config.frequencyPenalty,
                        "max_tokens": config.maxTokens,
                        "stream": true,
                        "messages": messages
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw OpenAIStreamingError.invalidResponse
                    }
                    guard (200..<300).contains(http.statusCode) else {
                        var bodyText = ""
                        for try await line in bytes.lines {
                            bodyText += line
                        }
                        throw OpenAIStreamingError.httpError(http.statusCode, bodyText)
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" {
                            break
                        }
                        guard let data = payload.data(using: .utf8),
                              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let first = choices.first,
                              let delta = first["delta"] as? [String: Any],
                              let content = delta["content"] as? String else {
                            continue
                        }
                        continuation.yield(content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

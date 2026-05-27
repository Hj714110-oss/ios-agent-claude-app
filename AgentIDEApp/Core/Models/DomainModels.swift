import Foundation

enum BuildProfile: String, Codable, Hashable {
    case store
    case open

    static var current: BuildProfile {
#if OPEN_PROFILE
        return .open
#else
        return .store
#endif
    }
}

struct ChatMessage: Identifiable, Codable, Hashable {
    enum Role: String, Codable {
        case system
        case user
        case assistant
        case tool
    }

    let id: UUID
    let role: Role
    var content: String
    let createdAt: Date

    init(id: UUID = UUID(), role: Role, content: String, createdAt: Date = .now) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

struct PlanTask: Identifiable, Codable, Hashable {
    enum Status: String, Codable {
        case todo
        case inProgress
        case done
        case blocked
    }

    let id: UUID
    var title: String
    var goal: String
    var steps: [String]
    var rollbackPoint: String
    var acceptance: String
    var status: Status
}

struct ToolSpec: Codable, Hashable {
    enum SafetyLevel: String, Codable {
        case readOnly
        case workspaceWrite
        case network
    }

    let name: String
    let inputSchema: String
    let safetyLevel: SafetyLevel
    let profileAvailability: [BuildProfile]
}

struct SkillManifest: Codable, Hashable, Identifiable {
    struct Trigger: Codable, Hashable {
        let type: String
        let value: String
    }

    let id: String
    let name: String
    let version: String
    let triggers: [Trigger]
    let tools: [String]
    let promptTemplate: String
    let permissions: [String]
}

struct PatchHunk: Codable, Hashable, Identifiable {
    let id: UUID
    let oldStart: Int
    let oldCount: Int
    let newStart: Int
    let newCount: Int
    let lines: [String]
}

struct PatchSet: Codable, Hashable, Identifiable {
    let id: UUID
    let filePath: String
    let hunks: [PatchHunk]
    let rationale: String
    let confidence: Double
}

struct RunRequest: Codable, Hashable {
    let command: String
    let args: [String]
    let workingDirectory: String
    let timeoutSeconds: Int
}

struct RunResult: Codable, Hashable {
    let stdout: String
    let stderr: String
    let traceback: String?
    let exitCode: Int32
    let durationMs: Int
    let usedRemoteFallback: Bool
}

struct AgentTask: Codable, Hashable {
    let id: UUID
    let prompt: String
    let workingDirectory: String
}

struct WorkspaceFile: Identifiable, Hashable {
    let id: UUID
    let path: String
    let isDirectory: Bool
}

enum StudioMode: String, Codable, CaseIterable, Identifiable {
    case designSketch
    case codeGeneration
    case fullApp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .designSketch:
            return "Design Sketch"
        case .codeGeneration:
            return "Code Generation"
        case .fullApp:
            return "Full App"
        }
    }
}

struct StudioRequest: Codable, Hashable {
    let mode: StudioMode
    let prompt: String
    let platform: String
    let language: String
    let systemPromptPreset: String?
    let targetFiles: [String]?
    let outputContractVersion: String?
}

struct StudioArtifact: Codable, Hashable, Identifiable {
    enum Kind: String, Codable {
        case markdown
        case code
        case patch
        case plan
    }

    let id: UUID
    let kind: Kind
    let title: String
    let content: String
    let targetPath: String?
    let language: String?
    let applyHint: String?
}

enum StudioEvent: Hashable {
    case token(String)
    case artifact(StudioArtifact)
    case marker(String)
    case error(String)
    case completed
}

enum StudioRunState: String {
    case idle
    case loading
    case streaming
    case parsing
    case ready
    case error
}

struct OpenAIServiceConfig: Codable, Hashable {
    var baseURL: String
    var model: String
    var temperature: Double
    var topP: Double
    var presencePenalty: Double
    var frequencyPenalty: Double
    var maxTokens: Int
    var personaName: String
    var customSystemPrompt: String

    static let `default` = OpenAIServiceConfig(
        baseURL: "https://api.openai.com/v1",
        model: "gpt-4.1",
        temperature: 0.2,
        topP: 1.0,
        presencePenalty: 0.0,
        frequencyPenalty: 0.0,
        maxTokens: 1200,
        personaName: "General Creative Engineer",
        customSystemPrompt: ""
    )
}

struct ProviderProfile: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var baseURL: String
    var model: String
    var temperature: Double
    var topP: Double
    var presencePenalty: Double
    var frequencyPenalty: Double
    var maxTokens: Int
    var personaName: String
    var customSystemPrompt: String
    var apiKeyRef: String
    var enabled: Bool

    static func makeDefault(id: String = UUID().uuidString, name: String = "Default") -> ProviderProfile {
        ProviderProfile(
            id: id,
            name: name,
            baseURL: OpenAIServiceConfig.default.baseURL,
            model: OpenAIServiceConfig.default.model,
            temperature: OpenAIServiceConfig.default.temperature,
            topP: OpenAIServiceConfig.default.topP,
            presencePenalty: OpenAIServiceConfig.default.presencePenalty,
            frequencyPenalty: OpenAIServiceConfig.default.frequencyPenalty,
            maxTokens: OpenAIServiceConfig.default.maxTokens,
            personaName: OpenAIServiceConfig.default.personaName,
            customSystemPrompt: OpenAIServiceConfig.default.customSystemPrompt,
            apiKeyRef: "provider.\(id).api_key",
            enabled: true
        )
    }

    var asServiceConfig: OpenAIServiceConfig {
        OpenAIServiceConfig(
            baseURL: baseURL,
            model: model,
            temperature: temperature,
            topP: topP,
            presencePenalty: presencePenalty,
            frequencyPenalty: frequencyPenalty,
            maxTokens: maxTokens,
            personaName: personaName,
            customSystemPrompt: customSystemPrompt
        )
    }
}

struct ProviderRegistry: Codable, Hashable {
    var profiles: [ProviderProfile]
    var activeProfileId: String

    static let `default` = ProviderRegistry(
        profiles: [ProviderProfile.makeDefault(id: "default", name: "Default")],
        activeProfileId: "default"
    )
}

struct WritePreview: Identifiable, Hashable {
    let id: UUID
    let targetPath: String
    let oldContent: String
    let newContent: String
    let changedLineCount: Int
}

struct ApplyQueueItem: Identifiable, Hashable {
    enum Status: String {
        case pending
        case applied
        case skipped
        case failed
    }

    let id: UUID
    let preview: WritePreview
    let hint: String?
    var status: Status
    var errorMessage: String?
}

struct GeneratedAppSummary: Hashable {
    let appName: String
    let outputPath: String
    let attemptedFiles: Int
    let appliedFiles: Int
    let failedFiles: Int
}

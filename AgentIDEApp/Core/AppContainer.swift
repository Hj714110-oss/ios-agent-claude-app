import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let buildProfile: BuildProfile
    let llmProvider: LLMProvider
    let executionProvider: ExecutionProvider
    let orchestrator: AgentOrchestrator
    let secretStore: SecretStore
    let studioProvider: StudioGenerationProvider
    let writeService: WorkspaceWriteService
    let generatedAppWriter: GeneratedAppWriter
    let configStore: UserDefaultsConfigStore

    @Published var chatMessages: [ChatMessage] = []
    @Published var planTasks: [PlanTask] = []
    @Published var studioArtifacts: [StudioArtifact] = []
    @Published var studioStreamText: String = ""
    @Published var studioState: StudioRunState = .idle
    @Published var studioErrorMessage: String = ""
    @Published var studioDiagnostics: [String] = []
    @Published var applyQueue: [ApplyQueueItem] = []
    @Published var workspaceRoot: String = ""
    @Published var selectedFilePath: String = ""
    @Published var selectedFileContent: String = ""
    @Published var providerRegistry: ProviderRegistry
    @Published var openAIConfig: OpenAIServiceConfig
    @Published var activeProfileName = ""
    @Published var lastGeneratedAppPath = ""
    @Published var appliedFileCount = 0
    @Published var lastGeneratedSummaryText = ""

    private var studioTask: Task<Void, Never>?
    private let streamingClient = OpenAIStreamingClient()

    private init(
        buildProfile: BuildProfile,
        llmProvider: LLMProvider,
        executionProvider: ExecutionProvider,
        orchestrator: AgentOrchestrator,
        secretStore: SecretStore,
        studioProvider: StudioGenerationProvider,
        writeService: WorkspaceWriteService,
        generatedAppWriter: GeneratedAppWriter,
        configStore: UserDefaultsConfigStore,
        providerRegistry: ProviderRegistry
    ) {
        self.buildProfile = buildProfile
        self.llmProvider = llmProvider
        self.executionProvider = executionProvider
        self.orchestrator = orchestrator
        self.secretStore = secretStore
        self.studioProvider = studioProvider
        self.writeService = writeService
        self.generatedAppWriter = generatedAppWriter
        self.configStore = configStore
        self.providerRegistry = providerRegistry
        self.openAIConfig = providerRegistry.profiles.first(where: { $0.id == providerRegistry.activeProfileId })?.asServiceConfig ?? .default
        self.activeProfileName = providerRegistry.profiles.first(where: { $0.id == providerRegistry.activeProfileId })?.name ?? "Default"
        self.planTasks = [
            PlanTask(
                id: UUID(),
                title: "Fix runtime error",
                goal: "Run python script without traceback",
                steps: ["Inspect stderr", "Patch code", "Re-run"],
                rollbackPoint: "Commit HEAD~1",
                acceptance: "Exit code == 0",
                status: .todo
            )
        ]
    }

    static func bootstrap() -> AppContainer {
        let profile = BuildProfile.current
        let keychain = KeychainSecretStore()
        let configStore = UserDefaultsConfigStore()
        let registry = configStore.loadProviderRegistry()
        let writeService = WorkspaceWriteServiceImpl()
        let generatedAppWriter = GeneratedAppWriterImpl(writeService: writeService)

        let llm = OpenAICompatibleLLMProvider(configProvider: {
            let reg = configStore.loadProviderRegistry()
            let active = reg.profiles.first(where: { $0.id == reg.activeProfileId }) ?? reg.profiles.first ?? ProviderProfile.makeDefault()
            let key = ((try? keychain.get(active.apiKeyRef)) ?? nil) ?? ""
            return OpenAICompatibleConfig(service: active.asServiceConfig, apiKey: key)
        })

        let local = LocalPythonExecutionProvider()
        let remote = RemoteExecutionProvider()
        let failover = FailoverExecutionProvider(local: local, remote: remote, remoteEnabled: profile == .open)
        let orchestrator = AgentOrchestrator(llmProvider: llm, executionProvider: failover)

        let studio = StudioGenerationProviderImpl(
            configProvider: {
                let reg = configStore.loadProviderRegistry()
                let active = reg.profiles.first(where: { $0.id == reg.activeProfileId }) ?? reg.profiles.first ?? ProviderProfile.makeDefault()
                return active.asServiceConfig
            },
            apiKeyProvider: {
                let reg = configStore.loadProviderRegistry()
                let active = reg.profiles.first(where: { $0.id == reg.activeProfileId }) ?? reg.profiles.first ?? ProviderProfile.makeDefault()
                return ((try? keychain.get(active.apiKeyRef)) ?? nil) ?? ""
            }
        )

        return AppContainer(
            buildProfile: profile,
            llmProvider: llm,
            executionProvider: failover,
            orchestrator: orchestrator,
            secretStore: keychain,
            studioProvider: studio,
            writeService: writeService,
            generatedAppWriter: generatedAppWriter,
            configStore: configStore,
            providerRegistry: registry
        )
    }

    func runStudio(mode: StudioMode, prompt: String) async {
        studioTask?.cancel()
        studioState = .loading
        studioStreamText = ""
        studioArtifacts = []
        applyQueue = []
        studioErrorMessage = ""
        studioDiagnostics = []

        let active = currentActiveProfile()
        let request = StudioRequest(
            mode: mode,
            prompt: prompt,
            platform: "iOS",
            language: "Swift",
            systemPromptPreset: "persona=\(active.personaName)\ncustom_system=\(active.customSystemPrompt)",
            targetFiles: selectedFilePath.isEmpty ? nil : [selectedFilePath],
            outputContractVersion: "v1"
        )

        studioTask = Task {
            let start = Date()
            do {
                for try await event in studioProvider.stream(request: request) {
                    if Task.isCancelled { break }
                    switch event {
                    case let .token(token): studioState = .streaming; studioStreamText.append(token)
                    case let .artifact(artifact): studioState = .parsing; studioArtifacts.append(artifact)
                    case let .marker(mark): studioDiagnostics.append("marker=\(mark)")
                    case let .error(message): studioState = .error; studioErrorMessage = message
                    case .completed: studioState = .ready
                    }
                }
                buildApplyQueue()
                studioDiagnostics.append("request_ms=\(Int(Date().timeIntervalSince(start) * 1000))")
                studioDiagnostics.append("profile_name=\(active.name)")
            } catch {
                studioState = .error
                studioErrorMessage = error.localizedDescription
                studioDiagnostics.append("network_error=\(error.localizedDescription)")
            }
        }
    }

    func cancelStudioRun() {
        studioTask?.cancel()
        studioTask = nil
    }

    func saveOpenAIConfig(_ config: OpenAIServiceConfig) {
        var active = currentActiveProfile()
        active.baseURL = config.baseURL
        active.model = config.model
        active.temperature = config.temperature
        active.topP = config.topP
        active.presencePenalty = config.presencePenalty
        active.frequencyPenalty = config.frequencyPenalty
        active.maxTokens = config.maxTokens
        active.personaName = config.personaName
        active.customSystemPrompt = config.customSystemPrompt
        updateProviderProfile(active)
    }

    func testOpenAIConnection() async -> String {
        do {
            let active = currentActiveProfile()
            let apiKey = try secretStore.get(active.apiKeyRef) ?? ""
            let ping = [["role": "user", "content": "Reply with PONG."]]
            var chars = 0
            for try await token in streamingClient.streamChatCompletions(config: active.asServiceConfig, apiKey: apiKey, messages: ping) {
                chars += token.count
                if chars > 4 { break }
            }
            return "Connection OK"
        } catch {
            return "Connection failed: \(error.localizedDescription)"
        }
    }

    func applyQueueItem(_ item: ApplyQueueItem) {
        guard let idx = applyQueue.firstIndex(where: { $0.id == item.id }) else { return }
        do {
            try writeService.applyWrite(root: workspaceRoot, preview: item.preview)
            applyQueue[idx].status = .applied
            appliedFileCount += 1
            if selectedFilePath == item.preview.targetPath { selectedFileContent = item.preview.newContent }
        } catch {
            applyQueue[idx].status = .failed
            applyQueue[idx].errorMessage = error.localizedDescription
        }
    }

    func skipQueueItem(_ item: ApplyQueueItem) {
        guard let idx = applyQueue.firstIndex(where: { $0.id == item.id }) else { return }
        applyQueue[idx].status = .skipped
    }

    func applyAllPending() {
        for item in applyQueue where item.status == .pending { applyQueueItem(item) }
    }

    func rollbackLastWrite() {
        do { try writeService.rollbackLast() } catch { studioDiagnostics.append("rollback_error=\(error.localizedDescription)") }
    }

    func generateFullAppBundle(appName: String) {
        let summary = generatedAppWriter.generate(workspaceRoot: workspaceRoot, appName: appName, artifacts: studioArtifacts)
        lastGeneratedAppPath = summary.outputPath
        appliedFileCount = summary.appliedFiles
        lastGeneratedSummaryText = "App: \(summary.appName)\nPath: \(summary.outputPath)\nAttempted: \(summary.attemptedFiles)\nApplied: \(summary.appliedFiles)\nFailed: \(summary.failedFiles)"
    }

    func createProviderProfile(name: String) {
        let id = UUID().uuidString
        var p = ProviderProfile.makeDefault(id: id, name: name)
        p.apiKeyRef = "provider.\(id).api_key"
        providerRegistry.profiles.append(p)
        providerRegistry.activeProfileId = p.id
        persistRegistry()
        refreshActive()
    }

    func duplicateProviderProfile(id: String) {
        guard let src = providerRegistry.profiles.first(where: { $0.id == id }) else { return }
        let id2 = UUID().uuidString
        var p = src
        p.id = id2
        p.name = "\(src.name)-Copy"
        p.apiKeyRef = "provider.\(id2).api_key"
        providerRegistry.profiles.append(p)
        providerRegistry.activeProfileId = p.id
        persistRegistry()
        refreshActive()
    }

    func updateProviderProfile(_ profile: ProviderProfile) {
        guard let idx = providerRegistry.profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        providerRegistry.profiles[idx] = profile
        persistRegistry()
        refreshActive()
    }

    func deleteProviderProfile(id: String) {
        guard providerRegistry.profiles.count > 1 else { return }
        providerRegistry.profiles.removeAll { $0.id == id }
        if providerRegistry.activeProfileId == id {
            providerRegistry.activeProfileId = providerRegistry.profiles[0].id
        }
        persistRegistry()
        refreshActive()
    }

    func setActiveProfile(id: String) {
        guard providerRegistry.profiles.contains(where: { $0.id == id }) else { return }
        providerRegistry.activeProfileId = id
        persistRegistry()
        refreshActive()
    }

    func exportProviderProfiles() -> Data {
        (try? JSONEncoder().encode(providerRegistry)) ?? Data()
    }

    func importProviderProfiles(data: Data) -> Bool {
        guard let imported = try? JSONDecoder().decode(ProviderRegistry.self, from: data), !imported.profiles.isEmpty else {
            return false
        }
        providerRegistry = imported
        persistRegistry()
        refreshActive()
        return true
    }

    func saveAPIKeyForActiveProfile(_ apiKey: String) {
        let active = currentActiveProfile()
        try? secretStore.set(apiKey, for: active.apiKeyRef)
    }

    func currentActiveProfile() -> ProviderProfile {
        providerRegistry.profiles.first(where: { $0.id == providerRegistry.activeProfileId }) ?? providerRegistry.profiles.first ?? ProviderProfile.makeDefault()
    }

    private func buildApplyQueue() {
        applyQueue = studioArtifacts.compactMap { artifact in
            guard let path = artifact.targetPath?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else { return nil }
            do {
                let preview = try writeService.previewWrite(root: workspaceRoot, targetPath: path, newContent: artifact.content)
                return ApplyQueueItem(id: UUID(), preview: preview, hint: artifact.applyHint, status: .pending, errorMessage: nil)
            } catch {
                return ApplyQueueItem(
                    id: UUID(),
                    preview: WritePreview(id: UUID(), targetPath: path, oldContent: "", newContent: artifact.content, changedLineCount: 0),
                    hint: artifact.applyHint,
                    status: .failed,
                    errorMessage: error.localizedDescription
                )
            }
        }
    }

    private func persistRegistry() {
        configStore.saveProviderRegistry(providerRegistry)
    }

    private func refreshActive() {
        let active = currentActiveProfile()
        openAIConfig = active.asServiceConfig
        activeProfileName = active.name
    }
}

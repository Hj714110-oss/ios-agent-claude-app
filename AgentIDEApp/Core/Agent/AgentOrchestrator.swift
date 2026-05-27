import Foundation

@MainActor
final class AgentOrchestrator: ObservableObject {
    @Published private(set) var state: AgentState = .idle
    @Published private(set) var logs: [String] = []
    @Published private(set) var latestPatch: PatchSet?

    private let llmProvider: LLMProvider
    private let executionProvider: ExecutionProvider

    init(llmProvider: LLMProvider, executionProvider: ExecutionProvider) {
        self.llmProvider = llmProvider
        self.executionProvider = executionProvider
    }

    func start(task: AgentTask, tools: [ToolSpec]) async {
        state = .planning
        logs.append("Planning task: \(task.prompt)")
        let messages = [ChatMessage(role: .user, content: task.prompt)]
        do {
            for try await event in llmProvider.stream(messages: messages, tools: tools) {
                switch event {
                case let .token(token):
                    logs.append("LLM: \(token)")
                case let .toolCall(name, payload):
                    logs.append("ToolCall: \(name) payload=\(payload)")
                case .completed:
                    logs.append("Planning complete")
                }
            }
            state = .executing
        } catch {
            state = .failed("Planning failed: \(error.localizedDescription)")
        }
    }

    func next(action: AgentAction) async {
        switch action {
        case .createPlan:
            state = .planning
        case let .run(request):
            state = .executing
            let result = await executionProvider.run(request: request)
            logs.append("Execute exit=\(result.exitCode) remote=\(result.usedRemoteFallback)")
        case let .observe(result):
            state = .observing
            logs.append("Observe stderr=\(result.stderr)")
        case let .proposePatch(patch):
            state = .patching
            latestPatch = patch
            logs.append("Patch proposed for \(patch.filePath)")
        case let .verify(result):
            state = .verifying
            logs.append("Verify exit=\(result.exitCode)")
            state = result.exitCode == 0 ? .completed : .failed("Verification failed")
        }
    }

    func apply(patch: PatchSet) {
        latestPatch = patch
        logs.append("Patch applied: \(patch.filePath)")
    }
}

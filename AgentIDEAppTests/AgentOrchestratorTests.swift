import XCTest
@testable import AgentIDEApp

final class AgentOrchestratorTests: XCTestCase {
    @MainActor
    func testOrchestratorTransitionsToCompletedOnVerifySuccess() async {
        let llm = StubLLMProvider()
        let exec = StubExecutionProvider(result: RunResult(
            stdout: "ok",
            stderr: "",
            traceback: nil,
            exitCode: 0,
            durationMs: 1,
            usedRemoteFallback: false
        ))
        let orchestrator = AgentOrchestrator(llmProvider: llm, executionProvider: exec)
        await orchestrator.next(action: .verify(exec.result))
        XCTAssertEqual(orchestrator.state, .completed)
    }
}

private final class StubLLMProvider: LLMProvider {
    func stream(messages: [ChatMessage], tools: [ToolSpec]) -> AsyncThrowingStream<LLMEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.completed)
            continuation.finish()
        }
    }
}

private final class StubExecutionProvider: ExecutionProvider {
    let result: RunResult
    init(result: RunResult) { self.result = result }
    func run(request: RunRequest) async -> RunResult { result }
}

import Foundation

enum LLMEvent: Hashable {
    case token(String)
    case toolCall(name: String, payload: String)
    case completed
}

enum AgentState: Hashable {
    case idle
    case planning
    case executing
    case observing
    case patching
    case verifying
    case completed
    case failed(String)
}

enum AgentAction: Hashable {
    case createPlan(String)
    case run(RunRequest)
    case observe(RunResult)
    case proposePatch(PatchSet)
    case verify(RunResult)
}

import Foundation

final class LocalPythonExecutionProvider: ExecutionProvider {
    func run(request: RunRequest) async -> RunResult {
        let start = Date()
        // Hook point: replace mock with embedded CPython XCFramework invocation.
        let stdout = "Local run: \(request.command) \(request.args.joined(separator: " "))"
        let durationMs = Int(Date().timeIntervalSince(start) * 1000)
        return RunResult(
            stdout: stdout,
            stderr: "",
            traceback: nil,
            exitCode: 0,
            durationMs: durationMs,
            usedRemoteFallback: false
        )
    }
}

final class RemoteExecutionProvider: ExecutionProvider {
    func run(request: RunRequest) async -> RunResult {
        RunResult(
            stdout: "",
            stderr: "Remote execution endpoint not configured",
            traceback: nil,
            exitCode: 1,
            durationMs: 50,
            usedRemoteFallback: true
        )
    }
}

final class FailoverExecutionProvider: ExecutionProvider {
    private let local: ExecutionProvider
    private let remote: ExecutionProvider
    private let remoteEnabled: Bool

    init(local: ExecutionProvider, remote: ExecutionProvider, remoteEnabled: Bool) {
        self.local = local
        self.remote = remote
        self.remoteEnabled = remoteEnabled
    }

    func run(request: RunRequest) async -> RunResult {
        let localResult = await local.run(request: request)
        guard remoteEnabled else { return localResult }
        if localResult.exitCode == 0 {
            return localResult
        }
        return await remote.run(request: request)
    }
}

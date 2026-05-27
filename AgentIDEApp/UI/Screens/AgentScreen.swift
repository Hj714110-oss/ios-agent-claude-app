import SwiftUI

struct AgentScreen: View {
    @EnvironmentObject private var container: AppContainer
    @State private var prompt = "Fix Python traceback in main.py and verify."

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextField("Agent task", text: $prompt)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                Button("Run Agent Loop") {
                    Task {
                        let task = AgentTask(id: UUID(), prompt: prompt, workingDirectory: container.workspaceRoot)
                        let tools = [
                            ToolSpec(
                                name: "workspace_search",
                                inputSchema: "{\"type\":\"object\"}",
                                safetyLevel: .readOnly,
                                profileAvailability: [.store, .open]
                            )
                        ]
                        await container.orchestrator.start(task: task, tools: tools)
                        let runResult = await container.executionProvider.run(
                            request: RunRequest(
                                command: "python",
                                args: ["main.py"],
                                workingDirectory: container.workspaceRoot,
                                timeoutSeconds: 30
                            )
                        )
                        await container.orchestrator.next(action: .observe(runResult))
                        let patch = PatchSet(
                            id: UUID(),
                            filePath: "main.py",
                            hunks: [
                                PatchHunk(
                                    id: UUID(),
                                    oldStart: 1,
                                    oldCount: 1,
                                    newStart: 1,
                                    newCount: 1,
                                    lines: ["-print(unknown_var)", "+print('fixed')"]
                                )
                            ],
                            rationale: "Replace undefined symbol",
                            confidence: 0.81
                        )
                        await container.orchestrator.next(action: .proposePatch(patch))
                        await container.orchestrator.next(action: .verify(runResult))
                    }
                }
                .buttonStyle(.borderedProminent)

                List {
                    Section("State") {
                        Text(String(describing: container.orchestrator.state))
                    }
                    Section("Plan Tasks (PIAN)") {
                        ForEach(container.planTasks) { task in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title).font(.headline)
                                Text(task.goal).font(.footnote)
                                Text(task.status.rawValue).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Section("Logs") {
                        ForEach(container.orchestrator.logs.indices, id: \.self) { index in
                            Text(container.orchestrator.logs[index]).font(.footnote.monospaced())
                        }
                    }
                }
            }
            .navigationTitle("Agent")
        }
    }
}

import SwiftUI

struct StudioScreen: View {
    @EnvironmentObject private var container: AppContainer
    @State private var mode: StudioMode = .designSketch
    @State private var prompt = "Build a mobile coding assistant home screen with patch preview."
    @State private var appBundleName = "MyGeneratedApp"

    private var isGenerating: Bool {
        container.studioState == .loading || container.studioState == .streaming
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("Mode", selection: $mode) {
                    ForEach(StudioMode.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                TextEditor(text: $prompt)
                    .frame(height: 120)
                    .padding(8)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                HStack {
                    Button(isGenerating ? "Generating..." : "Generate") {
                        container.cancelStudioRun()
                        Task {
                            await container.runStudio(mode: mode, prompt: prompt)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isGenerating || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Cancel") {
                        container.cancelStudioRun()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isGenerating)
                }

                if mode == .fullApp {
                    HStack {
                        TextField("App bundle name", text: $appBundleName)
                            .textFieldStyle(.roundedBorder)
                        Button("Generate App Bundle") {
                            container.generateFullAppBundle(appName: appBundleName)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(container.workspaceRoot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        stateView

                        if !container.studioStreamText.isEmpty {
                            card(title: "Live Stream", content: container.studioStreamText)
                        }

                        ForEach(container.studioArtifacts) { artifact in
                            var text = artifact.content
                            if let path = artifact.targetPath {
                                text = "[path] \(path)\n\n" + text
                            }
                            card(title: artifact.title + " (\(artifact.kind.rawValue))", content: text)
                        }

                        if !container.applyQueue.isEmpty {
                            applyQueueView
                        }

                        if !container.studioDiagnostics.isEmpty {
                            card(title: "Diagnostics", content: container.studioDiagnostics.joined(separator: "\n"))
                        }

                        if !container.lastGeneratedSummaryText.isEmpty {
                            card(title: "Generated App Summary", content: container.lastGeneratedSummaryText)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Studio")
        }
    }

    private var stateView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("State: \(container.studioState.rawValue)").font(.caption).foregroundStyle(.secondary)
            if !container.studioErrorMessage.isEmpty {
                Text(container.studioErrorMessage).font(.footnote).foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var applyQueueView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Apply Queue").font(.headline)
                Spacer()
                Button("Apply All") {
                    container.applyAllPending()
                }
                .buttonStyle(.bordered)
                Button("Rollback") {
                    container.rollbackLastWrite()
                }
                .buttonStyle(.bordered)
            }

            ForEach(container.applyQueue) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.preview.targetPath).font(.subheadline.monospaced())
                    Text("Changed lines: \(item.preview.changedLineCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let hint = item.hint, !hint.isEmpty {
                        Text("Hint: \(hint)").font(.caption)
                    }
                    if let err = item.errorMessage {
                        Text(err).font(.caption).foregroundStyle(.red)
                    }
                    ScrollView(.horizontal) {
                        Text(item.preview.newContent).font(.caption.monospaced())
                    }
                    HStack {
                        Text("Status: \(item.status.rawValue)").font(.caption)
                        Spacer()
                        if item.status == .pending {
                            Button("Apply") {
                                container.applyQueueItem(item)
                            }
                            .buttonStyle(.borderedProminent)
                            Button("Skip") {
                                container.skipQueueItem(item)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func card(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(content).font(.footnote.monospaced())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

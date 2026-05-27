import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var container: AppContainer

    @State private var selectedProfileId = ""
    @State private var profileName = ""
    @State private var apiKey = ""
    @State private var status = ""
    @State private var baseURL = OpenAIServiceConfig.default.baseURL
    @State private var model = OpenAIServiceConfig.default.model
    @State private var temperature = OpenAIServiceConfig.default.temperature
    @State private var topP = OpenAIServiceConfig.default.topP
    @State private var presencePenalty = OpenAIServiceConfig.default.presencePenalty
    @State private var frequencyPenalty = OpenAIServiceConfig.default.frequencyPenalty
    @State private var maxTokensText = "\(OpenAIServiceConfig.default.maxTokens)"
    @State private var personaName = OpenAIServiceConfig.default.personaName
    @State private var customSystemPrompt = OpenAIServiceConfig.default.customSystemPrompt
    @State private var importExportText = ""
    @State private var testing = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Provider Profiles") {
                    Picker("Active", selection: $selectedProfileId) {
                        ForEach(container.providerRegistry.profiles) { p in
                            Text(p.name).tag(p.id)
                        }
                    }
                    .onChange(of: selectedProfileId) { _, newValue in
                        container.setActiveProfile(id: newValue)
                        loadActive()
                    }
                    HStack {
                        Button("New") {
                            container.createProviderProfile(name: "Provider-\(container.providerRegistry.profiles.count + 1)")
                            selectedProfileId = container.providerRegistry.activeProfileId
                            loadActive()
                        }
                        Button("Copy") {
                            container.duplicateProviderProfile(id: selectedProfileId)
                            selectedProfileId = container.providerRegistry.activeProfileId
                            loadActive()
                        }
                        Button("Delete") {
                            container.deleteProviderProfile(id: selectedProfileId)
                            selectedProfileId = container.providerRegistry.activeProfileId
                            loadActive()
                        }
                    }
                }

                Section("Active Provider Config") {
                    TextField("Profile Name", text: $profileName)
                    TextField("Base URL", text: $baseURL)
                    TextField("Model", text: $model)
                    HStack {
                        Text("Temp")
                        Slider(value: $temperature, in: 0...1)
                        Text(String(format: "%.2f", temperature))
                    }
                    HStack {
                        Text("Top P")
                        Slider(value: $topP, in: 0...1)
                        Text(String(format: "%.2f", topP))
                    }
                    HStack {
                        Text("Presence")
                        Slider(value: $presencePenalty, in: -2...2)
                        Text(String(format: "%.2f", presencePenalty))
                    }
                    HStack {
                        Text("Frequency")
                        Slider(value: $frequencyPenalty, in: -2...2)
                        Text(String(format: "%.2f", frequencyPenalty))
                    }
                    TextField("Max Tokens", text: $maxTokensText).keyboardType(.numberPad)
                    TextField("Persona", text: $personaName)
                    TextEditor(text: $customSystemPrompt).frame(height: 100)
                    SecureField("API Key", text: $apiKey)

                    Button("Save Active Provider") {
                        saveActive()
                    }
                    Button(testing ? "Testing..." : "Test Connection") {
                        testing = true
                        Task {
                            status = await container.testOpenAIConnection()
                            testing = false
                        }
                    }
                    .disabled(testing)
                    Text(status).font(.footnote).foregroundStyle(.secondary)
                }

                Section("Import/Export JSON") {
                    TextEditor(text: $importExportText).frame(height: 100)
                    HStack {
                        Button("Export") {
                            importExportText = String(data: container.exportProviderProfiles(), encoding: .utf8) ?? ""
                        }
                        Button("Import") {
                            guard let data = importExportText.data(using: .utf8) else {
                                status = "Invalid JSON text"
                                return
                            }
                            let ok = container.importProviderProfiles(data: data)
                            status = ok ? "Import success" : "Import failed"
                            selectedProfileId = container.providerRegistry.activeProfileId
                            loadActive()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                selectedProfileId = container.providerRegistry.activeProfileId
                loadActive()
            }
        }
    }

    private func loadActive() {
        let active = container.currentActiveProfile()
        profileName = active.name
        baseURL = active.baseURL
        model = active.model
        temperature = active.temperature
        topP = active.topP
        presencePenalty = active.presencePenalty
        frequencyPenalty = active.frequencyPenalty
        maxTokensText = "\(active.maxTokens)"
        personaName = active.personaName
        customSystemPrompt = active.customSystemPrompt
    }

    private func saveActive() {
        var active = container.currentActiveProfile()
        active.name = profileName
        active.baseURL = baseURL
        active.model = model
        active.temperature = temperature
        active.topP = topP
        active.presencePenalty = presencePenalty
        active.frequencyPenalty = frequencyPenalty
        active.maxTokens = max(64, Int(maxTokensText) ?? OpenAIServiceConfig.default.maxTokens)
        active.personaName = personaName
        active.customSystemPrompt = customSystemPrompt
        container.updateProviderProfile(active)
        container.saveAPIKeyForActiveProfile(apiKey)
        status = "Saved"
    }
}

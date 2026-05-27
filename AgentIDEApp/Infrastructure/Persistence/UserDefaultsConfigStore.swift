import Foundation

final class UserDefaultsConfigStore {
    private let defaults: UserDefaults
    private let configKey = "openai_service_config"
    private let registryKey = "provider_registry"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadOpenAIConfig() -> OpenAIServiceConfig {
        guard let data = defaults.data(forKey: configKey),
              let config = try? decoder.decode(OpenAIServiceConfig.self, from: data) else {
            return .default
        }
        return config
    }

    func saveOpenAIConfig(_ config: OpenAIServiceConfig) {
        guard let data = try? encoder.encode(config) else { return }
        defaults.set(data, forKey: configKey)
    }

    func loadProviderRegistry() -> ProviderRegistry {
        if let data = defaults.data(forKey: registryKey),
           let registry = try? decoder.decode(ProviderRegistry.self, from: data),
           !registry.profiles.isEmpty {
            return registry
        }
        let migrated = migrateFromLegacyConfig()
        saveProviderRegistry(migrated)
        return migrated
    }

    func saveProviderRegistry(_ registry: ProviderRegistry) {
        guard let data = try? encoder.encode(registry) else { return }
        defaults.set(data, forKey: registryKey)
    }

    private func migrateFromLegacyConfig() -> ProviderRegistry {
        let legacy = loadOpenAIConfig()
        var profile = ProviderProfile.makeDefault(id: "default", name: "Default")
        profile.baseURL = legacy.baseURL
        profile.model = legacy.model
        profile.temperature = legacy.temperature
        profile.topP = legacy.topP
        profile.presencePenalty = legacy.presencePenalty
        profile.frequencyPenalty = legacy.frequencyPenalty
        profile.maxTokens = legacy.maxTokens
        profile.personaName = legacy.personaName
        profile.customSystemPrompt = legacy.customSystemPrompt
        profile.apiKeyRef = "openai_api_key"
        profile.enabled = true
        return ProviderRegistry(profiles: [profile], activeProfileId: profile.id)
    }
}

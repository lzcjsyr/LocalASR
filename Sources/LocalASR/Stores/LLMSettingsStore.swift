import Foundation
import SwiftUI

@MainActor
final class LLMSettingsStore: ObservableObject {
    @Published private(set) var providers: [LLMProviderProfile]
    @Published private(set) var selectedProviderID: UUID
    @Published var apiKey: String
    @Published private(set) var statusMessage = ""
    @Published private(set) var isTesting = false

    private let defaults: UserDefaults
    private let service = LLMService()

    private enum Keys {
        static let providers = "llm.providers"
        static let selectedProviderID = "llm.selectedProviderID"

        // These keys are retained only to migrate the original single-provider setup.
        static let legacyBaseURL = "llm.baseURL"
        static let legacyModel = "llm.model"
        static let legacyPrompt = "llm.prompt"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let loadedProviders: [LLMProviderProfile]
        if let data = defaults.data(forKey: Keys.providers),
           let decoded = try? JSONDecoder().decode([LLMProviderProfile].self, from: data),
           !decoded.isEmpty {
            loadedProviders = decoded
        } else {
            let migrated = LLMProviderProfile(
                id: UUID(),
                name: "默认供应商",
                baseURL: defaults.string(forKey: Keys.legacyBaseURL) ?? "",
                model: defaults.string(forKey: Keys.legacyModel) ?? "",
                prompt: defaults.string(forKey: Keys.legacyPrompt) ?? LLMConfiguration.defaultPrompt
            )
            loadedProviders = [migrated]
        }

        let savedID = defaults.string(forKey: Keys.selectedProviderID).flatMap(UUID.init(uuidString:))
        let initialID = savedID.flatMap { id in
            loadedProviders.contains { $0.id == id } ? id : nil
        } ?? loadedProviders[0].id

        providers = loadedProviders
        selectedProviderID = initialID
        apiKey = KeychainStore.read(account: Self.keychainAccount(for: initialID))
            ?? KeychainStore.read()
            ?? ""
    }

    var selectedProvider: LLMProviderProfile? {
        providers.first { $0.id == selectedProviderID }
    }

    var configuration: LLMConfiguration {
        selectedProvider?.configuration ?? LLMConfiguration(baseURL: "", model: "", prompt: "")
    }

    func binding(for keyPath: WritableKeyPath<LLMProviderProfile, String>) -> Binding<String> {
        Binding(
            get: { [weak self] in
                guard let self, let selectedProvider = self.selectedProvider else { return "" }
                return selectedProvider[keyPath: keyPath]
            },
            set: { [weak self] value in
                self?.updateSelectedProvider(keyPath, value: value)
            }
        )
    }

    func selectProvider(_ id: UUID) {
        guard id != selectedProviderID, providers.contains(where: { $0.id == id }) else { return }
        persist(showStatus: false)
        selectedProviderID = id
        apiKey = KeychainStore.read(account: Self.keychainAccount(for: id)) ?? ""
        statusMessage = "已切换到 " + (selectedProvider?.name ?? "供应商")
    }

    func addProvider() {
        persist(showStatus: false)
        let profile = LLMProviderProfile.makeDefault(name: "供应商 " + String(providers.count + 1))
        providers.append(profile)
        selectedProviderID = profile.id
        apiKey = ""
        persist(showStatus: false)
        statusMessage = "已新增供应商，请填写连接参数"
    }

    func deleteSelectedProvider() {
        guard providers.count > 1,
              let index = providers.firstIndex(where: { $0.id == selectedProviderID }) else {
            statusMessage = "至少保留一个供应商配置"
            return
        }

        let removedID = providers[index].id
        providers.remove(at: index)
        try? KeychainStore.delete(account: Self.keychainAccount(for: removedID))
        selectedProviderID = providers[max(0, index - 1)].id
        apiKey = KeychainStore.read(account: Self.keychainAccount(for: selectedProviderID)) ?? ""
        persist(showStatus: false)
        statusMessage = "已删除供应商配置"
    }

    @discardableResult
    func save() -> Bool {
        persist(showStatus: true)
    }

    func testConnection() async {
        guard save() else { return }
        let configuration = configuration
        let apiKey = apiKey
        isTesting = true
        statusMessage = "正在测试连接…"
        defer { isTesting = false }

        do {
            try await service.testConnection(configuration: configuration, apiKey: apiKey)
            statusMessage = "连接成功：" + (selectedProvider?.name ?? configuration.model)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func updateSelectedProvider(
        _ keyPath: WritableKeyPath<LLMProviderProfile, String>,
        value: String
    ) {
        guard let index = providers.firstIndex(where: { $0.id == selectedProviderID }) else { return }
        providers[index][keyPath: keyPath] = value
    }

    @discardableResult
    private func persist(showStatus: Bool) -> Bool {
        guard let selectedProvider else { return false }
        guard let data = try? JSONEncoder().encode(providers) else {
            statusMessage = "供应商配置无法保存"
            return false
        }

        defaults.set(data, forKey: Keys.providers)
        defaults.set(selectedProviderID.uuidString, forKey: Keys.selectedProviderID)

        do {
            try KeychainStore.save(apiKey, account: Self.keychainAccount(for: selectedProvider.id))
            if showStatus { statusMessage = "配置已保存" }
            return true
        } catch {
            statusMessage = error.localizedDescription
            return false
        }
    }

    private static func keychainAccount(for id: UUID) -> String {
        "api-key-" + id.uuidString
    }
}

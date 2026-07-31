import Foundation
import SwiftUI

@MainActor
final class LLMSettingsStore: ObservableObject {
    @Published var baseURL: String
    @Published var model: String
    @Published var apiKey: String
    @Published var prompt: String
    @Published private(set) var statusMessage = ""
    @Published private(set) var isTesting = false

    private let defaults: UserDefaults
    private let service = LLMService()

    private enum Keys {
        static let baseURL = "llm.baseURL"
        static let model = "llm.model"
        static let prompt = "llm.prompt"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        baseURL = defaults.string(forKey: Keys.baseURL) ?? "https://api.deepseek.com"
        model = defaults.string(forKey: Keys.model) ?? "deepseek-v4-flash"
        prompt = defaults.string(forKey: Keys.prompt) ?? LLMConfiguration.defaultPrompt
        apiKey = KeychainStore.read() ?? ""
    }

    var configuration: LLMConfiguration {
        LLMConfiguration(baseURL: baseURL, model: model, prompt: prompt)
    }

    @discardableResult
    func save() -> Bool {
        defaults.set(baseURL, forKey: Keys.baseURL)
        defaults.set(model, forKey: Keys.model)
        defaults.set(prompt, forKey: Keys.prompt)

        do {
            try KeychainStore.save(apiKey)
            statusMessage = "配置已保存"
            return true
        } catch {
            statusMessage = error.localizedDescription
            return false
        }
    }

    func testConnection() async {
        guard save() else { return }
        isTesting = true
        statusMessage = "正在测试连接…"
        defer { isTesting = false }

        do {
            try await service.testConnection(configuration: configuration, apiKey: apiKey)
            statusMessage = "连接成功：\(model)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

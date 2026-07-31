import Foundation

enum LLMError: LocalizedError {
    case missingConfiguration
    case insecureBaseURL
    case invalidURL
    case unauthorized
    case server(statusCode: Int, message: String)
    case invalidResponse
    case emptyResponse
    case keychainFailure(OSStatus)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "请先填写 Base URL、模型和 API Key。"
        case .insecureBaseURL:
            return "为了保护 API Key，公网地址必须使用 HTTPS；HTTP 仅允许 localhost 或 127.0.0.1。"
        case .invalidURL:
            return "Base URL 格式不正确。"
        case .unauthorized:
            return "API Key 无效或没有权限访问该模型。"
        case let .server(statusCode, message):
            return "LLM 服务返回错误（HTTP \(statusCode)）：\(message)"
        case .invalidResponse:
            return "LLM 返回格式无法识别。"
        case .emptyResponse:
            return "LLM 没有返回可用文字。"
        case .keychainFailure:
            return "API Key 无法保存到 macOS 钥匙串。"
        }
    }
}

struct LLMService {
    func testConnection(configuration: LLMConfiguration, apiKey: String) async throws {
        let message = ChatMessage(role: "user", content: "请只回复 OK。")
        let response = try await complete(
            configuration: configuration,
            apiKey: apiKey,
            messages: [message],
            maxTokens: 8,
            temperature: 0
        )
        guard !response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMError.emptyResponse
        }
    }

    func polish(text: String, configuration: LLMConfiguration, apiKey: String) async throws -> String {
        let messages = [
            ChatMessage(role: "system", content: configuration.prompt),
            ChatMessage(role: "user", content: text)
        ]
        let response = try await complete(
            configuration: configuration,
            apiKey: apiKey,
            messages: messages,
            maxTokens: 4096,
            temperature: 0.2
        )
        let result = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { throw LLMError.emptyResponse }
        return result
    }

    private func complete(
        configuration: LLMConfiguration,
        apiKey: String,
        messages: [ChatMessage],
        maxTokens: Int,
        temperature: Double
    ) async throws -> String {
        guard !configuration.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !configuration.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMError.missingConfiguration
        }

        let endpoint = try Self.endpointURL(from: configuration.baseURL)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            ChatCompletionRequest(
                model: configuration.model,
                messages: messages,
                temperature: temperature,
                maxTokens: maxTokens
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw LLMError.unauthorized
            }
            throw LLMError.server(
                statusCode: httpResponse.statusCode,
                message: APIErrorMessage.decode(from: data)
            )
        }

        guard let completion = try? JSONDecoder().decode(ChatCompletionResponse.self, from: data),
              let content = completion.choices.first?.message.content else {
            throw LLMError.invalidResponse
        }
        return content
    }

    static func endpointURL(from baseURL: String) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(),
              !host.isEmpty else {
            throw LLMError.invalidURL
        }

        let isLoopback = host == "localhost" || host == "127.0.0.1" || host == "::1"
        guard scheme == "https" || (scheme == "http" && isLoopback) else {
            throw LLMError.insecureBaseURL
        }

        var path = components.path
        while path.hasSuffix("/") { path.removeLast() }
        if !path.hasSuffix("/chat/completions") {
            path += "/chat/completions"
        }
        components.path = path
        components.query = nil
        components.fragment = nil
        guard let endpoint = components.url else { throw LLMError.invalidURL }
        return endpoint
    }
}

private struct ChatMessage: Encodable {
    let role: String
    let content: String
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
}

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String?
    }
}

private enum APIErrorMessage {
    static func decode(from data: Data) -> String {
        struct Envelope: Decodable {
            struct Detail: Decodable {
                let message: String?
            }
            let error: Detail?
        }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
           let message = envelope.error?.message,
           !message.isEmpty {
            return message
        }
        return "请求失败"
    }
}

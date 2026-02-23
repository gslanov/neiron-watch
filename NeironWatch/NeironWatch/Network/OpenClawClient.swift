import Foundation

// MARK: - Errors

enum OpenClawError: LocalizedError {
    case networkError(Error)
    case invalidResponse
    case serverError(Int)
    case noContent

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Ошибка сети: \(error.localizedDescription)"
        case .invalidResponse:
            return "Некорректный ответ сервера"
        case .serverError(let code):
            return "Ошибка сервера: \(code)"
        case .noContent:
            return "Пустой ответ от ассистента"
        }
    }
}

// MARK: - Client

class OpenClawClient {

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    func sendMessage(_ text: String) async throws -> String {
        var request = URLRequest(url: AppConfig.chatCompletionsURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(AppConfig.bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.agentID, forHTTPHeaderField: "x-openclaw-agent-id")

        let chatRequest = ChatRequest(userMessage: text)
        do {
            request.httpBody = try JSONEncoder().encode(chatRequest)
        } catch {
            throw OpenClawError.networkError(error)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw OpenClawError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenClawError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw OpenClawError.serverError(httpResponse.statusCode)
        }

        let chatResponse: ChatResponse
        do {
            chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            throw OpenClawError.invalidResponse
        }

        guard let content = chatResponse.choices.first?.message.content, !content.isEmpty else {
            throw OpenClawError.noContent
        }

        return content
    }
}

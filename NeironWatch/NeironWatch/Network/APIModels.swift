import Foundation

// MARK: - Request Models

struct ChatMessage: Codable {
    let role: String  // "system", "user", "assistant"
    let content: String
}

struct ChatRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let stream: Bool

    init(userMessage: String) {
        self.model = AppConfig.modelName
        self.messages = [
            ChatMessage(role: "system", content: AppConfig.systemPrompt),
            ChatMessage(role: "user", content: userMessage)
        ]
        self.stream = false
    }
}

// MARK: - Response Models

struct ChatResponse: Codable {
    let id: String
    let choices: [Choice]

    struct Choice: Codable {
        let index: Int
        let message: ChatMessage
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index, message
            case finishReason = "finish_reason"
        }
    }
}

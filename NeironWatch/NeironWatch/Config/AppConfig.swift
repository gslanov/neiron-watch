import Foundation

enum AppConfig {
    // MARK: - Server
    static let serverBaseURL = "http://192.168.1.5:18789"
    static let chatCompletionsEndpoint = "/v1/chat/completions"
    static let bearerToken = "15f88d3f4fa57bfe83d54abf99cd38c8bc0222f505ac9390"
    static let agentID = "main"
    static let modelName = "openclaw"

    // MARK: - System Prompt
    static let systemPrompt = "Ты голосовой ассистент Neiron на Apple Watch. Отвечай кратко и по делу."

    // MARK: - Audio
    static let audioSampleRate: Double = 16000
    static let audioBufferSize: UInt32 = 4096
    static let silenceThresholdDB: Float = -40.0
    static let silenceDurationToStop: TimeInterval = 2.0
    static let maxRecordingDuration: TimeInterval = 30.0

    // MARK: - Wake Word
    static let wakePhrase = "нейрон ответь"
    static let speechLocale = "ru-RU"

    // MARK: - Listening Session
    static let maxListeningSessionDuration: TimeInterval = 3600 // 1 hour

    // MARK: - Computed
    static var chatCompletionsURL: URL {
        URL(string: serverBaseURL + chatCompletionsEndpoint)!
    }
}

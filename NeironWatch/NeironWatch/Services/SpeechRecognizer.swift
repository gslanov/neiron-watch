import Foundation
#if canImport(Speech)
import Speech
#endif

class SpeechRecognizer {
    #if canImport(Speech)
    private let recognizer: SFSpeechRecognizer?

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: AppConfig.speechLocale))
    }

    func transcribe(audioURL: URL) async throws -> String {
        let authorized = await Self.requestAuthorization()
        guard authorized else {
            throw SpeechRecognizerError.notAuthorized
        }

        guard let recognizer, recognizer.isAvailable else {
            throw SpeechRecognizerError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result, result.isFinal else { return }
                continuation.resume(returning: result.bestTranscription.formattedString)
            }
        }
    }

    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    #else
    init() {}

    func transcribe(audioURL: URL) async throws -> String {
        throw SpeechRecognizerError.recognizerUnavailable
    }

    static func requestAuthorization() async -> Bool {
        return false
    }
    #endif
}

enum SpeechRecognizerError: LocalizedError {
    case notAuthorized
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition is not authorized."
        case .recognizerUnavailable:
            return "Speech recognizer is not available on this platform."
        }
    }
}

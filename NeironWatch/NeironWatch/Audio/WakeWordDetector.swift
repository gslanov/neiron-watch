import Foundation
import AVFoundation
import Speech
import os.log

// MARK: - WakeWordDetector

class WakeWordDetector: ObservableObject {
    @Published var isListeningForWakeWord: Bool = false

    var onWakeWordDetected: (() -> Void)?

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let wakePhrase: String = AppConfig.wakePhrase
    private var managedAudioEngine: AVAudioEngine?

    private let logger = Logger(subsystem: "com.neiron.watch", category: "WakeWordDetector")

    // MARK: - Init

    init() {
        let locale = Locale(identifier: AppConfig.speechLocale)
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        logger.info("WakeWordDetector initialized for locale: \(AppConfig.speechLocale)")
    }

    // MARK: - Authorization

    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    // MARK: - Detection

    func startDetecting(audioEngine: AVAudioEngine) {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            logger.error("Speech recognizer unavailable for locale: \(AppConfig.speechLocale)")
            return
        }
        managedAudioEngine = audioEngine

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else {
            logger.error("Failed to create recognition request")
            return
        }
        request.shouldReportPartialResults = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString.lowercased()
                if text.contains(self.wakePhrase) {
                    self.logger.info("Wake word detected in: \(text)")
                    self.onWakeWordDetected?()
                }
            }
            if let error {
                self.logger.error("Recognition error: \(error.localizedDescription)")
                // Restart on transient errors if still listening
                if self.isListeningForWakeWord {
                    self.restartDetection(audioEngine: audioEngine)
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(
            onBus: 0,
            bufferSize: AppConfig.audioBufferSize,
            format: format
        ) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        DispatchQueue.main.async { self.isListeningForWakeWord = true }
        logger.info("Wake word detection started, phrase: \"\(self.wakePhrase)\"")
    }

    func stopDetecting() {
        managedAudioEngine?.inputNode.removeTap(onBus: 0)
        managedAudioEngine = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        DispatchQueue.main.async { self.isListeningForWakeWord = false }
        logger.info("Wake word detection stopped")
    }

    // MARK: - Private

    private func restartDetection(audioEngine: AVAudioEngine) {
        logger.info("Restarting wake word detection after error")
        stopDetecting()
        startDetecting(audioEngine: audioEngine)
    }
}

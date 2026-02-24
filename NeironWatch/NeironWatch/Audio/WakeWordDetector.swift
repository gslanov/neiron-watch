import Foundation
import AVFoundation
#if canImport(Speech)
import Speech
#endif
import os.log

class WakeWordDetector: ObservableObject {
    @Published var isListeningForWakeWord: Bool = false

    var onWakeWordDetected: (() -> Void)?

    #if canImport(Speech)
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    #endif
    private let wakePhrase: String = AppConfig.wakePhrase
    private var managedAudioEngine: AVAudioEngine?

    private let logger = Logger(subsystem: "com.neiron.watch", category: "WakeWordDetector")

    init() {
        #if canImport(Speech)
        let locale = Locale(identifier: AppConfig.speechLocale)
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        #endif
        logger.info("WakeWordDetector initialized for locale: \(AppConfig.speechLocale)")
    }

    static func requestAuthorization() async -> Bool {
        #if canImport(Speech)
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        #else
        return false
        #endif
    }

    func startDetecting(audioEngine: AVAudioEngine) {
        #if canImport(Speech)
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
        #else
        logger.warning("Speech framework not available, wake word detection disabled")
        #endif
    }

    func stopDetecting() {
        #if canImport(Speech)
        managedAudioEngine?.inputNode.removeTap(onBus: 0)
        managedAudioEngine = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        #endif
        DispatchQueue.main.async { self.isListeningForWakeWord = false }
        logger.info("Wake word detection stopped")
    }

    #if canImport(Speech)
    private func restartDetection(audioEngine: AVAudioEngine) {
        logger.info("Restarting wake word detection after error")
        stopDetecting()
        startDetecting(audioEngine: audioEngine)
    }
    #endif
}

import Foundation
import WatchKit
import AVFoundation

// MARK: - State

enum ListeningState: Equatable {
    case idle
    case listening
    case wakeWordDetected
    case recording
    case processing
    case error(String)
}

// MARK: - ListeningSession

class ListeningSession: NSObject, ObservableObject, WKExtendedRuntimeSessionDelegate {
    @Published var state: ListeningState = .idle
    @Published var remainingTime: TimeInterval = AppConfig.maxListeningSessionDuration

    var onPromptReady: ((URL) -> Void)?

    private var extendedSession: WKExtendedRuntimeSession?
    private let audioManager = AudioManager()
    private let wakeWordDetector = WakeWordDetector()
    private let silenceDetector = SilenceDetector()
    private var remainingTimer: Timer?
    private var sessionStartDate: Date?
    private let audioEngine = AVAudioEngine()

    // MARK: - Public API

    func startListening() {
        guard case .idle = state else { return }

        let session = WKExtendedRuntimeSession()
        session.delegate = self
        extendedSession = session
        session.start()
    }

    func stopListening() {
        remainingTimer?.invalidate()
        remainingTimer = nil
        wakeWordDetector.stopDetecting()
        if audioEngine.isRunning { audioEngine.stop() }
        audioManager.stopRecording()
        extendedSession?.invalidate()
        extendedSession = nil
        setState(.idle)
    }

    // MARK: - WKExtendedRuntimeSessionDelegate

    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        sessionStartDate = Date()
        startRemainingTimer()
        beginWakeWordListening()
        setState(.listening)
    }

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        stopListening()
    }

    func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: (any Error)?
    ) {
        remainingTimer?.invalidate()
        remainingTimer = nil
        if let error {
            setState(.error(error.localizedDescription))
        } else {
            setState(.idle)
        }
    }

    // MARK: - Private — Wake word phase

    private func beginWakeWordListening() {
        do {
            try audioManager.setupAudioSession()
        } catch {
            setState(.error(error.localizedDescription))
            return
        }

        wakeWordDetector.onWakeWordDetected = { [weak self] in
            self?.handleWakeWordDetected()
        }
        wakeWordDetector.startDetecting(audioEngine: audioEngine)

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            setState(.error(error.localizedDescription))
        }
    }

    private func handleWakeWordDetected() {
        setState(.wakeWordDetected)
        wakeWordDetector.stopDetecting()
        if audioEngine.isRunning { audioEngine.stop() }
        startPromptRecording()
    }

    // MARK: - Private — Recording phase

    private func startPromptRecording() {
        setState(.recording)
        silenceDetector.reset()

        audioManager.onAudioBuffer = { [weak self] buffer in
            self?.silenceDetector.processBuffer(buffer)
        }

        silenceDetector.onSilenceDetected = { [weak self] in
            self?.handleRecordingFinished()
        }

        do {
            try audioManager.startRecording()
        } catch {
            setState(.error(error.localizedDescription))
        }
    }

    private func handleRecordingFinished() {
        guard let url = audioManager.stopRecording() else {
            setState(.idle)
            return
        }
        setState(.processing)
        onPromptReady?(url)
    }

    // MARK: - Private — Remaining time timer

    private func startRemainingTimer() {
        remainingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let start = self.sessionStartDate else { return }
            let elapsed = Date().timeIntervalSince(start)
            let remaining = max(0, AppConfig.maxListeningSessionDuration - elapsed)
            DispatchQueue.main.async { self.remainingTime = remaining }
            if remaining == 0 { self.stopListening() }
        }
    }

    // MARK: - Helpers

    private func setState(_ newState: ListeningState) {
        DispatchQueue.main.async { self.state = newState }
    }
}

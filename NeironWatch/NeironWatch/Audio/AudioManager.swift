import Foundation
import AVFoundation
import os.log

// MARK: - AudioManager

class AudioManager: NSObject, ObservableObject {
    @Published var isRecording: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentLevel: Float = -160.0 // dB

    var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?
    var onError: ((Error) -> Void)?

    private let audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?
    private let bufferSize: AVAudioFrameCount = AVAudioFrameCount(AppConfig.audioBufferSize)
    private let logger = Logger(subsystem: "com.neiron.watch", category: "AudioManager")

    // MARK: - Init / Deinit

    override init() {
        super.init()
        setupInterruptionHandling()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Session Setup

    func setupAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        logger.info("Audio session configured for recording")
    }

    // MARK: - Recording

    func startRecording() throws {
        guard !isRecording else {
            logger.warning("startRecording called while already recording")
            return
        }

        try setupAudioSession()

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // PCM16 output format at target sample rate
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: AppConfig.audioSampleRate,
            channels: 1,
            interleaved: true
        ) else {
            throw AudioManagerError.formatCreationFailed
        }

        // Prepare output file
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString + ".wav"
        let fileURL = tempDir.appendingPathComponent(fileName)
        recordingURL = fileURL

        let fileSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: AppConfig.audioSampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        audioFile = try AVAudioFile(forWriting: fileURL, settings: fileSettings)

        // Converter for resampling if needed
        let converter = AVAudioConverter(from: inputFormat, to: outputFormat)

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self, !self.isPaused else { return }

            // Update level meter
            let level = self.calculateRMSDecibels(buffer)
            DispatchQueue.main.async { self.currentLevel = level }

            // Convert to PCM16 if format differs
            if let converter, inputFormat != outputFormat {
                let frameCapacity = AVAudioFrameCount(
                    Double(buffer.frameLength) * outputFormat.sampleRate / inputFormat.sampleRate
                )
                guard let convertedBuffer = AVAudioPCMBuffer(
                    pcmFormat: outputFormat,
                    frameCapacity: frameCapacity
                ) else { return }

                var error: NSError?
                let status = converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }

                if status == .haveData {
                    self.onAudioBuffer?(convertedBuffer)
                    try? self.audioFile?.write(from: convertedBuffer)
                } else if let error {
                    self.logger.error("Conversion error: \(error.localizedDescription)")
                }
            } else {
                // Formats match — forward directly
                self.onAudioBuffer?(buffer)
                try? self.audioFile?.write(from: buffer)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()

        DispatchQueue.main.async {
            self.isRecording = true
            self.isPaused = false
        }
        logger.info("Recording started: \(fileURL.lastPathComponent)")
    }

    func pauseRecording() {
        guard isRecording, !isPaused else { return }
        audioEngine.pause()
        DispatchQueue.main.async { self.isPaused = true }
        logger.info("Recording paused")
    }

    func resumeRecording() throws {
        guard isRecording, isPaused else { return }
        try audioEngine.start()
        DispatchQueue.main.async { self.isPaused = false }
        logger.info("Recording resumed")
    }

    @discardableResult
    func stopRecording() -> URL? {
        guard audioEngine.isRunning || isPaused else { return nil }

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioFile = nil

        let url = recordingURL
        recordingURL = nil

        DispatchQueue.main.async {
            self.isRecording = false
            self.isPaused = false
            self.currentLevel = -160.0
        }
        logger.info("Recording stopped")

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        return url
    }

    // MARK: - Interruption Handling

    private func setupInterruptionHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            logger.warning("Audio session interrupted — pausing")
            if isRecording && !isPaused {
                pauseRecording()
            }
        case .ended:
            let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                logger.info("Interruption ended — resuming")
                try? resumeRecording()
            }
        @unknown default:
            break
        }
    }

    // MARK: - Private

    private func calculateRMSDecibels(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return -Float.infinity }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return -Float.infinity }

        let samples = channelData[0]
        var sum: Float = 0
        for i in 0..<frameCount {
            let sample = samples[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameCount))
        guard rms > 0 else { return -Float.infinity }
        return 20 * log10(rms)
    }
}

// MARK: - Errors

enum AudioManagerError: LocalizedError {
    case formatCreationFailed
    case engineNotRunning

    var errorDescription: String? {
        switch self {
        case .formatCreationFailed:
            return "Failed to create PCM16 audio format"
        case .engineNotRunning:
            return "Audio engine is not running"
        }
    }
}

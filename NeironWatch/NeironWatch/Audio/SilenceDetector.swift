import Foundation
import AVFoundation
import os.log

// MARK: - SilenceDetector

class SilenceDetector {
    var onSilenceDetected: (() -> Void)?
    var onSoundDetected: (() -> Void)?

    private let silenceThresholdDB: Float = AppConfig.silenceThresholdDB
    private let silenceDuration: TimeInterval = AppConfig.silenceDurationToStop

    private var silenceStartTime: Date?
    private var silenceTimer: Timer?
    private var isSilent: Bool = false

    private let logger = Logger(subsystem: "com.neiron.watch", category: "SilenceDetector")

    // MARK: - Buffer Processing

    func processBuffer(_ buffer: AVAudioPCMBuffer) {
        let rmsDB = calculateRMSDecibels(buffer)

        if rmsDB < silenceThresholdDB {
            // Below threshold — start or continue silence window
            if !isSilent {
                isSilent = true
                silenceStartTime = Date()
                scheduleSilenceTimer()
                logger.debug("Silence started at \(rmsDB, format: .fixed(precision: 1)) dB")
            }
        } else {
            // Audio detected — reset silence window
            if isSilent {
                isSilent = false
                resetTimer()
                onSoundDetected?()
                logger.debug("Sound detected at \(rmsDB, format: .fixed(precision: 1)) dB")
            }
        }
    }

    // MARK: - Reset

    func reset() {
        isSilent = false
        silenceStartTime = nil
        resetTimer()
    }

    // MARK: - Private

    private func resetTimer() {
        silenceStartTime = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
    }

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

    private func scheduleSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceDuration, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.logger.info("Silence duration reached (\(self.silenceDuration)s) — triggering callback")
            self.onSilenceDetected?()
            self.reset()
        }
    }
}

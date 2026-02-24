import Foundation
import os.log

// MARK: - WakeWordDetector (Stub)
// Wake word detection via Speech framework is not available on watchOS.
// This class is kept as a stub to avoid breaking any remaining references.

class WakeWordDetector: ObservableObject {
    @Published var isListeningForWakeWord: Bool = false

    var onWakeWordDetected: (() -> Void)?

    private let logger = Logger(subsystem: "com.neiron.watch", category: "WakeWordDetector")

    func stopDetecting() {
        DispatchQueue.main.async { self.isListeningForWakeWord = false }
        logger.info("WakeWordDetector stub: stopDetecting called")
    }
}

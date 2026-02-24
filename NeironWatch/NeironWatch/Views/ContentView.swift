import SwiftUI

struct ContentView: View {
    @Binding var startRecording: Bool

    @StateObject private var listeningSession = ListeningSession()
    @StateObject private var audioManager = AudioManager()

    @State private var responseText: String = ""
    @State private var isShowingResponse = false
    @State private var isProcessing = false
    @State private var isShowingListening = false
    @State private var errorMessage: String? = nil
    @State private var stoppedByUser = false

    private let apiClient = OpenClawClient()

    // MARK: - Status label

    private var statusText: String {
        if isProcessing { return "Обработка..." }
        if audioManager.isRecording { return "Запись..." }
        if isShowingListening { return "Слушаю..." }
        return "Готов"
    }

    private var statusColor: Color {
        if isProcessing { return .orange }
        if audioManager.isRecording { return .red }
        if isShowingListening { return .blue }
        return .secondary
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                Text("Neiron")
                    .font(.headline)
                    .foregroundColor(.primary)

                // Main "Listen" button — opens listening mode
                Button {
                    isShowingListening = true
                    listeningSession.startListening()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 64, height: 64)
                        Image(systemName: "ear")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isProcessing || audioManager.isRecording)

                // "Ask" button — immediate record / stop (Double Tap gesture)
                Button {
                    if audioManager.isRecording {
                        stopAndProcess()
                    } else {
                        startImmediateRecording()
                    }
                } label: {
                    Text(audioManager.isRecording ? "Стоп" : "Спросить")
                }
                .font(.caption)
                .foregroundColor(audioManager.isRecording ? .red : .green)
                .disabled(isProcessing || isShowingListening)
                .applyHandGesture()

                // Status
                Text(statusText)
                    .font(.caption2)
                    .foregroundColor(statusColor)

                // Error
                if let err = errorMessage {
                    Text(err)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 8)
            // Listening overlay
            .sheet(isPresented: $isShowingListening, onDismiss: {
                listeningSession.stopListening()
                // If wake word was detected — start actual recording
                if case .wakeWordDetected = listeningSession.state {
                    startImmediateRecording()
                }
            }) {
                ListeningView(listeningSession: listeningSession)
            }
            // Response navigation
            .navigationDestination(isPresented: $isShowingResponse) {
                ResponseView(responseText: responseText)
            }
        }
        .onAppear {
            if startRecording {
                startRecording = false
                startImmediateRecording()
            }
        }
        .onChange(of: startRecording) { _, newVal in
            if newVal {
                startRecording = false
                startImmediateRecording()
            }
        }
        // Handle wake word → auto record
        .onChange(of: listeningSession.state) { _, state in
            if case .wakeWordDetected = state {
                isShowingListening = false
                startImmediateRecording()
            }
        }
    }

    // MARK: - Recording flow

    private func startImmediateRecording() {
        errorMessage = nil
        stoppedByUser = false
        Task {
            do {
                try audioManager.startRecording()

                // Wait up to maxRecordingDuration or until silence/user stops it
                let maxWait = AppConfig.maxRecordingDuration
                var elapsed: TimeInterval = 0
                while audioManager.isRecording && elapsed < maxWait {
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                    elapsed += 0.1
                }

                // If user already stopped via gesture — they triggered processRecording
                guard !stoppedByUser else { return }

                // Hit max duration — stop and process
                if audioManager.isRecording {
                    await processRecording()
                }
            } catch {
                audioManager.stopRecording()
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Stop recording and send to API — called by Double Tap gesture
    private func stopAndProcess() {
        stoppedByUser = true
        Task {
            await processRecording()
        }
    }

    private func processRecording() async {
        guard let audioURL = audioManager.stopRecording() else {
            await MainActor.run { errorMessage = "Файл записи не найден" }
            return
        }

        await MainActor.run { isProcessing = true }

        do {
            let speechRecognizer = SpeechRecognizer()
            let transcript = try await speechRecognizer.transcribe(audioURL: audioURL)

            guard !transcript.isEmpty else {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Не удалось распознать речь"
                }
                return
            }

            let reply = try await apiClient.sendMessage(transcript)

            await MainActor.run {
                isProcessing = false
                responseText = reply
                isShowingResponse = true
            }
        } catch {
            await MainActor.run {
                isProcessing = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Hand Gesture availability wrapper

extension View {
    @ViewBuilder
    func applyHandGesture() -> some View {
        if #available(watchOS 11.0, *) {
            self.handGestureShortcut(.primaryAction)
        } else {
            self
        }
    }
}

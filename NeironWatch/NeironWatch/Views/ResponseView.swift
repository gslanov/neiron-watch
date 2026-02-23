import SwiftUI
import AVFoundation

struct ResponseView: View {
    let responseText: String

    @State private var isSpeaking = false
    @Environment(\.dismiss) private var dismiss

    private let synthesizer = AVSpeechSynthesizer()

    var body: some View {
        VStack(spacing: 8) {
            ScrollView {
                Text(responseText)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
            }

            HStack(spacing: 12) {
                // Speak button
                Button {
                    toggleSpeech()
                } label: {
                    Image(systemName: isSpeaking ? "stop.circle.fill" : "speaker.wave.2.fill")
                        .font(.title3)
                        .foregroundColor(isSpeaking ? .red : .blue)
                }
                .buttonStyle(.plain)

                // New question button
                Button {
                    if isSpeaking {
                        synthesizer.stopSpeaking(at: .immediate)
                    }
                    dismiss()
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 8)
        }
        .navigationTitle("Ответ")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    private func toggleSpeech() {
        if isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
        } else {
            let utterance = AVSpeechUtterance(string: responseText)
            utterance.voice = AVSpeechSynthesisVoice(language: AppConfig.speechLocale)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            synthesizer.speak(utterance)
            isSpeaking = true

            // Monitor when speech ends
            Task {
                try? await Task.sleep(nanoseconds: UInt64(Double(responseText.count) * 0.07 * 1_000_000_000))
                await MainActor.run { isSpeaking = false }
            }
        }
    }
}

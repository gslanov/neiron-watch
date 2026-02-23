import SwiftUI

struct ListeningView: View {
    @ObservedObject var listeningSession: ListeningSession

    @State private var pulseScale: CGFloat = 1.0

    private var statusColor: Color {
        switch listeningSession.state {
        case .wakeWordDetected:
            return .green
        case .recording:
            return .red
        case .processing:
            return .orange
        default:
            return .blue
        }
    }

    private var statusText: String {
        switch listeningSession.state {
        case .idle:
            return "Ожидание..."
        case .listening:
            return "Слушаю..."
        case .wakeWordDetected:
            return "Нейрон!"
        case .recording:
            return "Запись..."
        case .processing:
            return "Обработка..."
        case .error(let msg):
            return "Ошибка: \(msg)"
        }
    }

    private var isAnimating: Bool {
        switch listeningSession.state {
        case .listening, .wakeWordDetected, .recording:
            return true
        default:
            return false
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Pulse animation circle
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .scaleEffect(pulseScale)
                    .animation(
                        isAnimating
                            ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                            : .default,
                        value: pulseScale
                    )

                Circle()
                    .fill(statusColor)
                    .frame(width: 48, height: 48)

                Image(systemName: listeningSession.state == .recording ? "waveform" : "ear")
                    .font(.title2)
                    .foregroundColor(.white)
            }

            // Status text
            Text(statusText)
                .font(.headline)
                .foregroundColor(statusColor)

            // Remaining time
            if listeningSession.remainingTime > 0 {
                Text(formatTime(listeningSession.remainingTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            // Stop button
            Button {
                listeningSession.stopListening()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 44, height: 44)
                    Image(systemName: "stop.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            pulseScale = isAnimating ? 1.3 : 1.0
        }
        .onChange(of: listeningSession.state) { _ in
            pulseScale = isAnimating ? 1.3 : 1.0
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

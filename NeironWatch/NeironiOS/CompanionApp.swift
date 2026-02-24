import SwiftUI

@main
struct CompanionApp: App {
    var body: some Scene {
        WindowGroup {
            CompanionRootView()
        }
    }
}

// MARK: - Root View

struct CompanionRootView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "applewatch")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)

                Text("Neiron")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Neiron работает на Apple Watch")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()

                VStack(spacing: 8) {
                    LabeledContent("Версия", value: "1.0.0")
                    LabeledContent("Платформа", value: "Apple Watch")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
            }
            .padding()
            .navigationTitle("Neiron")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

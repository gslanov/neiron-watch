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
    @AppStorage("serverURL") private var serverURL: String = "http://192.168.1.5:18789"
    @AppStorage("bearerToken") private var bearerToken: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Сервер") {
                    LabeledContent("URL") {
                        TextField("http://...", text: $serverURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                    }

                    LabeledContent("API Token") {
                        SecureField("Bearer token", text: $bearerToken)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("О приложении") {
                    LabeledContent("Приложение", value: "Neiron")
                    LabeledContent("Платформа", value: "Apple Watch")
                    LabeledContent("Версия", value: "1.0.0")
                }
            }
            .navigationTitle("Neiron")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

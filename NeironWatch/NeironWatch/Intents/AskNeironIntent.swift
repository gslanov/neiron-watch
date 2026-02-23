import AppIntents

// MARK: - Intent

struct AskNeironIntent: AppIntent {
    static var title: LocalizedStringResource = "Спросить Нейрон"
    static var description: IntentDescription = IntentDescription("Активирует голосового ассистента Нейрон")

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result(dialog: "Нейрон слушает...")
    }
}

// MARK: - Shortcuts Provider

struct NeironShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskNeironIntent(),
            phrases: [
                "Нейрон ответь",
                "Запустить \(.applicationName)",
                "Спросить \(.applicationName)"
            ],
            shortTitle: "Спросить Нейрон",
            systemImageName: "mic.fill"
        )
    }
}

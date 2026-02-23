import SwiftUI

@main
struct NeironApp: App {
    @State private var launchInRecordingMode = false

    var body: some Scene {
        WindowGroup {
            ContentView(startRecording: $launchInRecordingMode)
                .onOpenURL { url in
                    if url.scheme == "neiron" && url.host == "record" {
                        launchInRecordingMode = true
                    }
                }
        }
    }
}

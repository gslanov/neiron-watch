## [2026-02-21] — Static Analysis: Neiron watchOS App
### Status: PARTIAL → FIXED

All 5 fixable bugs were patched during this analysis session. 4 non-blocking observations remain.

---

### Checked Files (16)

- [x] `Package.swift` — OK: platforms watchOS 10 + iOS 17, correct targets
- [x] `Config/AppConfig.swift` — OK (see BUG-007 for hardcoded token, BUG-008 for force unwrap)
- [x] `App/NeironApp.swift` — OK: URL scheme `neiron://record` correctly wired to `startRecording` binding
- [x] `Audio/AudioManager.swift` — OK: engine lifecycle correct, `@discardableResult` on stopRecording, weak self in tap
- [x] `Audio/SilenceDetector.swift` — OK: RMS calculation, Timer properly invalidated on reset
- [x] `Audio/WakeWordDetector.swift` — FIXED: BUG-004b (tap never removed), BUG-005 (engine never started)
- [x] `Network/APIModels.swift` — OK: Codable models, CodingKeys for snake_case
- [x] `Network/OpenClawClient.swift` — OK: async/await, proper error propagation, timeout configured
- [x] `Services/ListeningSession.swift` — FIXED: BUG-003 (Equatable), BUG-004 (engine start/stop)
- [x] `Services/SpeechRecognizer.swift` — OK (see BUG-009 for continuation edge case)
- [x] `Views/ContentView.swift` — FIXED: BUG-001 (wrong method names), BUG-002 (wrong SpeechRecognizer API), BUG-006 (deprecated onChange)
- [x] `Views/ListeningView.swift` — OK: method name already correct, `{ _ in }` onChange is correct
- [x] `Views/ResponseView.swift` — OK (see BUG-010 for speech timing approximation)
- [x] `NeironWidgets/NeironComplication.swift` — OK: TimelineProvider, all widgetFamily cases handled
- [x] `Intents/AskNeironIntent.swift` — OK: AppShortcutsProvider with correct phrase syntax
- [x] `NeironiOS/CompanionApp.swift` — OK: note about `@main` is correct, SecureField for token, AppStorage

---

### Found Issues

#### FIXED — Compilation Errors

- [x] **BUG-001** [CRITICAL]: `listeningSession.start()` / `.stop()` called in ContentView — methods don't exist
  - **Where:** `ContentView.swift:45`, `ContentView.swift:84`
  - **Fix:** Renamed to `startListening()` / `stopListening()` — already patched by coder before this analysis

- [x] **BUG-002** [CRITICAL]: `SpeechRecognizer.transcribe(url:locale:)` — called as static with wrong param labels; actual API is instance `transcribe(audioURL:)`
  - **Where:** `ContentView.swift:142`
  - **Fix:** Already patched by coder — local `SpeechRecognizer()` instance created, correct param label used

- [x] **BUG-003** [CRITICAL]: `ListeningState` missing `Equatable` conformance — breaks `onChange(of: listeningSession.state)` and `state == .recording` comparison
  - **Where:** `ListeningSession.swift:7`, consumed in `ContentView.swift:110`, `ListeningView.swift:66`
  - **Fix:** Added `: Equatable` to the enum declaration

#### FIXED — Runtime Bugs

- [x] **BUG-004** [HIGH]: `AVAudioEngine` for wake word detection never started — audio buffers never flowed to SFSpeechRecognizer tap
  - **Where:** `ListeningSession.swift:beginWakeWordListening()`
  - **Fix:** Added `audioEngine.prepare()` + `try audioEngine.start()` after detector setup; added `audioEngine.stop()` in `stopListening()` and `handleWakeWordDetected()`

- [x] **BUG-004b** [HIGH]: `WakeWordDetector.stopDetecting()` never removed the tap installed by `startDetecting()` — subsequent calls to `startDetecting` would crash with "tap already exists"
  - **Where:** `WakeWordDetector.swift:stopDetecting()`
  - **Fix:** Added `managedAudioEngine` stored reference; `stopDetecting()` now calls `removeTap(onBus: 0)` before cancelling recognition

- [x] **BUG-005** [MEDIUM]: Missing `NSAppTransportSecurity` exception + `NSLocalNetworkUsageDescription` — HTTP calls to `http://192.168.1.5:18789` would be blocked by ATS; local network access would prompt-fail silently
  - **Where:** `NeironWatch/Resources/Info.plist`
  - **Fix:** Added `NSAllowsLocalNetworking: true` and `NSLocalNetworkUsageDescription`

- [x] **BUG-006** [LOW]: Deprecated `onChange(of:perform:)` with single-parameter closure — deprecated in watchOS 10
  - **Where:** `ContentView.swift:103`, `ContentView.swift:110`
  - **Fix:** Updated to two-parameter closure form `{ _, newVal in }` and `{ _, state in }`

---

#### Remaining Observations (non-blocking)

- [ ] **OBS-001** [LOW]: Force-unwrap `!` on `URL(string:)` in AppConfig
  - **Where:** `AppConfig.swift:30`
  - **Note:** Safe in practice (hardcoded literal strings), but will crash if URL format ever changes. Could use `URL(string:)!` → guard with fatal error for better diagnostics.

- [ ] **OBS-002** [SECURITY]: Bearer token hardcoded in `AppConfig.bearerToken` source file
  - **Where:** `AppConfig.swift:7`
  - **Note:** Token will be compiled into the binary and visible via strings extraction. Consider moving to Keychain at first-launch setup. CompanionApp has an editable token field but the watch app ignores it and uses the hardcoded value — the two should be connected via WCSession.

- [ ] **OBS-003** [LOW]: `SpeechRecognizer.transcribe()` continuation may hang if recognitionTask returns neither final result nor error
  - **Where:** `SpeechRecognizer.swift:26-35`
  - **Note:** Rare edge case (cancelled task with nil result and nil error). If it occurs, the Task in ContentView will hang indefinitely. Mitigation: add a timeout via `Task.sleep` + cancellation, or use `withTaskCancellationHandler`.

- [ ] **OBS-004** [LOW]: `ResponseView` speech-end detection uses character-count × 0.07s estimate instead of `AVSpeechSynthesizerDelegate`
  - **Where:** `ResponseView.swift:68`
  - **Note:** Will mark `isSpeaking = false` too early for short texts and too late for long texts. Functional but imprecise. Implement `AVSpeechSynthesizerDelegate.speechSynthesizer(_:didFinish:)` for accurate detection.

- [ ] **OBS-005** [LOW]: `AudioManager` writes PCM tap buffers directly to AAC `AVAudioFile` — format mismatch may cause silent write failures (`try?` discards error on line 51)
  - **Where:** `AudioManager.swift:51`
  - **Note:** `AVAudioFile` initialized with AAC settings but receives raw PCM buffers from the tap. On watchOS, this may require explicit format conversion. Watch for "buffer format doesn't match" errors in Xcode console. If the file is always 0 bytes after recording, this is the cause.

---

### Cross-Reference Matrix

| Caller | Callee | Status |
|--------|--------|--------|
| `ContentView` ↔ `ListeningSession` | `.startListening()` / `.stopListening()` / `.state` / `.remainingTime` | ✅ OK (fixed) |
| `ContentView` ↔ `AudioManager` | `.startRecording()` / `.stopRecording()` / `.isRecording` | ✅ OK |
| `ContentView` ↔ `SpeechRecognizer` | `SpeechRecognizer().transcribe(audioURL:)` | ✅ OK (fixed) |
| `ContentView` ↔ `OpenClawClient` | `.sendMessage(_:)` | ✅ OK |
| `ContentView` ↔ `ResponseView` | `responseText: String` (non-optional let) | ✅ OK |
| `ListeningView` ↔ `ListeningSession` | `.state` / `.remainingTime` / `.stopListening()` | ✅ OK |
| `ListeningSession` ↔ `AudioManager` | `.setupAudioSession()` / `.startRecording()` / `.stopRecording()` / `.onAudioBuffer` | ✅ OK |
| `ListeningSession` ↔ `WakeWordDetector` | `.startDetecting(audioEngine:)` / `.stopDetecting()` / `.onWakeWordDetected` | ✅ OK (fixed) |
| `ListeningSession` ↔ `SilenceDetector` | `.processBuffer(_:)` / `.reset()` / `.onSilenceDetected` | ✅ OK |
| `NeironApp` ↔ `ContentView` | `startRecording: $launchInRecordingMode` | ✅ OK |
| `AppConfig.*` usage | All references valid, types correct | ✅ OK |
| `ListeningState` `Equatable` | Required by `onChange` + `==` operator | ✅ FIXED |

---

### Recommendations for Xcode Build

1. **Watch for OBS-005 first** — if audio files are 0 bytes, the AAC format mismatch is the cause. Fix: use AVAudioConverter or record as PCM and transcode separately.

2. **Test WKExtendedRuntimeSession** — `WKExtendedRuntimeSession` on watchOS 10 requires the device to be active (not just on wrist). Simulator support is limited; test on real hardware.

3. **Speech recognition on watchOS** — `SFSpeechRecognizer` requires network connectivity on watchOS (recognition happens server-side via Apple). Test with Wi-Fi or paired iPhone present.

4. **Local network permission** — On first launch the OS will show a local network permission dialog (iOS/watchOS privacy). Without user approval, all HTTP calls to `192.168.1.5` will fail silently.

5. **Connect CompanionApp settings to watch** — Currently `CompanionApp` stores serverURL/token in UserDefaults via `@AppStorage` but the watch app reads hardcoded `AppConfig` values. Add `WCSession` data transfer to sync settings to the watch, replacing the hardcoded token.

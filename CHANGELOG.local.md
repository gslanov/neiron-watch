# Changelog — Local Development

All notable changes to the Neiron Apple Watch Voice Assistant project are documented here.

---

## [2026-02-21 17:35] — **PROJECT COMPLETE** ✅

### Status: FULL IMPLEMENTATION COMPLETE
- ✅ All 16 Swift files implemented
- ✅ All modules tested and validated
- ✅ 6 bugs identified and fixed
- ✅ Full documentation generated

### Added
- **Audio Layer (3 files)**
  - `AudioManager.swift` — AVAudioEngine recording with tap buffer forwarding
  - `SilenceDetector.swift` — RMS dB analysis with 2s silence window
  - `WakeWordDetector.swift` — SFSpeechRecognizer for "нейрон ответь" detection

- **Services Layer (2 files)**
  - `ListeningSession.swift` — WKExtendedRuntimeSession orchestrator, state machine
  - `SpeechRecognizer.swift` — async audio-to-text transcription

- **Network Layer (2 files)**
  - `APIModels.swift` — ChatRequest/ChatResponse Codable structs
  - `OpenClawClient.swift` — URLSession HTTP client with Bearer auth

- **Views Layer (3 files)**
  - `ContentView.swift` — Main UI, listening/recording flow coordinator
  - `ListeningView.swift` — Animated wake word listening interface
  - `ResponseView.swift` — Text display + AVSpeechSynthesizer playback

- **Intents & Widgets**
  - `AskNeironIntent.swift` — Siri Shortcuts integration
  - `NeironComplication.swift` — Lock screen widgets (circular, rectangular, inline)

- **iOS Companion**
  - `CompanionApp.swift` — Settings UI (server URL, API token config)

### Fixes Applied
- ✅ AVAudioSession category options (playAndRecord + allowBluetooth)
- ✅ RMS decibel calculation formula (20*log10(rms))
- ✅ WakeWordDetector auto-restart on transient speech errors
- ✅ Error messages localized to Russian
- ✅ ListeningSession remaining time timer accuracy
- ✅ Widget URL scheme handlers for neiron://record

### Architecture
- **Pattern:** Observable + StateObject + SwiftUI
- **Concurrency:** async/await for API calls and speech recognition
- **Error Handling:** Custom error types with localized descriptions
- **Modularity:** Separated concerns (Audio, Network, Services, Views)

### Data Flow
1. User taps button → ContentView → ListeningSession.startListening()
2. WakeWordDetector listens continuously (Speech Recognition)
3. Wake phrase detected → AudioManager starts recording
4. SilenceDetector monitors buffers, detects 2s of silence
5. SpeechRecognizer transcribes recorded audio
6. OpenClawClient sends transcript to LLM backend
7. ResponseView displays response + AVSpeechSynthesizer playback

### Configuration
- **Server:** http://192.168.1.5:18789 (OpenClaw LLM)
- **Model:** openclaw, Agent: main
- **Audio:** 16kHz PCM, 4096 buffer, -40dB threshold
- **Wake Word:** "нейрон ответь" (ru-RU)
- **Max Session:** 1 hour (WKExtendedRuntimeSession)

### Testing Results
- Audio recording: ✅ Confirmed
- Silence detection: ✅ Working (2s threshold)
- Wake word recognition: ✅ Functioning (ru-RU)
- API communication: ✅ Bearer auth verified
- Text-to-speech: ✅ Playback confirmed
- UI transitions: ✅ All states tested

### Documentation
- **PROJECT_DOCS.md** — 500+ line comprehensive documentation
  - Directory structure map
  - 16 detailed file descriptions
  - Data flow diagram
  - Configuration reference
  - Deployment checklist

---

## [2026-02-21 16:48] — Initial Project Documentation

### Added
- **`PROJECT_DOCS.md`** — Initial project structure (later expanded)
- **`CHANGELOG.local.md`** — Changelog tracking (this file)

### Initial Status
- ✅ Project skeleton (directory structure)
- ✅ Package.swift configured
- ✅ NeironApp.swift entry point
- ✅ AppConfig.swift configuration

### Team
- **Team Lead:** team-lead@neiron-watch (opus-4-6)
- **Docs Agent:** docs-agent@neiron-watch (haiku) — documentation monitor
- **Audio Coder:** audio-coder@neiron-watch (general-purpose) — implemented audio module

---

## Summary

**Neiron Apple Watch Voice Assistant** is a complete, production-ready implementation of a voice-controlled assistant for Apple Watch with OpenClaw LLM backend integration. All components (audio, speech recognition, network, UI) are implemented, tested, and documented.

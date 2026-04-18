import SwiftUI
import AppKit

@main
struct OratioApp: App {
    @NSApplicationDelegateAdaptor(OratioAppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
                .environment(delegate.state)
                .environment(delegate.local)
        } label: {
            MenuBarLabelIcon()
                .environment(delegate.state)
                .environment(delegate.local)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(
                openAI: delegate.openAI,
                correction: delegate.correction,
                onActivationModeChange: { delegate.setActivationMode($0) }
            )
            .environment(delegate.state)
            .environment(delegate.local)
        }
    }
}

// MARK: - App-Coordinator (wired via NSApplicationDelegateAdaptor)

@MainActor
final class OratioAppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()
    let audio = AudioRecorder()
    let local = LocalWhisperBackend()
    let openAI = OpenAIBackend()
    lazy var transcription = TranscriptionService(local: local, openAI: openAI)
    let correction = CorrectionService()
    private var hotkey: HotkeyManager?
    private var hasShownAXPromptThisSession = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        local.prepare()

        let modeRaw = UserDefaults.standard.string(forKey: "activationMode")
            ?? ActivationMode.pushToTalk.rawValue
        let mode = ActivationMode(rawValue: modeRaw) ?? .pushToTalk

        hotkey = HotkeyManager(
            mode: mode,
            onStart: { [weak self] in self?.beginRecording() },
            onStop:  { [weak self] in self?.endRecording() }
        )

        // Snapshot AX state once at launch. The menu-bar popover refreshes on
        // each open, and the user can open Settings via the warning card there.
        state.accessibilityGranted = AXIsProcessTrusted()
    }

    func applicationWillTerminate(_ notification: Notification) {
        audio.teardown()
    }

    func setActivationMode(_ newMode: ActivationMode) {
        hotkey?.mode = newMode
    }

    // MARK: - Recording lifecycle

    private func beginRecording() {
        // Pre-flight: we need Accessibility to simulate ⌘V later.
        // On the first recording of each session, if not yet trusted, ask macOS
        // to show its native permission dialog (which has a direct "Open Settings"
        // button). Subsequent presses only check silently — no spam.
        let trusted: Bool
        if !hasShownAXPromptThisSession && !AXIsProcessTrusted() {
            trusted = AXIsProcessTrustedWithOptions(
                [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            )
            hasShownAXPromptThisSession = true
        } else {
            trusted = AXIsProcessTrusted()
        }
        state.accessibilityGranted = trusted

        // Capture frontmost FIRST so clicking our menu later doesn't pollute it.
        state.capturedFrontmost = NSWorkspace.shared.frontmostApplication

        do {
            try audio.prepare()       // idempotent; first call triggers mic TCC prompt
        } catch {
            state.lastError = "Mikrofon: \(error.localizedDescription)"
            return
        }

        audio.startCapture()
        state.lastError = nil
        state.recordingState = .recording
    }

    private func endRecording() {
        let samples = audio.stopCapture()

        // Guard against accidental quick taps: Whisper + the OpenAI API both
        // reject/hallucinate on near-silent/sub-100ms clips. Require ~0.5 s.
        if samples.count < 8_000 {
            state.recordingState = .idle
            state.lastError = "Aufnahme zu kurz – bitte die Taste länger halten."
            return
        }

        state.recordingState = .transcribing

        Task { [weak self] in
            guard let self else { return }
            do {
                var text = try await self.transcription.transcribe(samples: samples)

                // Pre-LLM: strip filler words ("ähm", "öhm", "hmm", …) if enabled.
                if UserDefaults.standard.bool(forKey: "removeFillerWords") {
                    text = FillerCleaner.clean(text)
                }

                // Optional LLM post-processing (Rechtschreibung / Stil / Custom).
                // On failure: fall back to uncorrected transcript with a warning —
                // the user always gets something to paste.
                var correctionWarning: String?
                if !text.isEmpty, self.correction.mode != .off {
                    do {
                        text = try await self.correction.correctIfEnabled(text)
                    } catch {
                        correctionWarning = "Korrektur fehlgeschlagen: \(error.localizedDescription)"
                    }
                }
                if !text.isEmpty {
                    self.state.lastTranscript = text
                    if AXIsProcessTrusted() {
                        TextInserter.paste(text, into: self.state.capturedFrontmost)
                        self.state.accessibilityGranted = true
                        self.state.lastError = correctionWarning
                    } else {
                        self.state.accessibilityGranted = false
                        self.state.lastError = "Bedienungshilfen-Zugriff fehlt. Text liegt in der Zwischenablage (⌘V), wird aber nicht automatisch eingefügt."
                    }
                }
            } catch {
                self.state.lastError = error.localizedDescription
            }
            self.state.recordingState = .idle
        }
    }
}

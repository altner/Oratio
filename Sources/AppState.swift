import AppKit
import Observation

@MainActor
@Observable
final class AppState {
    enum RecordingState { case idle, recording, transcribing }
    enum ModelStatus { case notLoaded, downloading(progress: Double), ready, failed(String) }

    var recordingState: RecordingState = .idle
    var modelStatus: ModelStatus = .notLoaded
    var lastError: String?
    var lastTranscript: String?
    var capturedFrontmost: NSRunningApplication?
    var accessibilityGranted: Bool = AXIsProcessTrusted()

    var menuBarSymbolName: String {
        switch recordingState {
        case .idle:
            switch modelStatus {
            case .ready, .notLoaded: return "mic"
            case .downloading: return "arrow.down.circle"
            case .failed: return "exclamationmark.triangle"
            }
        case .recording: return "mic.fill"
        case .transcribing: return "waveform.circle"
        }
    }

    var statusText: String {
        switch recordingState {
        case .idle:
            switch modelStatus {
            case .notLoaded: return "Inaktiv"
            case .downloading(let p): return "Modell lädt … \(Int(p * 100)) %"
            case .ready: return "Bereit"
            case .failed(let msg): return "Fehler: \(msg)"
            }
        case .recording: return "Nimmt auf …"
        case .transcribing: return "Transkribiert …"
        }
    }
}

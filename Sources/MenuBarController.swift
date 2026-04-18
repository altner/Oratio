import SwiftUI
import AppKit
import ApplicationServices

/// Icon shown in the macOS menu bar. Uses the custom "O" template asset when
/// ready / recording / transcribing (auto-tinted), falls back to SF Symbols for
/// download / compile / failure states that need distinct shapes.
struct MenuBarLabelIcon: View {
    @Environment(AppState.self) private var state
    @Environment(LocalWhisperBackend.self) private var local

    var body: some View {
        switch state.recordingState {
        case .recording:
            Image("MenuBarIcon")
                .renderingMode(.template)
                .foregroundStyle(.red)
        case .transcribing:
            Image("MenuBarIcon")
                .renderingMode(.template)
                .foregroundStyle(.blue)
        case .idle:
            switch local.status {
            case .downloading:
                Image(systemName: "arrow.down.circle")
            case .compiling:
                Image(systemName: "gearshape.2")
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            case .notLoaded, .ready:
                Image("MenuBarIcon")
                    .renderingMode(.template)
            }
        }
    }
}

struct MenuBarContent: View {
    @Environment(AppState.self) private var state
    @Environment(LocalWhisperBackend.self) private var local

    @AppStorage("selectedBackend") private var backendRaw: String = BackendChoice.local.rawValue
    @AppStorage("correctionMode") private var correctionRaw: String = CorrectionMode.off.rawValue

    private var activeBackend: BackendChoice {
        BackendChoice(rawValue: backendRaw) ?? .local
    }
    private var activeCorrection: CorrectionMode {
        CorrectionMode(rawValue: correctionRaw) ?? .off
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()
            statusSection
            activeIndicator
            if !state.accessibilityGranted {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Label("Bedienungshilfen-Zugriff fehlt", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text("Ohne diesen Zugriff kann Oratio Text nicht automatisch einfügen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Systemeinstellungen öffnen") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if let err = state.lastError {
                Divider()
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(4)
            }
            if let last = state.lastTranscript, !last.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Zuletzt transkribiert")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(last)
                        .font(.callout)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
            }
            Divider()
            SettingsLink {
                Label("Einstellungen…", systemImage: "gear")
            }
            .buttonStyle(.plain)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Oratio beenden", systemImage: "power")
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 300)
        .onAppear {
            state.accessibilityGranted = AXIsProcessTrusted()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: state.menuBarSymbolName)
                .symbolRenderingMode(.hierarchical)
                .font(.title3)
                .foregroundStyle(headerTint)
            Text("Oratio")
                .font(.headline)
            Spacer()
        }
    }

    private var headerTint: Color {
        switch state.recordingState {
        case .recording:    return .red
        case .transcribing: return .blue
        case .idle:
            switch local.status {
            case .ready:       return .primary
            case .downloading: return .yellow
            case .compiling:   return .blue
            case .failed:      return .red
            case .notLoaded:   return .secondary
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(statusLine).font(.callout)
            if case .downloading(let p) = local.status {
                ProgressView(value: p).controlSize(.small)
            } else if case .compiling = local.status {
                ProgressView().controlSize(.small)
            }
        }
    }

    private var statusLine: String {
        if state.recordingState != .idle { return state.statusText }
        switch local.status {
        case .notLoaded:          return "Modell nicht geladen"
        case .downloading(let p): return "Lädt herunter … \(Int(p * 100)) %"
        case .compiling:          return "Kompiliert Modell …"
        case .ready:              return "Bereit"
        case .failed(let msg):    return "Fehler: \(msg)"
        }
    }

    private var activeIndicator: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: activeBackend == .local ? "laptopcomputer" : "cloud")
                    .foregroundStyle(.secondary)
                Text("Backend:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(activeBackend.label)
                    .font(.caption.weight(.medium))
            }
            HStack(spacing: 6) {
                Image(systemName: activeCorrection == .off ? "text.badge.xmark" : "text.badge.checkmark")
                    .foregroundStyle(activeCorrection == .off ? Color.secondary : Color.blue)
                Text("Korrektur:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(activeCorrection.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(activeCorrection == .off ? Color.secondary : Color.primary)
            }
        }
    }
}

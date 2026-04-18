import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let pushToTalk = Self(
        "oratio.pushToTalk",
        default: .init(.space, modifiers: [.option])
    )
}

enum ActivationMode: String, CaseIterable, Identifiable {
    case pushToTalk, toggle
    var id: String { rawValue }
    var label: String {
        switch self {
        case .pushToTalk: return "Halten (Push-to-Talk)"
        case .toggle: return "Umschalten"
        }
    }
}

@MainActor
final class HotkeyManager {
    var mode: ActivationMode
    private let onStart: () -> Void
    private let onStop: () -> Void
    private var isRecording = false

    init(
        mode: ActivationMode,
        onStart: @escaping () -> Void,
        onStop: @escaping () -> Void
    ) {
        self.mode = mode
        self.onStart = onStart
        self.onStop = onStop

        KeyboardShortcuts.onKeyDown(for: .pushToTalk) { [weak self] in
            guard let self else { return }
            switch self.mode {
            case .pushToTalk:
                if !self.isRecording {
                    self.isRecording = true
                    self.onStart()
                }
            case .toggle:
                if self.isRecording {
                    self.isRecording = false
                    self.onStop()
                } else {
                    self.isRecording = true
                    self.onStart()
                }
            }
        }
        KeyboardShortcuts.onKeyUp(for: .pushToTalk) { [weak self] in
            guard let self, self.mode == .pushToTalk, self.isRecording else { return }
            self.isRecording = false
            self.onStop()
        }
    }
}

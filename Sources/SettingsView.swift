import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @Environment(LocalWhisperBackend.self) private var local
    let openAI: OpenAIBackend
    let correction: CorrectionService
    let onActivationModeChange: (ActivationMode) -> Void

    @AppStorage("activationMode") private var activationModeRaw: String = ActivationMode.pushToTalk.rawValue
    @AppStorage("selectedBackend") private var backendRaw: String = BackendChoice.local.rawValue
    @AppStorage("openAIBaseURL") private var openAIBaseURL: String = "https://api.openai.com/v1"
    @AppStorage("openAIModel") private var openAIModel: String = "whisper-1"
    @AppStorage("correctionMode") private var correctionModeRaw: String = CorrectionMode.off.rawValue
    @AppStorage("correctionModel") private var correctionModel: String = "gpt-4o-mini"
    @AppStorage("apiPreset") private var apiPresetRaw: String = APIPreset.openAI.rawValue
    @AppStorage("correctionUseOwnAPI") private var correctionUseOwnAPI: Bool = false
    @AppStorage("correctionAPIPreset") private var correctionAPIPresetRaw: String = APIPreset.openAI.rawValue
    @AppStorage("correctionBaseURL") private var correctionBaseURL: String = "https://api.openai.com/v1"
    @AppStorage("removeFillerWords") private var removeFillerWords: Bool = false

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("Allgemein", systemImage: "keyboard") }
            transcriptionTab
                .tabItem { Label("Transkription", systemImage: "waveform") }
            correctionTab
                .tabItem { Label("Nachbearbeitung", systemImage: "text.magnifyingglass") }
        }
        .frame(width: 560, height: 520)
    }

    // MARK: - Allgemein

    private var generalTab: some View {
        Form {
            Section("Tastenkürzel") {
                KeyboardShortcuts.Recorder(for: .pushToTalk) {
                    Text("Diktieren starten")
                }
                Text("Standard: ⌥Leertaste")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Aktivierung") {
                Picker("Modus", selection: Binding(
                    get: { ActivationMode(rawValue: activationModeRaw) ?? .pushToTalk },
                    set: { newValue in
                        activationModeRaw = newValue.rawValue
                        onActivationModeChange(newValue)
                    }
                )) {
                    ForEach(ActivationMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(modeHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var modeHint: String {
        (ActivationMode(rawValue: activationModeRaw) ?? .pushToTalk) == .pushToTalk
            ? "Taste halten während du sprichst. Loslassen beendet die Aufnahme und fügt den Text ein."
            : "Einmal drücken startet die Aufnahme. Nochmal drücken beendet sie und fügt den Text ein."
    }

    // MARK: - Transkription

    private var transcriptionTab: some View {
        Form {
            Section("Backend") {
                Picker("", selection: $backendRaw) {
                    ForEach(BackendChoice.allCases) { c in
                        Text(c.label).tag(c.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text("Lokal: Audio verlässt Ihren Mac nie. Cloud-API: Audio wird an den unten konfigurierten Host übertragen (Standard: api.openai.com, alternativ Groq, OpenRouter, Azure, self-hosted u. a.).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if currentBackend == .local {
                Section("Lokales Modell (WhisperKit)") {
                    HStack {
                        Circle()
                            .fill(localStatusColor)
                            .frame(width: 8, height: 8)
                        Text(localStatusText)
                        Spacer()
                        if case .notLoaded = local.status {
                            Button("Laden") { local.prepare() }
                        } else if case .failed = local.status {
                            Button("Erneut versuchen") {
                                local.reset()
                                local.prepare()
                            }
                        }
                    }
                    Text("Modell: \(local.modelName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Cloud-API") {
                    LabeledContent("Dienst") {
                        Picker("", selection: Binding(
                            get: { currentAPIPreset },
                            set: { applyPreset($0) }
                        )) {
                            ForEach(APIPreset.allCases) { p in
                                Text(p.label).tag(p)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }

                    Text(currentAPIPreset.tagline)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let signup = currentAPIPreset.signupURL {
                        Link(destination: signup) {
                            Label("API-Key bei \(currentAPIPreset.label) erstellen", systemImage: "arrow.up.right.square")
                                .font(.caption)
                        }
                    }

                    OpenAIKeyField()

                    LabeledContent("Base URL") {
                        TextField("", text: $openAIBaseURL,
                                  prompt: Text("https://api.openai.com/v1"))
                            .textFieldStyle(.roundedBorder)
                    }
                    LabeledContent("Modell") {
                        TextField("", text: $openAIModel,
                                  prompt: Text("whisper-1"))
                            .textFieldStyle(.roundedBorder)
                    }

                    if !currentAPIPreset.supportsWhisper && currentAPIPreset != .custom {
                        Label("\(currentAPIPreset.label) bietet aktuell keinen Whisper-Endpunkt – für Transkription Backend auf 'Lokal' umschalten oder einen Custom-Host nutzen.", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    OpenAITestButton(openAI: openAI)

                    Text("Funktioniert mit jeder OpenAI-kompatiblen API. Kosten hängen vom Anbieter ab. Der API-Schlüssel wird im macOS-Schlüsselbund gespeichert.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var currentBackend: BackendChoice {
        BackendChoice(rawValue: backendRaw) ?? .local
    }

    private var currentAPIPreset: APIPreset {
        APIPreset(rawValue: apiPresetRaw) ?? .custom
    }

    private var currentCorrectionAPIPreset: APIPreset {
        APIPreset(rawValue: correctionAPIPresetRaw) ?? .custom
    }

    /// Transcription preset: overwrites Base URL, Whisper-Modell und (sofern
    /// Korrektur den gleichen Dienst nutzt) auch das LLM-Modell.
    private func applyPreset(_ preset: APIPreset) {
        apiPresetRaw = preset.rawValue
        if let url = preset.baseURL { openAIBaseURL = url }
        if let wm  = preset.whisperModel { openAIModel = wm }
        if !correctionUseOwnAPI, let lm = preset.llmModel {
            correctionModel = lm
        }
    }

    /// Korrektur-Preset: setzt Base URL und LLM-Modell unabhängig.
    private func applyCorrectionPreset(_ preset: APIPreset) {
        correctionAPIPresetRaw = preset.rawValue
        if let url = preset.baseURL { correctionBaseURL = url }
        if let lm  = preset.llmModel { correctionModel = lm }
    }

    // MARK: - Nachbearbeitung

    private var correctionTab: some View {
        Form {
            Section("Füllwörter") {
                Toggle("Füllwörter entfernen", isOn: $removeFillerWords)
                Text("Entfernt ähm, äh, öh, hmm, mhm und Varianten aus dem Diktat. Wird vor der optionalen LLM-Korrektur angewendet. 'Um' und 'er' bleiben unangetastet (echte Wörter).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Modus") {
                Picker("Nachbearbeitung", selection: $correctionModeRaw) {
                    ForEach(CorrectionMode.allCases) { m in
                        Text(m.label).tag(m.rawValue)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()

                Text(correctionModeHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if currentCorrectionMode != .off {
                Section("Prompt") {
                    PromptEditorView(mode: currentCorrectionMode)
                        .id(currentCorrectionMode.rawValue)
                }

                Section("API-Dienst für Nachbearbeitung") {
                    // Picker is always visible so the user can pick model defaults
                    // even without a separate key. Toggle below determines whether
                    // URL + key are independent or shared with Transcription.
                    LabeledContent("Dienst") {
                        Picker("", selection: Binding(
                            get: { currentCorrectionAPIPreset },
                            set: { applyCorrectionPreset($0) }
                        )) {
                            ForEach(APIPreset.allCases) { p in
                                Text(p.label).tag(p)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }

                    Text(currentCorrectionAPIPreset.tagline)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle("Eigener API-Dienst (unabhängig von Transkription)",
                           isOn: $correctionUseOwnAPI)

                    if correctionUseOwnAPI {
                        Text("Eigener Key/URL nur für die Nachbearbeitung. Transkription bleibt unberührt.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Nutzt denselben Keychain-Eintrag wie Transkription. Änderungen am Feld unten wirken in beiden Tabs.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let signup = currentCorrectionAPIPreset.signupURL {
                        Link(destination: signup) {
                            Label("API-Key bei \(currentCorrectionAPIPreset.label) erstellen",
                                  systemImage: "arrow.up.right.square")
                                .font(.caption)
                        }
                    }

                    // Key field is always visible. The account switches with the toggle.
                    OpenAIKeyField(
                        account: correctionUseOwnAPI
                            ? KeychainStore.correctionAccount
                            : KeychainStore.transcriptionAccount,
                        placeholder: correctionUseOwnAPI
                            ? "Eigener API-Key für Nachbearbeitung"
                            : "API-Key (geteilt mit Transkription)"
                    )
                    .id(correctionUseOwnAPI)   // force refresh when toggle flips

                    if correctionUseOwnAPI {
                        LabeledContent("Base URL") {
                            TextField("", text: $correctionBaseURL,
                                      prompt: Text("https://api.openai.com/v1"))
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    LabeledContent("Modell") {
                        TextField("", text: $correctionModel,
                                  prompt: Text("gpt-4o-mini"))
                            .textFieldStyle(.roundedBorder)
                    }

                    CorrectionTestButton(correction: correction)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var currentCorrectionMode: CorrectionMode {
        CorrectionMode(rawValue: correctionModeRaw) ?? .off
    }

    private var correctionModeHint: String {
        switch currentCorrectionMode {
        case .off:
            return "Deaktiviert. Der transkribierte Text wird unverändert eingefügt."
        case .grammar:
            return "Minimaleingriff: Rechtschreibung, Grammatik und Satzzeichen werden korrigiert, Bedeutung und Wortwahl bleiben erhalten."
        case .professional:
            return "Umformulierung für E-Mails/Notizen: formeller, freundlicher Ton. Fakten bleiben erhalten."
        case .polite:
            return "Entschärft aggressive oder beleidigende Sprache. Kritik bleibt erhalten, aber sachlich und respektvoll formuliert."
        case .custom:
            return "Eigener Prompt: du definierst das Verhalten selbst."
        }
    }

    private var localStatusColor: Color {
        switch local.status {
        case .notLoaded:  return .gray
        case .downloading: return .yellow
        case .compiling:  return .blue
        case .ready:      return .green
        case .failed:     return .red
        }
    }

    private var localStatusText: String {
        switch local.status {
        case .notLoaded:             return "Noch nicht geladen"
        case .downloading(let p):    return "Lädt herunter … \(Int(p * 100)) %"
        case .compiling:             return "Kompiliert Modell für Neural Engine …"
        case .ready:                 return "Bereit"
        case .failed(let msg):       return "Fehler: \(msg)"
        }
    }
}

// MARK: - Prompt-Editor

private struct PromptEditorView: View {
    let mode: CorrectionMode

    @State private var text: String = ""
    @State private var savedText: String = ""

    private var defaultText: String { mode.defaultPrompt ?? "" }

    private var usesCustomOverride: Bool {
        !savedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && savedText != defaultText
    }
    private var isDirty: Bool { text != savedText }
    private var canResetToDefault: Bool {
        mode.defaultPrompt != nil && text != defaultText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $text)
                .font(.system(.callout, design: .monospaced))
                .frame(minHeight: 160)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.secondary.opacity(0.3), lineWidth: 1)
                )

            HStack(spacing: 8) {
                Button("Speichern") { save() }
                    .disabled(!isDirty)

                if mode.defaultPrompt != nil {
                    Button("Auf Standard zurücksetzen") {
                        text = defaultText
                        save()
                    }
                    .disabled(!canResetToDefault)
                } else {
                    Button("Leeren") {
                        text = ""
                        save()
                    }
                    .disabled(text.isEmpty)
                }

                Spacer()

                statusBadge
            }

            if mode == .custom && savedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Noch kein Prompt hinterlegt — Korrektur bleibt solange deaktiviert.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text("Wird als system-Nachricht an das LLM übergeben. Das Diktat folgt als user-Nachricht.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { load() }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if usesCustomOverride {
            Label("Eigener Prompt aktiv", systemImage: "pencil")
                .font(.caption)
                .foregroundStyle(.blue)
                .labelStyle(.titleAndIcon)
        } else if mode.defaultPrompt != nil {
            Label("Standard aktiv", systemImage: "checkmark.seal")
                .font(.caption)
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
        }
    }

    private func load() {
        savedText = UserDefaults.standard.string(forKey: mode.promptStorageKey) ?? ""
        // Pre-fill editor: stored override if any, else default
        text = savedText.isEmpty ? defaultText : savedText
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // If identical to default (for preset modes): clear the override so future
        // default changes propagate automatically.
        if let def = mode.defaultPrompt,
           trimmed == def.trimmingCharacters(in: .whitespacesAndNewlines) {
            UserDefaults.standard.removeObject(forKey: mode.promptStorageKey)
            savedText = ""
        } else if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: mode.promptStorageKey)
            savedText = ""
        } else {
            UserDefaults.standard.set(text, forKey: mode.promptStorageKey)
            savedText = text
        }
    }
}

// MARK: - API-Key Feld

private struct OpenAIKeyField: View {
    var account: String = KeychainStore.transcriptionAccount
    var placeholder: String = "API-Key, z. B. sk-…"

    @State private var inputKey: String = ""
    @State private var saveMessage: String?
    @State private var isSaveOK = false

    private var hasStoredKey: Bool {
        KeychainStore.hasKey(account: account)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SecureField(
                hasStoredKey ? "•••••••• (neuer Schlüssel überschreibt)" : placeholder,
                text: $inputKey
            )
            .textFieldStyle(.roundedBorder)
            .onSubmit(saveKey)

            HStack {
                Button("Speichern") { saveKey() }
                    .disabled(inputKey.isEmpty)

                if hasStoredKey {
                    Button("Löschen", role: .destructive) {
                        KeychainStore.delete(account: account)
                        inputKey = ""
                        saveMessage = "Schlüssel gelöscht."
                        isSaveOK = true
                    }
                }

                if let msg = saveMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(isSaveOK ? .green : .red)
                }
            }
        }
    }

    private func saveKey() {
        do {
            try KeychainStore.save(inputKey, account: account)
            inputKey = ""
            saveMessage = "Gespeichert."
            isSaveOK = true
        } catch {
            saveMessage = "Fehler: \(error.localizedDescription)"
            isSaveOK = false
        }
    }
}

// MARK: - "Verbindung testen" (Nachbearbeitung)

private struct CorrectionTestButton: View {
    let correction: CorrectionService
    @State private var isTesting = false
    @State private var result: Result<Void, Error>?

    var body: some View {
        HStack(spacing: 8) {
            Button("Verbindung testen") {
                Task { await runTest() }
            }
            .disabled(isTesting)

            if isTesting {
                ProgressView().controlSize(.small)
            }

            switch result {
            case .success:
                Label("OK", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .labelStyle(.titleAndIcon)
            case .failure(let err):
                Label(err.localizedDescription, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .labelStyle(.titleAndIcon)
                    .help(err.localizedDescription)
                    .lineLimit(2)
            case .none:
                EmptyView()
            }
        }
    }

    @MainActor
    private func runTest() async {
        isTesting = true
        result = nil
        defer { isTesting = false }
        do {
            try await correction.testConnection()
            result = .success(())
        } catch {
            result = .failure(error)
        }
    }
}

// MARK: - "Verbindung testen" (Transkription)

private struct OpenAITestButton: View {
    let openAI: OpenAIBackend
    @State private var isTesting = false
    @State private var result: Result<Void, Error>?

    var body: some View {
        HStack(spacing: 8) {
            Button("Verbindung testen") {
                Task { await runTest() }
            }
            .disabled(isTesting)

            if isTesting {
                ProgressView().controlSize(.small)
            }

            switch result {
            case .success:
                Label("OK", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .labelStyle(.titleAndIcon)
            case .failure(let err):
                Label(err.localizedDescription, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .labelStyle(.titleAndIcon)
                    .help(err.localizedDescription)
                    .lineLimit(2)
            case .none:
                EmptyView()
            }
        }
    }

    @MainActor
    private func runTest() async {
        isTesting = true
        result = nil
        defer { isTesting = false }
        do {
            try await openAI.testConnection()
            result = .success(())
        } catch {
            result = .failure(error)
        }
    }
}

import Foundation

enum CorrectionMode: String, CaseIterable, Identifiable {
    case off, grammar, professional, polite, custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off:          return "Aus"
        case .grammar:      return "Rechtschreibung & Grammatik"
        case .professional: return "Professioneller Stil"
        case .polite:       return "Höflich umformulieren"
        case .custom:       return "Eigener Prompt"
        }
    }

    /// UserDefaults key that stores the user's (possibly edited) prompt for this mode.
    /// Empty / absent → fall back to `defaultPrompt`.
    var promptStorageKey: String {
        switch self {
        case .custom: return "correctionCustomPrompt"        // legacy key, kept
        default:      return "correctionPrompt_\(rawValue)"
        }
    }

    /// Hardcoded default prompt for preset modes. `nil` for `.off` and `.custom`
    /// (custom has no default — user must provide it).
    var defaultPrompt: String? {
        switch self {
        case .off, .custom:
            return nil
        case .grammar:
            return """
            Du bist ein stiller Korrektor für deutschsprachige Diktate.
            Korrigiere ausschließlich Rechtschreibung, Grammatik und Satzzeichen.
            Erhalte Bedeutung, Wortwahl und Tonfall exakt. Keine Umformulierungen, keine Zusammenfassung.
            Gib NUR den korrigierten Text zurück — ohne Anführungszeichen, ohne Vorwort, ohne Kommentare.
            """
        case .professional:
            return """
            Formuliere den folgenden deutschen Diktattext als professionell klingende Kurznotiz / E-Mail-Fragment.
            Erhalte alle Fakten und die Kernaussage. Korrigiere Grammatik, Rechtschreibung und Satzzeichen.
            Verwende einen formellen, freundlichen Ton. Keine Anrede oder Grußformel hinzufügen, außer sie war im Original.
            Gib NUR den überarbeiteten Text zurück — ohne Anführungszeichen, ohne Vorwort, ohne Kommentare.
            """
        case .polite:
            return """
            Formuliere den folgenden deutschen Diktattext in eine höfliche, respektvolle und sachliche Version um.
            Regeln:
            - Entferne Beleidigungen, Schimpfwörter, Aggression, Herabsetzungen und vulgäre Ausdrücke vollständig.
            - Erhalte das eigentliche Anliegen, den Inhalt und die Kernforderung klar und vollständig.
            - Mache Kritik konstruktiv, ohne sie zu verwässern oder zu relativieren.
            - Verwende eine sachliche, freundliche, erwachsene Sprache.
            - Korrigiere Grammatik, Rechtschreibung und Satzzeichen.
            - Füge keine Anrede oder Grußformel hinzu, außer sie war im Original.
            Gib NUR den umformulierten Text zurück — ohne Anführungszeichen, ohne Vorwort, ohne Kommentare.
            """
        }
    }

    /// The prompt actually sent to the LLM. Reads the user's override from
    /// UserDefaults; falls back to `defaultPrompt`. `nil` → skip correction.
    var effectivePrompt: String? {
        if self == .off { return nil }
        let stored = (UserDefaults.standard.string(forKey: promptStorageKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !stored.isEmpty { return stored }
        return defaultPrompt
    }
}

@MainActor
final class CorrectionService {

    /// When `true`, correction uses its own preset/URL/key (see `correctionBaseURL`,
    /// `KeychainStore.correctionAccount`). When `false` (default), correction
    /// shares the transcription config.
    var useOwnAPI: Bool {
        UserDefaults.standard.bool(forKey: "correctionUseOwnAPI")
    }

    var baseURL: String {
        if useOwnAPI {
            return UserDefaults.standard.string(forKey: "correctionBaseURL")
                ?? "https://api.openai.com/v1"
        }
        return UserDefaults.standard.string(forKey: "openAIBaseURL")
            ?? "https://api.openai.com/v1"
    }

    var model: String {
        UserDefaults.standard.string(forKey: "correctionModel") ?? "gpt-4o-mini"
    }

    var mode: CorrectionMode {
        let raw = UserDefaults.standard.string(forKey: "correctionMode") ?? CorrectionMode.off.rawValue
        return CorrectionMode(rawValue: raw) ?? .off
    }

    private func apiKey() -> String? {
        if useOwnAPI {
            return KeychainStore.load(account: KeychainStore.correctionAccount)
        }
        return KeychainStore.load()
    }

    /// Ping the configured LLM endpoint with a trivial request to verify that
    /// key + URL + model work. Returns on 2xx, throws otherwise.
    func testConnection() async throws {
        guard let key = apiKey(), !key.isEmpty else {
            throw TranscriptionError.missingAPIKey
        }
        _ = try await callChatCompletions(
            systemPrompt: "Antworte mit exakt: OK",
            userText: "ping",
            apiKey: key
        )
    }

    /// Runs the configured correction mode on `text`. Returns the original text
    /// when correction is disabled or misconfigured (missing key / empty prompt).
    /// Throws on network / API errors so callers can decide whether to fall back.
    func correctIfEnabled(_ text: String) async throws -> String {
        guard let systemPrompt = mode.effectivePrompt else { return text }
        guard !text.isEmpty else { return text }
        guard let key = apiKey(), !key.isEmpty else {
            throw TranscriptionError.missingAPIKey
        }
        return try await callChatCompletions(
            systemPrompt: systemPrompt,
            userText: text,
            apiKey: key
        )
    }

    private func callChatCompletions(
        systemPrompt: String,
        userText: String,
        apiKey: String
    ) async throws -> String {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw TranscriptionError.server("Ungültige Base URL")
        }

        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user",   "content": userText]
            ],
            "temperature": 0
        ]
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw TranscriptionError.server("Keine HTTP-Antwort")
        }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw TranscriptionError.http(http.statusCode, text)
        }

        struct Choice: Decodable {
            struct Message: Decodable { let content: String }
            let message: Message
        }
        struct ChatResponse: Decodable { let choices: [Choice] }

        let parsed = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = parsed.choices.first?.message.content else {
            throw TranscriptionError.server("Leere Antwort vom LLM")
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

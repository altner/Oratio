import Foundation

enum BackendChoice: String, CaseIterable, Identifiable {
    // rawValue "openAI" is kept for backwards-compatible UserDefaults storage;
    // the label is generic because any OpenAI-compatible endpoint works
    // (Groq, OpenRouter, Azure, self-hosted whisper servers, …).
    case local, openAI
    var id: String { rawValue }
    var label: String {
        switch self {
        case .local:  return "Lokal (WhisperKit)"
        case .openAI: return "Cloud-API"
        }
    }
}

protocol TranscriptionBackend {
    func transcribe(samples: [Float], language: String) async throws -> String
}

enum TranscriptionError: LocalizedError {
    case backendNotReady
    case missingAPIKey
    case http(Int, String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .backendNotReady:       return "Backend nicht bereit (Modell noch nicht geladen)."
        case .missingAPIKey:         return "OpenAI API-Key fehlt. Bitte in Einstellungen hinterlegen."
        case .http(let code, let b): return "HTTP \(code): \(b.prefix(200))"
        case .server(let msg):       return msg
        }
    }
}

@MainActor
final class TranscriptionService {
    let local: LocalWhisperBackend
    let openAI: OpenAIBackend

    init(local: LocalWhisperBackend, openAI: OpenAIBackend) {
        self.local = local
        self.openAI = openAI
    }

    private var activeBackend: BackendChoice {
        let raw = UserDefaults.standard.string(forKey: "selectedBackend")
            ?? BackendChoice.local.rawValue
        return BackendChoice(rawValue: raw) ?? .local
    }

    func transcribe(samples: [Float], language: String = "de") async throws -> String {
        switch activeBackend {
        case .local:  return try await local.transcribe(samples: samples, language: language)
        case .openAI: return try await openAI.transcribe(samples: samples, language: language)
        }
    }
}

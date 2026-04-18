import Foundation

/// Convenience presets for popular OpenAI-compatible providers.
/// Picking a preset auto-fills the Base URL + default model names.
enum APIPreset: String, CaseIterable, Identifiable {
    case openAI, groq, openRouter, custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .openAI:     return "OpenAI"
        case .groq:       return "Groq"
        case .openRouter: return "OpenRouter"
        case .custom:     return "Eigener Dienst"
        }
    }

    var tagline: String {
        switch self {
        case .openAI:     return "Standard, breite Modellauswahl."
        case .groq:       return "Ultraschnell, Whisper & Llama, oft gratis."
        case .openRouter: return "Viele LLMs über eine API (kein Whisper)."
        case .custom:     return "Self-hosted oder andere OpenAI-kompatible API."
        }
    }

    var baseURL: String? {
        switch self {
        case .openAI:     return "https://api.openai.com/v1"
        case .groq:       return "https://api.groq.com/openai/v1"
        case .openRouter: return "https://openrouter.ai/api/v1"
        case .custom:     return nil
        }
    }

    /// Default model for speech-to-text on this provider (if supported).
    var whisperModel: String? {
        switch self {
        case .openAI:     return "whisper-1"
        case .groq:       return "whisper-large-v3-turbo"
        case .openRouter: return nil   // OpenRouter currently has no Whisper endpoint
        case .custom:     return nil
        }
    }

    /// Default model for the LLM correction pass on this provider.
    var llmModel: String? {
        switch self {
        case .openAI:     return "gpt-4o-mini"
        case .groq:       return "llama-3.3-70b-versatile"
        case .openRouter: return "anthropic/claude-3.5-haiku"
        case .custom:     return nil
        }
    }

    var signupURL: URL? {
        switch self {
        case .openAI:     return URL(string: "https://platform.openai.com/api-keys")
        case .groq:       return URL(string: "https://console.groq.com/keys")
        case .openRouter: return URL(string: "https://openrouter.ai/keys")
        case .custom:     return nil
        }
    }

    var supportsWhisper: Bool { whisperModel != nil }
}

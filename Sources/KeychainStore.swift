import Foundation
import Security

enum KeychainError: Error {
    case unhandled(OSStatus)
    case encoding
}

enum KeychainStore {
    static let service = "org.altner.Oratio.openai"

    /// Account identifiers. Transcription and correction can store independent
    /// keys so the user can mix providers (e.g. Groq for Whisper, OpenAI for
    /// the LLM correction pass).
    static let transcriptionAccount = "api-key"
    static let correctionAccount    = "correction-api-key"

    // MARK: - Low-level

    static func save(_ key: String, account: String = transcriptionAccount) throws {
        guard let data = key.data(using: .utf8) else { throw KeychainError.encoding }

        let baseQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        if updateStatus != errSecItemNotFound {
            throw KeychainError.unhandled(updateStatus)
        }

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.unhandled(addStatus)
        }
    }

    static func load(account: String = transcriptionAccount) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let str = String(data: data, encoding: .utf8)
        else { return nil }
        return str
    }

    @discardableResult
    static func delete(account: String = transcriptionAccount) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }

    static func hasKey(account: String = transcriptionAccount) -> Bool {
        load(account: account) != nil
    }
}

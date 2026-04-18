import Foundation

@MainActor
final class OpenAIBackend: TranscriptionBackend {
    var baseURL: String {
        UserDefaults.standard.string(forKey: "openAIBaseURL")
            ?? "https://api.openai.com/v1"
    }
    var model: String {
        UserDefaults.standard.string(forKey: "openAIModel") ?? "whisper-1"
    }

    /// Transcribe; uses the API key from Keychain.
    func transcribe(samples: [Float], language: String) async throws -> String {
        guard let apiKey = KeychainStore.load(), !apiKey.isEmpty else {
            throw TranscriptionError.missingAPIKey
        }
        let wav = encodeWAV(samples: samples, sampleRate: 16_000)
        return try await post(wav: wav, apiKey: apiKey, language: language)
    }

    /// Test the connection with a short silent clip.
    func testConnection() async throws {
        guard let apiKey = KeychainStore.load(), !apiKey.isEmpty else {
            throw TranscriptionError.missingAPIKey
        }
        let silence = [Float](repeating: 0, count: 16_000)  // 1 s of silence
        let wav = encodeWAV(samples: silence, sampleRate: 16_000)
        _ = try await post(wav: wav, apiKey: apiKey, language: "de")
    }

    // MARK: - HTTP

    private func post(wav: Data, apiKey: String, language: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/audio/transcriptions") else {
            throw TranscriptionError.server("Ungültige Base URL")
        }
        let boundary = "oratio-" + UUID().uuidString

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = multipartBody(
            boundary: boundary,
            wav: wav,
            fields: [
                "model": model,
                "language": language,
                "response_format": "text",
                "temperature": "0"
            ]
        )

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw TranscriptionError.server("Keine HTTP-Antwort")
        }
        let body = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(http.statusCode) else {
            throw TranscriptionError.http(http.statusCode, body)
        }
        return body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func multipartBody(
        boundary: String,
        wav: Data,
        fields: [String: String]
    ) -> Data {
        var body = Data()
        let crlf = "\r\n"

        for (k, v) in fields {
            body.append("--\(boundary)\(crlf)")
            body.append("Content-Disposition: form-data; name=\"\(k)\"\(crlf)\(crlf)")
            body.append("\(v)\(crlf)")
        }

        body.append("--\(boundary)\(crlf)")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.wav\"\(crlf)")
        body.append("Content-Type: audio/wav\(crlf)\(crlf)")
        body.append(wav)
        body.append("\(crlf)")

        body.append("--\(boundary)--\(crlf)")
        return body
    }

    // MARK: - WAV encoder (16-bit PCM mono)

    private func encodeWAV(samples: [Float], sampleRate: UInt32) -> Data {
        let bitsPerSample: UInt16 = 16
        let channels: UInt16 = 1
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample) / 8
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = UInt32(samples.count) * UInt32(bitsPerSample / 8)
        let chunkSize = 36 + dataSize

        var data = Data(capacity: Int(44 + dataSize))
        data.append(contentsOf: "RIFF".utf8)
        data.appendLE(chunkSize)
        data.append(contentsOf: "WAVE".utf8)

        data.append(contentsOf: "fmt ".utf8)
        data.appendLE(UInt32(16))           // fmt-chunk size
        data.appendLE(UInt16(1))            // PCM format
        data.appendLE(channels)
        data.appendLE(sampleRate)
        data.appendLE(byteRate)
        data.appendLE(blockAlign)
        data.appendLE(bitsPerSample)

        data.append(contentsOf: "data".utf8)
        data.appendLE(dataSize)
        for s in samples {
            let clamped = max(-1, min(1, s))
            let scaled = Int16(clamped * Float(Int16.max))
            data.appendLE(UInt16(bitPattern: scaled))
        }
        return data
    }
}

private extension Data {
    mutating func append(_ s: String) {
        if let d = s.data(using: .utf8) { append(d) }
    }
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { buffer in
            self.append(contentsOf: buffer)
        }
    }
}

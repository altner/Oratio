import Foundation
import WhisperKit

@MainActor
@Observable
final class LocalWhisperBackend: TranscriptionBackend {
    enum Status: Equatable {
        case notLoaded
        case downloading(Double)    // 0...1, actual download fraction
        case compiling              // download done, loading into Neural Engine
        case ready
        case failed(String)
    }

    let modelName: String
    private(set) var status: Status = .notLoaded
    private var whisperKit: WhisperKit?
    private var loadTask: Task<Void, Never>?

    init(modelName: String = "openai_whisper-large-v3-v20240930_turbo") {
        self.modelName = modelName
    }

    func prepare() {
        guard loadTask == nil else { return }
        if case .ready = status { return }

        status = .downloading(0)

        loadTask = Task { [weak self, modelName] in
            guard let self else { return }
            do {
                // Step 1: Download (with progress) → returns modelFolder URL.
                // Skipped if cache is already complete.
                let folder = try await WhisperKit.download(
                    variant: modelName,
                    progressCallback: { progress in
                        Task { @MainActor [weak self] in
                            self?.status = .downloading(progress.fractionCompleted)
                        }
                    }
                )

                await MainActor.run {
                    self.status = .compiling
                }

                // Step 2: Init with local folder; no further download.
                let config = WhisperKitConfig(
                    modelFolder: folder.path,
                    verbose: false,
                    logLevel: .error,
                    prewarm: true,
                    load: true,
                    download: false
                )
                let wk = try await WhisperKit(config)

                await MainActor.run {
                    self.whisperKit = wk
                    self.status = .ready
                }
            } catch {
                await MainActor.run {
                    self.status = .failed(error.localizedDescription)
                    self.loadTask = nil
                }
            }
        }
    }

    func reset() {
        loadTask?.cancel()
        loadTask = nil
        whisperKit = nil
        status = .notLoaded
    }

    func transcribe(samples: [Float], language: String) async throws -> String {
        guard let whisperKit else { throw TranscriptionError.backendNotReady }
        let options = DecodingOptions(
            verbose: false,
            task: .transcribe,
            language: language,
            temperature: 0,
            skipSpecialTokens: true,
            withoutTimestamps: true
        )
        let results = try await whisperKit.transcribe(
            audioArray: samples,
            decodeOptions: options
        )
        return results
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

import AVFoundation
import Foundation

/// Pre-warms `AVAudioEngine`, maintains a 300 ms pre-roll ring buffer,
/// applies a 1-pole high-pass @ ~60 Hz (DC-offset removal), and fades in
/// the first ~10 ms of each captured chunk (click suppression).
final class AudioRecorder {
    enum RecorderError: Error {
        case engineUnavailable
    }

    private let engine = AVAudioEngine()
    private let targetFormat: AVAudioFormat
    private var converter: AVAudioConverter?

    private let lock = NSLock()
    private var isCapturing = false
    private var ringBuffer: [Float] = []
    private var captureBuffer: [Float] = []
    private let ringSize = 4_800           // 300 ms @ 16 kHz
    private let fadeInSamples = 160         // ~10 ms @ 16 kHz
    private let maxCaptureSamples = 16_000 * 120  // 120 s cap

    // 1-pole high-pass filter state (~60 Hz @ 16 kHz → alpha ≈ 0.977)
    private var hpPrevIn: Float = 0
    private var hpPrevOut: Float = 0
    private let hpAlpha: Float = 0.977

    private var isPrepared = false

    /// Tear the engine down after this many seconds of no recording activity
    /// so the system microphone indicator ("orange dot") doesn't linger.
    /// Back-to-back recordings within this window stay warm.
    var sleepDelay: TimeInterval = 30
    private var sleepTask: DispatchWorkItem?

    init() {
        targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        )!
        ringBuffer.reserveCapacity(ringSize)
        captureBuffer.reserveCapacity(maxCaptureSamples)
    }

    /// Installs the tap and starts the engine. Triggers the microphone TCC prompt
    /// on first call. Idempotent.
    func prepare() throws {
        guard !isPrepared else { return }
        let input = engine.inputNode
        let hwFormat = input.outputFormat(forBus: 0)
        guard hwFormat.sampleRate > 0 else { throw RecorderError.engineUnavailable }

        converter = AVAudioConverter(from: hwFormat, to: targetFormat)
        input.installTap(onBus: 0, bufferSize: 4_096, format: hwFormat) { [weak self] buf, _ in
            self?.handleBuffer(buf)
        }

        engine.prepare()
        try engine.start()
        isPrepared = true
    }

    /// Begin capturing. Seeds captureBuffer with the current ring-buffer contents
    /// (pre-roll) so the first word is never cut off.
    func startCapture() {
        cancelSleep()
        lock.lock()
        captureBuffer.removeAll(keepingCapacity: true)
        captureBuffer.append(contentsOf: ringBuffer)
        let fadeLen = min(fadeInSamples, captureBuffer.count)
        for i in 0..<fadeLen {
            captureBuffer[i] *= Float(i) / Float(fadeLen)
        }
        isCapturing = true
        lock.unlock()
    }

    /// Stop capturing and return the accumulated samples at 16 kHz / mono / Float32.
    func stopCapture() -> [Float] {
        lock.lock()
        isCapturing = false
        let out = captureBuffer
        captureBuffer.removeAll(keepingCapacity: true)
        lock.unlock()
        scheduleSleep()
        return out
    }

    func teardown() {
        cancelSleep()
        if isPrepared {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            isPrepared = false
        }
        // Clear the ring buffer too so stale samples don't sneak into the next
        // session's pre-roll after a cold start.
        lock.lock()
        ringBuffer.removeAll(keepingCapacity: true)
        hpPrevIn = 0
        hpPrevOut = 0
        lock.unlock()
    }

    // MARK: - Auto-sleep

    private func scheduleSleep() {
        cancelSleep()
        let task = DispatchWorkItem { [weak self] in
            self?.teardown()
        }
        sleepTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + sleepDelay, execute: task)
    }

    private func cancelSleep() {
        sleepTask?.cancel()
        sleepTask = nil
    }

    // MARK: - Tap callback (runs on audio thread)
    private func handleBuffer(_ inBuf: AVAudioPCMBuffer) {
        guard let converter else { return }

        let ratio = targetFormat.sampleRate / inBuf.format.sampleRate
        let capacity = AVAudioFrameCount(Double(inBuf.frameLength) * ratio) + 1_024
        guard let outBuf = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var error: NSError?
        var consumed = false
        converter.convert(to: outBuf, error: &error) { _, status in
            if consumed { status.pointee = .noDataNow; return nil }
            consumed = true
            status.pointee = .haveData
            return inBuf
        }
        if error != nil { return }

        guard let ch = outBuf.floatChannelData?[0] else { return }
        let count = Int(outBuf.frameLength)
        guard count > 0 else { return }

        var samples = [Float](repeating: 0, count: count)
        var pIn = hpPrevIn
        var pOut = hpPrevOut
        for i in 0..<count {
            let x = ch[i]
            let y = hpAlpha * (pOut + x - pIn)
            pIn = x
            pOut = y
            samples[i] = y
        }
        hpPrevIn = pIn
        hpPrevOut = pOut

        lock.lock()
        ringBuffer.append(contentsOf: samples)
        if ringBuffer.count > ringSize {
            ringBuffer.removeFirst(ringBuffer.count - ringSize)
        }
        if isCapturing {
            if captureBuffer.count + count <= maxCaptureSamples {
                captureBuffer.append(contentsOf: samples)
            } else {
                isCapturing = false
            }
        }
        lock.unlock()
    }
}

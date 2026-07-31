import AVFoundation
import Foundation

final class AudioRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var waveformLevels = [Double](repeating: 0.04, count: 48)

    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var converter: AVAudioConverter?
    private var samples = [Float]()

    func start() async throws {
        guard await requestMicrophoneAccess() else {
            throw AppError.recordingFailed("没有获得麦克风权限，请在系统设置中允许本地 ASR 使用麦克风。")
        }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw AppError.recordingFailed("没有可用的麦克风输入设备。")
        }

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ), let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AppError.recordingFailed("无法初始化音频格式转换器。")
        }

        resetSamples()
        resetWaveform()
        self.converter = converter

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self, let converter = self.converter,
                  let targetFormat = converter.outputFormat as AVAudioFormat? else { return }

            let ratio = targetFormat.sampleRate / buffer.format.sampleRate
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

            var conversionError: NSError?
            let status = converter.convert(to: outputBuffer, error: &conversionError) { _, inputStatus in
                inputStatus.pointee = .haveData
                return buffer
            }

            guard status == .haveData || status == .inputRanDry,
                  let channel = outputBuffer.floatChannelData?.pointee,
                  outputBuffer.frameLength > 0 else { return }

            let frameCount = Int(outputBuffer.frameLength)
            let level = self.level(for: channel, count: frameCount)
            self.lock.lock()
            self.samples.append(contentsOf: UnsafeBufferPointer(start: channel, count: frameCount))
            self.lock.unlock()
            self.publishWaveformLevel(level)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw AppError.recordingFailed(error.localizedDescription)
        }

        await MainActor.run {
            self.isRecording = true
            self.waveformLevels = Self.idleWaveform
        }
    }

    func stop() -> Data? {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil

        lock.lock()
        let capturedSamples = samples
        samples.removeAll(keepingCapacity: false)
        lock.unlock()

        DispatchQueue.main.async {
            self.isRecording = false
            self.waveformLevels = Self.idleWaveform
        }

        guard let speechSamples = AudioPreprocessor.trimSilence(capturedSamples) else {
            return nil
        }
        return WAVEncoder.pcm16(samples: speechSamples)
    }

    private func requestMicrophoneAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    private func resetSamples() {
        lock.lock()
        samples.removeAll(keepingCapacity: true)
        lock.unlock()
    }

    private func publishWaveformLevel(_ level: Double) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isRecording else { return }
            var levels = self.waveformLevels
            levels.removeFirst()
            levels.append(level)
            self.waveformLevels = levels
        }
    }

    private func level(for samples: UnsafePointer<Float>, count: Int) -> Double {
        guard count > 0 else { return 0.04 }

        var sumOfSquares = 0.0
        var peak = 0.0
        for index in 0..<count {
            let magnitude = abs(Double(samples[index]))
            sumOfSquares += magnitude * magnitude
            peak = max(peak, magnitude)
        }

        let rms = sqrt(sumOfSquares / Double(count))
        return min(1.0, max(0.04, max(rms * 8.0, peak * 3.0)))
    }

    private func resetWaveform() {
        DispatchQueue.main.async { [weak self] in
            self?.waveformLevels = Self.idleWaveform
        }
    }

    private static let idleWaveform = [Double](repeating: 0.04, count: 48)
}

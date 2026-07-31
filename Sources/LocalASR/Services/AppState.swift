import AppKit
import Foundation

@MainActor
final class AppState: ObservableObject {
    let modelStore = ModelStore()
    let recorder = AudioRecorder()
    let llmStore = LLMSettingsStore()

    @Published var transcript = ""
    @Published var polishedTranscript = ""
    @Published var statusMessage = "准备就绪"
    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var isPolishing = false
    @Published var errorMessage: String?
    @Published private(set) var segments = [TranscriptSegment]()

    private let whisperService = WhisperService()
    private let llmService = LLMService()

    var selectedModel: WhisperModel? {
        modelStore.selectedModel
    }

    var selectedModelIsDownloaded: Bool {
        guard let selectedModel else { return false }
        return modelStore.isDownloaded(selectedModel)
    }

    func toggleRecording() {
        if isRecording {
            let audio = recorder.stop()
            isRecording = false
            guard let audio else {
                statusMessage = "未检测到有效语音"
                return
            }
            Task { await transcribe(audio: audio) }
        } else {
            Task { await startRecording() }
        }
    }

    func startRecording() async {
        guard selectedModelIsDownloaded else {
            errorMessage = AppError.modelNotInstalled.localizedDescription
            statusMessage = "请先下载模型"
            return
        }

        errorMessage = nil
        do {
            try await recorder.start()
            isRecording = true
            statusMessage = "正在录音…"
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "录音未开始"
        }
    }

    func transcribe(audio: Data) async {
        guard let model = selectedModel else { return }
        guard modelStore.isDownloaded(model) else {
            errorMessage = AppError.modelNotInstalled.localizedDescription
            return
        }

        isTranscribing = true
        errorMessage = nil
        statusMessage = "正在加载模型并转写…"
        polishedTranscript = ""

        do {
            let modelURL = try await modelStore.validatedURL(for: model)
            let response = try await whisperService.transcribe(
                wavData: audio,
                model: model,
                modelURL: modelURL
            )
            let rawSegments = response.segments ?? []
            let cleanedSegments = TranscriptCleaner.removeConsecutiveDuplicates(from: rawSegments)
            if cleanedSegments.count < rawSegments.count {
                transcript = cleanedSegments
                    .compactMap { $0.text?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                transcript = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            segments = cleanedSegments.compactMap { segment in
                guard let start = segment.start, let end = segment.end, let text = segment.text else { return nil }
                return TranscriptSegment(start: start, end: end, text: text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            statusMessage = "转写完成 · \(model.displayName)"
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "转写失败"
        }

        isTranscribing = false
    }

    func copyTranscript() {
        copyText(transcript, status: "原文已复制到剪贴板")
    }

    func copyPolishedTranscript() {
        copyText(polishedTranscript, status: "润色结果已复制到剪贴板")
    }

    private func copyText(_ text: String, status: String) {
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        statusMessage = status
    }

    func polishTranscript() {
        guard !isRecording, !isTranscribing, !isPolishing else { return }
        let sourceText = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceText.isEmpty else { return }
        guard llmStore.save() else {
            errorMessage = llmStore.statusMessage
            return
        }

        let configuration = llmStore.configuration
        let apiKey = llmStore.apiKey
        isPolishing = true
        errorMessage = nil
        statusMessage = "正在使用 LLM 梳理文字…"

        Task { [weak self] in
            guard let self else { return }
            do {
                let polishedText = try await llmService.polish(
                    text: sourceText,
                    configuration: configuration,
                    apiKey: apiKey
                )
                polishedTranscript = polishedText
                statusMessage = "LLM 梳理完成 · \(llmStore.selectedProvider?.name ?? configuration.model)"
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = "LLM 梳理失败"
            }
            isPolishing = false
        }
    }

    func clearTranscript() {
        transcript = ""
        polishedTranscript = ""
        segments = []
        statusMessage = "已清空"
    }

    func saveTranscript() {
        guard !transcript.isEmpty else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "transcript.txt"
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try transcript.write(to: url, atomically: true, encoding: .utf8)
            statusMessage = "已保存"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopEngine() {
        whisperService.stop()
    }
}

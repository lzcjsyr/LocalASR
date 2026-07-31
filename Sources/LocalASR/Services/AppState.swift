import AppKit
import Foundation

@MainActor
final class AppState: ObservableObject {
    let modelStore = ModelStore()
    let recorder = AudioRecorder()

    @Published var transcript = ""
    @Published var statusMessage = "准备就绪"
    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var errorMessage: String?
    @Published private(set) var segments = [TranscriptSegment]()

    private let whisperService = WhisperService()

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

        do {
            let modelURL = try await modelStore.validatedURL(for: model)
            let response = try await whisperService.transcribe(
                wavData: audio,
                model: model,
                modelURL: modelURL
            )
            transcript = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
            segments = (response.segments ?? []).compactMap { segment in
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
        guard !transcript.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcript, forType: .string)
        statusMessage = "已复制到剪贴板"
    }

    func clearTranscript() {
        transcript = ""
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

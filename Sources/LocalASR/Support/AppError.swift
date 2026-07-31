import Foundation

enum AppError: LocalizedError {
    case modelNotInstalled
    case invalidServerResponse
    case engineNotFound
    case engineFailed(String)
    case downloadFailed(String)
    case checksumMismatch(expected: String, actual: String)
    case recordingFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotInstalled:
            return "请先在“模型”页面下载一个 Whisper 模型。"
        case .invalidServerResponse:
            return "本地转写服务返回了无法识别的结果。"
        case .engineNotFound:
            return "未找到本地 whisper.cpp 引擎，请重新构建应用。"
        case .engineFailed(let message):
            return "本地转写引擎启动失败：\(message)"
        case .downloadFailed(let message):
            return "模型下载失败：\(message)"
        case .checksumMismatch(let expected, let actual):
            return "模型校验失败。期望 \(expected)，实际 \(actual)。文件已删除。"
        case .recordingFailed(let message):
            return "录音失败：\(message)"
        }
    }
}

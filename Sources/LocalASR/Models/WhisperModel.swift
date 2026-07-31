import Foundation

struct WhisperModel: Identifiable, Hashable, Codable {
    let id: String
    let displayName: String
    let detail: String
    let fileName: String
    let downloadURL: URL
    let expectedSHA1: String
    let sizeInBytes: Int64
    let recommended: Bool

    static let catalog: [WhisperModel] = [
        WhisperModel(
            id: "large-v3-turbo-q5_0",
            displayName: "Large v3 Turbo Q5",
            detail: "推荐：中文质量与体积平衡",
            fileName: "ggml-large-v3-turbo-q5_0.bin",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin")!,
            expectedSHA1: "e050f7970618a659205450ad97eb95a18d69c9ee",
            sizeInBytes: 547_000_000,
            recommended: true
        ),
        WhisperModel(
            id: "small",
            displayName: "Small",
            detail: "更快：适合快速草稿",
            fileName: "ggml-small.bin",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin")!,
            expectedSHA1: "55356645c2b361a969dfd0ef2c5a50d530afd8d5",
            sizeInBytes: 466_000_000,
            recommended: false
        ),
        WhisperModel(
            id: "large-v3-turbo",
            displayName: "Large v3 Turbo",
            detail: "最高质量：占用更多空间",
            fileName: "ggml-large-v3-turbo.bin",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin")!,
            expectedSHA1: "4af2b29d7ec73d781377bfd1758ca957a807e941",
            sizeInBytes: 1_500_000_000,
            recommended: false
        )
    ]

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: sizeInBytes, countStyle: .file)
    }
}

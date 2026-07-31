import Foundation
import SwiftUI

@MainActor
final class ModelStore: ObservableObject {
    @Published private(set) var downloadedIDs = Set<String>()
    @Published var selectedModelID: String {
        didSet { UserDefaults.standard.set(selectedModelID, forKey: Self.selectedModelKey) }
    }
    @Published private(set) var downloadingID: String?
    @Published private(set) var statusMessage = ""

    static let selectedModelKey = "selectedModelID"

    let modelsDirectory: URL
    private let fileManager: FileManager
    private var validatedIDs = Set<String>()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.modelsDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LocalASR", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)

        let stored = UserDefaults.standard.string(forKey: Self.selectedModelKey)
        self.selectedModelID = stored ?? WhisperModel.catalog.first(where: { $0.recommended })!.id
        refresh()
    }

    var selectedModel: WhisperModel? {
        WhisperModel.catalog.first(where: { $0.id == selectedModelID })
    }

    func refresh() {
        try? fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        downloadedIDs = Set(WhisperModel.catalog.filter(isDownloaded).map(\.id))
    }

    func isDownloaded(_ model: WhisperModel) -> Bool {
        guard isSafeFileName(model.fileName) else { return false }
        let url = modelsDirectory.appendingPathComponent(model.fileName)
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else {
            return false
        }
        return size.int64Value > 0
    }

    func localURL(for model: WhisperModel) -> URL {
        modelsDirectory.appendingPathComponent(model.fileName)
    }

    func download(_ model: WhisperModel) async {
        guard downloadingID == nil else { return }
        guard model.downloadURL.scheme == "https", isSafeFileName(model.fileName) else {
            statusMessage = "已拒绝不安全的模型地址。"
            return
        }

        downloadingID = model.id
        statusMessage = "正在下载 \(model.displayName)…"

        do {
            try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
            var request = URLRequest(url: model.downloadURL)
            request.httpMethod = "GET"
            request.timeoutInterval = 3600
            let (temporaryURL, response) = try await URLSession.shared.download(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw AppError.downloadFailed("服务器返回了无效状态。")
            }

            let actualSHA1 = try FileHasher.sha1(of: temporaryURL)
            guard actualSHA1.caseInsensitiveCompare(model.expectedSHA1) == .orderedSame else {
                throw AppError.checksumMismatch(expected: model.expectedSHA1, actual: actualSHA1)
            }

            let destination = localURL(for: model)
            try? fileManager.removeItem(at: destination)
            try fileManager.moveItem(at: temporaryURL, to: destination)
            downloadedIDs.insert(model.id)
            validatedIDs.insert(model.id)
            statusMessage = "已下载：\(model.displayName)"
        } catch {
            statusMessage = error.localizedDescription
        }

        downloadingID = nil
        refresh()
    }

    func delete(_ model: WhisperModel) {
        guard isSafeFileName(model.fileName) else { return }
        do {
            try fileManager.removeItem(at: localURL(for: model))
        } catch {
            statusMessage = "删除失败：\(error.localizedDescription)"
            return
        }
        downloadedIDs.remove(model.id)
        validatedIDs.remove(model.id)
        if selectedModelID == model.id {
            selectedModelID = WhisperModel.catalog.first(where: { isDownloaded($0) })?.id ?? model.id
        }
        statusMessage = "已删除：\(model.displayName)"
    }

    func validatedURL(for model: WhisperModel) async throws -> URL {
        guard isDownloaded(model) else { throw AppError.modelNotInstalled }
        let url = localURL(for: model)
        if validatedIDs.contains(model.id) {
            return url
        }

        let expected = model.expectedSHA1
        let actual = try await Task.detached(priority: .userInitiated) {
            try FileHasher.sha1(of: url)
        }.value
        guard actual.caseInsensitiveCompare(expected) == .orderedSame else {
            try? fileManager.removeItem(at: url)
            refresh()
            throw AppError.checksumMismatch(expected: expected, actual: actual)
        }

        validatedIDs.insert(model.id)
        return url
    }

    private func isSafeFileName(_ fileName: String) -> Bool {
        fileName.hasSuffix(".bin") &&
        !fileName.contains("/") &&
        !fileName.contains("\\") &&
        fileName != "." &&
        fileName != ".."
    }
}

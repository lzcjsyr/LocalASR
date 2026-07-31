import AppKit
import Foundation

@MainActor
final class WhisperService {
    private var process: Process?
    private var runningModelID: String?
    private var port: UInt16?
    private var terminationObserver: NSObjectProtocol?

    init() {
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.stop()
            }
        }
    }

    deinit {
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
        }
        process?.terminate()
    }

    func transcribe(wavData: Data, model: WhisperModel, modelURL: URL) async throws -> TranscriptionResponse {
        try await ensureRunning(model: model, modelURL: modelURL)

        guard let port else { throw AppError.engineFailed("本地端口未准备好。") }
        let boundary = "Boundary-LocalASR-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/inference")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 3600
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = MultipartFormData(boundary: boundary)
            .file(fieldName: "file", fileName: "recording.wav", mimeType: "audio/wav", data: wavData)
            .field(name: "language", value: "zh")
            .field(name: "response_format", value: "verbose_json")
            .field(name: "temperature", value: "0.0")
            .field(name: "temperature_inc", value: "0.2")
            .field(name: "no_speech_thold", value: "0.6")
            .field(name: "suppress_nst", value: "true")
            .field(name: "no_context", value: "true")
            .build()

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP 请求失败"
            throw AppError.engineFailed(message)
        }

        do {
            return try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        } catch {
            throw AppError.invalidServerResponse
        }
    }

    func stop() {
        process?.terminate()
        process = nil
        runningModelID = nil
        port = nil
    }

    private func ensureRunning(model: WhisperModel, modelURL: URL) async throws {
        if let process, process.isRunning, runningModelID == model.id {
            return
        }

        stop()
        guard let executableURL = Bundle.main.url(forResource: "whisper-server", withExtension: nil, subdirectory: "bin") else {
            throw AppError.engineNotFound
        }

        let port = try LocalPortAllocator.allocateLoopbackPort()

        let server = Process()
        server.executableURL = executableURL
        server.arguments = [
            "--host", "127.0.0.1",
            "--port", String(port),
            "--model", modelURL.path,
            "--language", "zh",
            "--threads", "6"
        ]
        let nullDevice = FileHandle(forWritingAtPath: "/dev/null")
        server.standardOutput = nullDevice
        server.standardError = nullDevice

        do {
            try server.run()
        } catch {
            throw AppError.engineFailed(error.localizedDescription)
        }

        process = server
        runningModelID = model.id
        self.port = port
        try await waitUntilReady(port: port)
    }

    private func waitUntilReady(port: UInt16) async throws {
        let healthURL = URL(string: "http://127.0.0.1:\(port)/")!
        for _ in 0..<120 {
            if let process, !process.isRunning {
                throw AppError.engineFailed("服务进程已退出。")
            }

            do {
                var request = URLRequest(url: healthURL)
                request.timeoutInterval = 1
                _ = try await URLSession.shared.data(for: request)
                return
            } catch {
                try await Task.sleep(for: .milliseconds(250))
            }
        }
        throw AppError.engineFailed("等待本地服务启动超时。")
    }

}

private struct MultipartFormData {
    private let boundary: String
    private var parts = Data()

    init(boundary: String) {
        self.boundary = boundary
    }

    func field(name: String, value: String) -> MultipartFormData {
        var next = self
        next.parts.append(contentsOf: Array("--\(boundary)\r\n".utf8))
        next.parts.append(contentsOf: Array("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
        next.parts.append(contentsOf: Array("\(value)\r\n".utf8))
        return next
    }

    func file(fieldName: String, fileName: String, mimeType: String, data: Data) -> MultipartFormData {
        var next = self
        next.parts.append(contentsOf: Array("--\(boundary)\r\n".utf8))
        next.parts.append(contentsOf: Array("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".utf8))
        next.parts.append(contentsOf: Array("Content-Type: \(mimeType)\r\n\r\n".utf8))
        next.parts.append(data)
        next.parts.append(contentsOf: Array("\r\n".utf8))
        return next
    }

    func build() -> Data {
        var output = parts
        output.append(contentsOf: Array("--\(boundary)--\r\n".utf8))
        return output
    }
}

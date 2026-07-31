import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("当前模型") {
                Text(appState.selectedModel?.displayName ?? "未选择")
                Text(appState.modelStore.modelsDirectory.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Section("隐私与安全") {
                Text("录音只发送给本机 127.0.0.1 上的 whisper.cpp 进程，不连接远程 ASR 服务。模型通过 HTTPS 下载并进行完整性校验。")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .padding()
    }
}

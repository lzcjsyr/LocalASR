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

            Section("LLM 设置") {
                Text("LLM 供应商、模型、API Key 和系统提示词已放在主窗口左侧的“LLM 设置”Tab 中。日常使用“录音转写”时不需要打开这些参数。")
                    .foregroundStyle(.secondary)
            }

            Section("隐私与安全") {
                Text("录音只发送给本机 127.0.0.1 上的 whisper.cpp 进程，不连接远程 ASR 服务。LLM 是单独的可选功能，公网服务必须使用 HTTPS。")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 620)
        .padding()
    }
}

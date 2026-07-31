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

            Section("LLM 润色") {
                Text("请在主窗口左侧的“LLM 润色”页面中配置供应商、模型、API Key 和系统提示词。不同供应商可以分别保存并切换。")
                    .foregroundStyle(.secondary)
            }

            Section("隐私与安全") {
                Text("录音只发送给本机 127.0.0.1 上的 whisper.cpp 进程，不连接远程 ASR 服务。LLM 是单独的可选功能，只有点击“开始润色”时才会发送当前原文。")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 620)
        .padding()
    }
}

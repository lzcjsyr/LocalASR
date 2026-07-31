import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var llmStore: LLMSettingsStore

    init(llmStore: LLMSettingsStore) {
        _llmStore = ObservedObject(wrappedValue: llmStore)
    }

    var body: some View {
        Form {
            Section("当前模型") {
                Text(appState.selectedModel?.displayName ?? "未选择")
                Text(appState.modelStore.modelsDirectory.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Section("LLM 润色与梳理") {
                TextField("Base URL", text: $llmStore.baseURL)
                    .textFieldStyle(.roundedBorder)
                TextField("模型", text: $llmStore.model)
                    .textFieldStyle(.roundedBorder)
                SecureField("API Key", text: $llmStore.apiKey)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: 6) {
                    Text("润色提示词")
                        .font(.callout.weight(.medium))
                    TextEditor(text: $llmStore.prompt)
                        .font(.system(.body, design: .default))
                        .frame(minHeight: 150)
                        .padding(6)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.25))
                        }
                }

                HStack {
                    Button("保存配置") {
                        _ = llmStore.save()
                    }
                    Button("测试连接") {
                        Task { await llmStore.testConnection() }
                    }
                    .disabled(llmStore.isTesting)

                    if llmStore.isTesting {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Spacer()
                    Text(llmStore.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("API Key 只保存在本机 macOS 钥匙串。点击“LLM 梳理”时，当前转写文字会发送到你配置的服务。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("隐私与安全") {
                Text("录音只发送给本机 127.0.0.1 上的 whisper.cpp 进程，不连接远程 ASR 服务。LLM 是单独的可选功能，模型通过 HTTPS 下载并进行完整性校验。")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 620)
        .padding()
    }
}

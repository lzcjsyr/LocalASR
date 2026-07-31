import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var llmStore: LLMSettingsStore

    init(llmStore: LLMSettingsStore) {
        _llmStore = ObservedObject(wrappedValue: llmStore)
    }

    private var selectedProviderBinding: Binding<UUID> {
        Binding(
            get: { llmStore.selectedProviderID },
            set: { llmStore.selectProvider($0) }
        )
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

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Picker("供应商", selection: selectedProviderBinding) {
                            ForEach(llmStore.providers) { provider in
                                Text(provider.name).tag(provider.id)
                            }
                        }
                        .frame(width: 230)

                        Button {
                            llmStore.addProvider()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .help("新增供应商配置")

                        Button(role: .destructive) {
                            llmStore.deleteSelectedProvider()
                        } label: {
                            Image(systemName: "minus")
                        }
                        .disabled(llmStore.providers.count <= 1 || llmStore.isTesting)
                        .help("删除当前供应商配置")
                    }

                    TextField("供应商名称", text: llmStore.binding(for: \.name))
                    TextField("Base URL", text: llmStore.binding(for: \.baseURL))
                    TextField("模型", text: llmStore.binding(for: \.model))
                    SecureField("API Key", text: $llmStore.apiKey)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("系统提示词")
                            .font(.callout.weight(.medium))
                        TextEditor(text: llmStore.binding(for: \.prompt))
                            .font(.system(.body, design: .default))
                            .frame(minHeight: 150)
                            .padding(6)
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.25))
                            }
                    }

                    HStack(spacing: 10) {
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

                        Text(llmStore.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } header: {
                Text("LLM 服务配置")
            } footer: {
                Text("这里是后台设置，不会出现在主界面的左侧导航中。API Key 只保存在本机 macOS 钥匙串；点击主界面的“LLM 润色”时，当前 ASR 原文会发送到选中的服务。")
            }

            Section("隐私与安全") {
                Text("录音只发送给本机 127.0.0.1 上的 whisper.cpp 进程，不连接远程 ASR 服务。LLM 是单独的可选功能，公网服务必须使用 HTTPS。")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 680)
        .padding()
    }
}

import SwiftUI

struct LLMSettingsView: View {
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
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("LLM 设置")
                    .font(.title2.weight(.semibold))
                Text("这里用于调整服务参数。设置完成后，回到“录音转写”页面即可直接使用。")
                    .foregroundStyle(.secondary)
            }
            .padding(22)

            Divider()

            Form {
                Section("服务配置") {
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
                            .frame(minHeight: 180)
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
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Text("API Key 只保存在本机 macOS 钥匙串。点击“录音转写”页面的“LLM 润色”时，当前 ASR 原文会发送到选中的服务。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 22)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

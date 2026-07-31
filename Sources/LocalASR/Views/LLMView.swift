import SwiftUI

struct LLMView: View {
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
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("LLM 润色与梳理")
                        .font(.title2.weight(.semibold))
                    Text("左侧保留 ASR 原文，右侧生成可继续编辑的润色结果。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if appState.isPolishing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            providerConfiguration
                .padding(.horizontal, 18)
                .padding(.bottom, 16)

            Divider()

            HStack(spacing: 0) {
                editorPane(
                    title: "ASR 原文",
                    text: $appState.transcript,
                    placeholder: "录音转写结果会显示在这里，也可以手动粘贴或编辑。",
                    copyAction: appState.copyTranscript
                )

                Divider()

                editorPane(
                    title: "润色结果",
                    text: $appState.polishedTranscript,
                    placeholder: "点击“开始润色”后，LLM 结果会显示在这里。你可以继续编辑。",
                    copyAction: appState.copyPolishedTranscript
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack(spacing: 12) {
                Text(appState.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Button("清空两栏") {
                    appState.clearTranscript()
                }
                .disabled(
                    (appState.transcript.isEmpty && appState.polishedTranscript.isEmpty)
                    || appState.isPolishing
                )

                Button {
                    appState.polishTranscript()
                } label: {
                    Label("开始润色", systemImage: "wand.and.stars")
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    appState.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || appState.isRecording
                    || appState.isTranscribing
                    || appState.isPolishing
                    || llmStore.isTesting
                )
            }
            .padding(12)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("复制润色结果") {
                    appState.copyPolishedTranscript()
                }
                .disabled(appState.polishedTranscript.isEmpty)
            }
        }
    }

    private var providerConfiguration: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Picker("供应商", selection: selectedProviderBinding) {
                        ForEach(llmStore.providers) { provider in
                            Text(provider.name).tag(provider.id)
                        }
                    }
                    .frame(width: 220)

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

                    TextField("供应商名称", text: llmStore.binding(for: \.name))
                        .textFieldStyle(.roundedBorder)

                    Spacer()
                }

                HStack(spacing: 10) {
                    TextField("Base URL", text: llmStore.binding(for: \.baseURL))
                        .textFieldStyle(.roundedBorder)
                    TextField("模型", text: llmStore.binding(for: \.model))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 230)
                    SecureField("API Key", text: $llmStore.apiKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 250)
                }

                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("系统提示词")
                            .font(.caption.weight(.medium))
                        TextEditor(text: llmStore.binding(for: \.prompt))
                            .font(.system(.callout, design: .default))
                            .frame(height: 66)
                            .padding(5)
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.25))
                            }
                    }

                    VStack(alignment: .trailing, spacing: 8) {
                        Button("保存配置") {
                            _ = llmStore.save()
                        }
                        Button("测试连接") {
                            Task { await llmStore.testConnection() }
                        }
                        .disabled(llmStore.isTesting)
                    }
                    .frame(width: 92, alignment: .trailing)
                }

                HStack(spacing: 8) {
                    if llmStore.isTesting {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(llmStore.statusMessage.isEmpty ? "API Key 只保存在本机钥匙串。" : llmStore.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text("公网地址必须使用 HTTPS；本地服务可使用 localhost HTTP")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        } label: {
            Label("服务配置", systemImage: "slider.horizontal.3")
        }
    }

    private func editorPane(
        title: String,
        text: Binding<String>,
        placeholder: String,
        copyAction: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button("复制") {
                    copyAction()
                }
                .disabled(text.wrappedValue.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            ZStack(alignment: .topLeading) {
                TextEditor(text: text)
                    .font(.system(.body, design: .default))
                    .scrollContentBackground(.hidden)
                    .padding(12)

                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

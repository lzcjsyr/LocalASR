import SwiftUI

struct ModelsView: View {
    @ObservedObject var modelStore: ModelStore
    @State private var modelPendingDeletion: WhisperModel?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("模型管理")
                    .font(.title2.weight(.semibold))
                Text("模型只下载一次，之后可以完全离线使用。选择一个已下载模型作为当前转写模型。")
                    .foregroundStyle(.secondary)
            }
            .padding(22)

            Divider()

            List {
                ForEach(WhisperModel.catalog) { model in
                    ModelRow(
                        model: model,
                        modelStore: modelStore,
                        onDelete: { modelPendingDeletion = model }
                    )
                }
            }
            .listStyle(.inset)

            if !modelStore.statusMessage.isEmpty {
                Text(modelStore.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 14)
            }
        }
        .alert("删除模型？", isPresented: Binding(
            get: { modelPendingDeletion != nil },
            set: { if !$0 { modelPendingDeletion = nil } }
        )) {
            Button("删除", role: .destructive) {
                if let modelPendingDeletion {
                    modelStore.delete(modelPendingDeletion)
                }
                modelPendingDeletion = nil
            }
            Button("取消", role: .cancel) {
                modelPendingDeletion = nil
            }
        } message: {
            if let modelPendingDeletion {
                Text(
                    "将从本机删除 " + modelPendingDeletion.displayName +
                    "（" + modelPendingDeletion.sizeText + "），不会影响其他模型。"
                )
            }
        }
    }
}

private struct ModelRow: View {
    let model: WhisperModel
    @ObservedObject var modelStore: ModelStore
    let onDelete: () -> Void

    private var downloaded: Bool { modelStore.isDownloaded(model) }
    private var selected: Bool { modelStore.selectedModelID == model.id }
    private var downloading: Bool { modelStore.downloadingID == model.id }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(model.displayName)
                        .font(.headline)
                    if model.recommended {
                        Text("推荐")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.tint.opacity(0.15), in: Capsule())
                            .foregroundStyle(.tint)
                    }
                }
                Text(model.detail + " · " + model.sizeText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if downloaded {
                Button(selected ? "使用中" : "切换") {
                    modelStore.selectedModelID = model.id
                }
                .disabled(selected)

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .help("删除本地模型")
            } else {
                Button {
                    Task { await modelStore.download(model) }
                } label: {
                    if downloading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("下载")
                    }
                }
                .disabled(modelStore.downloadingID != nil)
            }
        }
        .padding(.vertical, 8)
    }
}

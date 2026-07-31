import SwiftUI

struct RecorderView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var recorder: AudioRecorder

    init(recorder: AudioRecorder) {
        _recorder = ObservedObject(wrappedValue: recorder)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    appState.toggleRecording()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: appState.isRecording ? "stop.fill" : "record.circle")
                        Text(appState.isRecording ? "停止并转写" : "开始录音")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(appState.isRecording ? .red : .accentColor)
                .accessibilityLabel(appState.isRecording ? "停止并转写" : "开始录音")
                .disabled(appState.isTranscribing)

                Picker("模型", selection: Binding(
                    get: { appState.modelStore.selectedModelID },
                    set: { appState.modelStore.selectedModelID = $0 }
                )) {
                    ForEach(WhisperModel.catalog) { model in
                        Text(model.displayName + (appState.modelStore.isDownloaded(model) ? " · 已下载" : " · 未下载"))
                            .tag(model.id)
                    }
                }
                .frame(width: 250)

                if !appState.selectedModelIsDownloaded {
                    Text("请先到“模型”下载")
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Text(appState.statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(16)

            if appState.isRecording {
                VStack(alignment: .leading, spacing: 8) {
                    RecordingWaveformView(
                        levels: recorder.waveformLevels,
                        isRecording: recorder.isRecording
                    )

                    Label("正在录音 · 麦克风输入会实时显示在波形中", systemImage: "waveform")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider()

            ZStack(alignment: .topLeading) {
                TextEditor(text: $appState.transcript)
                    .font(.system(.body, design: .default))
                    .scrollContentBackground(.hidden)
                    .padding(18)

                if appState.transcript.isEmpty {
                    Text("录音停止后，识别结果会显示在这里。你可以直接编辑、复制或保存。")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 26)
                        .allowsHitTesting(false)
                }
            }

            Divider()

            HStack {
                Text("音频和文字只在本机处理")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("LLM 梳理") { appState.polishTranscript() }
                    .disabled(appState.transcript.isEmpty || appState.isTranscribing || appState.isPolishing)
                Button("清空") { appState.clearTranscript() }
                    .disabled(appState.transcript.isEmpty || appState.isTranscribing || appState.isPolishing)
                Button("复制") { appState.copyTranscript() }
                    .keyboardShortcut("c", modifiers: [.command, .option])
                    .disabled(appState.transcript.isEmpty || appState.isPolishing)
                Button("保存") { appState.saveTranscript() }
                    .disabled(appState.transcript.isEmpty || appState.isPolishing)
            }
            .padding(12)
        }
        .animation(.easeInOut(duration: 0.2), value: appState.isRecording)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if appState.isTranscribing || appState.isPolishing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }
}

private struct RecordingWaveformView: View {
    let levels: [Double]
    let isRecording: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let count = max(levels.count, 1)
                let slotWidth = size.width / CGFloat(count)
                let barWidth = max(2, slotWidth * 0.48)
                let centerY = size.height / 2
                let phase = timeline.date.timeIntervalSinceReferenceDate * 4.0

                for index in 0..<count {
                    let recordedLevel = index < levels.count ? levels[index] : 0.04
                    let idlePulse = isRecording
                        ? 0.025 + 0.025 * ((sin(phase + Double(index) * 0.38) + 1.0) / 2.0)
                        : 0.0
                    let amplitude = max(recordedLevel, idlePulse)
                    let barHeight = max(4, CGFloat(amplitude) * size.height * 0.9)
                    let x = CGFloat(index) * slotWidth + (slotWidth - barWidth) / 2
                    let rect = CGRect(
                        x: x,
                        y: centerY - barHeight / 2,
                        width: barWidth,
                        height: barHeight
                    )
                    let color = isRecording
                        ? Color.red.opacity(0.85)
                        : Color.secondary.opacity(0.5)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: barWidth / 2),
                        with: .color(color)
                    )
                }
            }
        }
        .frame(height: 64)
        .padding(.horizontal, 12)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.18), lineWidth: 1)
        }
    }
}

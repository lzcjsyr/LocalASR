import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selection = "record"

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("本地 ASR") {
                    Label("录音转写", systemImage: "waveform.circle.fill")
                        .tag("record")
                    Label("模型", systemImage: "shippingbox")
                        .tag("models")
                }

                Section("后台设置") {
                    Label("LLM 设置", systemImage: "slider.horizontal.3")
                        .tag("llm-settings")
                }

            }
            .listStyle(.sidebar)
            .navigationTitle("本地 ASR")
        } detail: {
            Group {
                if selection == "models" {
                    ModelsView(modelStore: appState.modelStore)
                } else if selection == "llm-settings" {
                    LLMSettingsView(llmStore: appState.llmStore)
                } else {
                    RecorderView(recorder: appState.recorder)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .alert("提示", isPresented: Binding(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )) {
            Button("好") { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }
}

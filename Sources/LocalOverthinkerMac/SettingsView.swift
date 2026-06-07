import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Form {
            Section("Models") {
                Picker("Reflection Model", selection: Binding(
                    get: { store.ollamaSettings.reflectionModel },
                    set: { store.updateReflectionModel($0) }
                )) {
                    ForEach(modelOptions, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }

                Picker("Embedding Model", selection: Binding(
                    get: { store.ollamaSettings.embeddingModel },
                    set: { store.updateEmbeddingModel($0) }
                )) {
                    ForEach(modelOptions, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }

                HStack {
                    Text("Local models are read from Ollama.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Refresh Models") {
                        store.refreshAvailableModels()
                    }
                    .controlSize(.small)
                    .disabled(store.ollamaStatus != .online)
                }
            }

            Section("Runtime") {
                HStack {
                    Text("Temperature")
                    Spacer()
                    Text(String(format: "%.2f", store.ollamaSettings.runtime.temperature))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Slider(
                    value: Binding(
                        get: { store.ollamaSettings.runtime.temperature },
                        set: { store.updateTemperature($0) }
                    ),
                    in: 0...1.5
                )

                Stepper(
                    value: Binding(
                        get: { store.ollamaSettings.runtime.numContextTokens },
                        set: { store.updateContextWindow($0) }
                    ),
                    in: 512...16384,
                    step: 512
                ) {
                    settingsValueRow("Context Tokens", value: "\(store.ollamaSettings.runtime.numContextTokens)")
                }

                Stepper(
                    value: Binding(
                        get: { store.ollamaSettings.runtime.maxOutputTokens },
                        set: { store.updateMaxOutputTokens($0) }
                    ),
                    in: 64...2048,
                    step: 64
                ) {
                    settingsValueRow("Max Output", value: "\(store.ollamaSettings.runtime.maxOutputTokens)")
                }

                Stepper(
                    value: Binding(
                        get: { store.ollamaSettings.runtime.numThreads },
                        set: { store.updateThreadCount($0) }
                    ),
                    in: 1...12
                ) {
                    settingsValueRow("Threads", value: "\(store.ollamaSettings.runtime.numThreads)")
                }
            }

            Section("Status") {
                settingsValueRow("Ollama", value: ollamaStatusLabel, color: ollamaStatusColor)
                settingsValueRow(
                    "Clipboard",
                    value: store.clipboardStatus == .active ? "Background watcher active" : "Watcher unavailable"
                )
                settingsValueRow("Automatic Reflections", value: store.automaticReflectionStatusText)

                HStack {
                    Text("Data Folder")
                    Spacer()
                    Button("Open") {
                        store.openDataFolder()
                    }
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(minWidth: 520, idealWidth: 560, minHeight: 420)
    }

    private var modelOptions: [String] {
        if store.availableOllamaModels.isEmpty {
            return [store.ollamaSettings.reflectionModel, store.ollamaSettings.embeddingModel]
        }

        return store.availableOllamaModels
    }

    private var ollamaStatusLabel: String {
        switch store.ollamaStatus {
        case .checking:
            return "Checking connection"
        case .online:
            return "Connected"
        case .offline:
            return "Offline, using fallback reflections"
        }
    }

    private var ollamaStatusColor: Color {
        switch store.ollamaStatus {
        case .checking:
            return .secondary
        case .online:
            return .green
        case .offline:
            return .red
        }
    }

    @ViewBuilder
    private func settingsValueRow(_ label: String, value: String, color: Color = .secondary) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(color)
                .multilineTextAlignment(.trailing)
        }
    }
}

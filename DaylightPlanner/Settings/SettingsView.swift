import SwiftUI

struct SettingsView: View {
    @AppStorage("llm.primary") private var primary = "apple"
    @AppStorage("llm.localEnabled") private var localEnabled = true
    @AppStorage("llm.baseURL") private var baseURL = "http://localhost:11434/v1"
    @AppStorage("llm.model") private var model = "llama3.2"

    @State private var apiKey = Keychain.get("llm.apiKey")
    @State private var status = ""
    @State private var testing = false

    var body: some View {
        Form {
            SwiftUI.Section("Quick add parsing") {
                Picker("Try first", selection: $primary) {
                    Text("Apple on-device").tag("apple")
                    Text("Local small model").tag("local")
                    Text("External model").tag("external")
                }
                Toggle("Use local small model (Qwen3 1.7B, ~1 GB download)", isOn: $localEnabled)
                Text("If a backend is unavailable or fails, the next one is tried, then the basic parser.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            SwiftUI.Section("External model (OpenAI-compatible, optional)") {
                TextField("Base URL", text: $baseURL)
                TextField("Model", text: $model)
                SecureField("API key (not needed for local servers)", text: $apiKey)
                    .onChange(of: apiKey) { Keychain.set(apiKey, for: "llm.apiKey") }
                HStack {
                    Button("Test") { test() }.disabled(testing)
                    if testing { ProgressView().controlSize(.small) }
                    Text(status).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Text("Presets: Ollama http://localhost:11434/v1 · LM Studio http://localhost:1234/v1 · OpenAI https://api.openai.com/v1")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 540, height: 460)
    }

    private func test() {
        testing = true
        status = ""
        Task { @MainActor in
            do {
                let d = try await RemoteLLM.parse("Lunch with Sam tomorrow 1pm", now: .now)
                status = "OK: \(d.title) at \(d.start)"
            } catch {
                status = "Failed: \(error.localizedDescription)"
            }
            testing = false
        }
    }
}

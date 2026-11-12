import Foundation
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import Tokenizers

enum EventPrompt {
    static func system(now: Date) -> String {
        let cal = Calendar.current
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEEE, yyyy-MM-dd HH:mm"
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "yyyy-MM-dd"
        let tomorrow = day.string(from: cal.date(byAdding: .day, value: 1, to: now) ?? now)

        return """
        You convert one casual sentence into a calendar event. Reply with ONE JSON object and nothing else.
        Today is \(f.string(from: now)) (\(TimeZone.current.identifier)).
        Keys: title (short, without date, time or priority words), \
        start (local time as yyyy-MM-dd'T'HH:mm in 24-hour format, 09:00 if no time is given), \
        durationMinutes (integer, 60 if unknown), place (string, empty if none), \
        repeatRule (one of: none, daily, weekdays, weekly, biweekly, monthly, yearly), \
        importance (one of: low, normal, high, critical).
        Example input: lunch with Sam tomorrow 1pm at Gangnam, important
        Example output: {"title":"Lunch with Sam","start":"\(tomorrow)T13:00","durationMinutes":60,"place":"Gangnam","repeatRule":"none","importance":"high"}
        """
    }
}

actor LocalLLM {
    static let shared = LocalLLM()
    static let modelID = "Qwen/Qwen3-1.7B-MLX-4bit"
    static let label = "Qwen3 1.7B"

    static var enabled: Bool {
        UserDefaults.standard.object(forKey: "llm.localEnabled") as? Bool ?? true
    }

    private var container: ModelContainer?

    private func load() async throws -> ModelContainer {
        if let container { return container }
        let c = try await #huggingFaceLoadModelContainer(
            configuration: ModelConfiguration(id: Self.modelID)
        )
        container = c
        return c
    }

    func warmUp() async { _ = try? await load() }

    func unload() { container = nil }
    
    func generate(system: String, prompt: String) async throws -> String {
        let model = try await load()
        let session = ChatSession(model, instructions: system)
        var text = try await session.respond(to: prompt + " /no_think")
        text = text.replacingOccurrences(of: "<think>[\\s\\S]*?</think>", with: "",
                                         options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func parse(_ input: String, now: Date) async throws -> DraftFields {
        let model = try await load()
        let session = ChatSession(model, instructions: EventPrompt.system(now: now))
        var text = try await session.respond(to: input + " /no_think")

        text = text.replacingOccurrences(of: "<think>[\\s\\S]*?</think>", with: "",
                                         options: .regularExpression)
        guard let a = text.firstIndex(of: "{"), let b = text.lastIndex(of: "}"), a < b else {
            throw URLError(.cannotParseResponse)
        }
        return try JSONDecoder().decode(DraftFields.self, from: Data(text[a...b].utf8))
    }
}

import Foundation
import Security

// MARK: - Shared draft type (used by every LLM backend)
struct DraftFields: Codable {
    var title: String
    var start: String
    var durationMinutes: Int
    var place: String
    var repeatRule: String
    var importance: String
}

// MARK: - Keychain helper
enum Keychain {
    private static func base(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "DaylightPlanner",
         kSecAttrAccount as String: key]
    }

    static func set(_ value: String, for key: String) {
        SecItemDelete(base(key) as CFDictionary)
        guard !value.isEmpty else { return }
        var add = base(key)
        add[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(add as CFDictionary, nil)
    }

    static func get(_ key: String) -> String {
        var q = base(key)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let d = out as? Data else { return "" }
        return String(decoding: d, as: UTF8.self)
    }
}

// MARK: - OpenAI-compatible client (OpenAI, Ollama, LM Studio, OpenRouter...)
enum RemoteLLM {
    static var baseURL: String { UserDefaults.standard.string(forKey: "llm.baseURL") ?? "" }
    static var model: String { UserDefaults.standard.string(forKey: "llm.model") ?? "" }
    static var isConfigured: Bool { !baseURL.isEmpty && !model.isEmpty }

    static func parse(_ input: String, now: Date) async throws -> DraftFields {
        let base = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard let url = URL(string: base + "/chat/completions"), !model.isEmpty else {
            throw URLError(.badURL)
        }

        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "title": ["type": "string"],
                "start": ["type": "string"],
                "durationMinutes": ["type": "integer"],
                "place": ["type": "string"],
                "repeatRule": ["type": "string",
                               "enum": ["none", "daily", "weekdays", "weekly", "biweekly", "monthly", "yearly"]],
                "importance": ["type": "string", "enum": ["low", "normal", "high", "critical"]]
            ],
            "required": ["title", "start", "durationMinutes", "place", "repeatRule", "importance"],
            "additionalProperties": false
        ]

        let body: [String: Any] = [
            "model": model,
            "temperature": 0,
            "messages": [
                ["role": "system", "content": EventPrompt.system(now: now)],
                ["role": "user", "content": input]
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": ["name": "calendar_event", "strict": true, "schema": schema]
            ]
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 20
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let key = Keychain.get("llm.apiKey")
        if !key.isEmpty { req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        struct Reply: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }

        let reply = try JSONDecoder().decode(Reply.self, from: data)
        guard var text = reply.choices.first?.message.content else {
            throw URLError(.cannotParseResponse)
        }
        text = text.replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return try JSONDecoder().decode(DraftFields.self, from: Data(text.utf8))
    }
}

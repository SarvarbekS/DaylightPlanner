import SwiftUI
import Observation
import FoundationModels

// MARK: - Tone
enum CoachTone: String, CaseIterable, Identifiable {
    case mixed, cheerleader, strict, rude, roast
    var id: String { rawValue }

    var label: String {
        switch self {
        case .mixed: return "Mixed"
        case .cheerleader: return "Cheerleader"
        case .strict: return "Drill sergeant"
        case .rude: return "Sarcastic"
        case .roast: return "Savage roast"
        }
    }

    var icon: String {
        switch self {
        case .mixed: return "shuffle"
        case .cheerleader: return "hands.clap"
        case .strict: return "megaphone"
        case .rude: return "exclamationmark.bubble"
        case .roast: return "flame.fill"
        }
    }

    func resolved() -> CoachTone {
        guard self == .mixed else { return self }
        let r = Double.random(in: 0..<1)
        if r < 0.25 { return .cheerleader }
        if r < 0.55 { return .strict }
        if r < 0.80 { return .rude }
        return .roast
    }

    func mood(for kind: SituationKind) -> MascotMood {
        switch self {
        case .cheerleader, .mixed: return kind == .allDone ? .proud : .happy
        case .strict: return kind == .allDone ? .proud : .stern
        case .rude: return .smug
        case .roast: return (kind == .allDone || kind == .checked) ? .smug : .furious
        }
    }
}

// MARK: - Context
enum SituationKind { case greeting, talk, checked, unchecked, allDone }

struct CoachContext {
    var kind: SituationKind
    var habit: String?
    var left: [String]
    var doneCount: Int
    var dueCount: Int
    var bestStreak: String?
    var missedYesterday: [String]
    var now: Date = .now

    var prompt: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEEE HH:mm"
        var lines = ["Now: \(f.string(from: now))",
                     "Today: \(doneCount) of \(dueCount) habits done"]
        lines.append(left.isEmpty ? "Nothing left today" : "Still to do: " + left.joined(separator: ", "))
        if let b = bestStreak { lines.append("Longest streak: \(b)") }
        if !missedYesterday.isEmpty { lines.append("Missed yesterday: " + missedYesterday.joined(separator: ", ")) }
        switch kind {
        case .greeting: lines.append("Event: the user just opened the habit tracker.")
        case .talk: lines.append("Event: the user asked you for a pep talk.")
        case .checked: lines.append("Event: the user just checked off '\(habit ?? "a habit")'.")
        case .unchecked: lines.append("Event: the user just unchecked '\(habit ?? "a habit")'.")
        case .allDone: lines.append("Event: the user just finished every habit for today.")
        }
        lines.append("Write your next message to the user.")
        return lines.joined(separator: "\n")
    }
}

// MARK: - Prompts
enum CoachPrompts {
    static func system(_ tone: CoachTone) -> String {
        let base = """
        You are Daylight, a small sun mascot who coaches the user's daily habits inside their planner app. \
        Reply with ONE or TWO short sentences, at most 35 words, plain text, no quotes, no emoji, no hashtags. \
        Refer to the user's real habits and numbers from the context. \
        End with a push toward a concrete next action, unless everything is already done. \
        Hard limits: no slurs or hateful language, nothing about the user's body, appearance, health, family, \
        identity, intelligence or self-worth, no profanity stronger than 'damn', and never encourage self-harm. \
        Any insult must target laziness, excuses and procrastination only, and stay playful and witty.
        """
        let voice: String
        switch tone {
        case .cheerleader, .mixed:
            voice = "Tone: warm, upbeat and specific. Celebrate effort and gently nudge."
        case .strict:
            voice = "Tone: strict drill-sergeant coach. Short, firm, imperative sentences. No fluff, no jokes. Praise only when earned, and tersely."
        case .rude:
            voice = "Tone: rude and sarcastic. Dry, eye-rolling, passive-aggressive remarks about their slacking. Give backhanded compliments when they do well."
        case .roast:
            voice = "Tone: savage comedy roast. Witty, over-the-top insults aimed at their laziness, procrastination and excuses, never at who they are. Funny and punchy, then tell them to go do the habit."
        }
        return base + "\n" + voice
    }

    private static let blocked = ["kill yourself", "kys", "worthless", "hate yourself",
                                  "you should die", "end your life"]

    static func clean(_ raw: String) -> String {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["Daylight AI:", "Daylight:"] where t.hasPrefix(prefix) {
            t = String(t.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        }
        t = t.trimmingCharacters(in: CharacterSet(charactersIn: "\"“”"))
        t = t.replacingOccurrences(of: "\n", with: " ")
        let lower = t.lowercased()
        if blocked.contains(where: { lower.contains($0) }) { return "" }
        if t.count > 260 {
            let cut = String(t.prefix(260))
            if let end = cut.lastIndex(where: { ".!?".contains($0) }) {
                t = String(cut[...end])
            } else {
                t = cut
            }
        }
        return t
    }
}

// MARK: - Built-in lines (used when no model answers)
enum CoachLines {
    static let cheer: [String: [String]] = [
        "allDone": ["Every habit done. That's what showing up looks like. Proud of you.",
                    "Perfect day! Enjoy it, you earned it."],
        "some": ["Only {left} to go. You're close, go finish {habit}.",
                 "{done} done already. {habit} next, and the day is yours."],
        "none": ["Fresh start. One tiny habit, {habit}, and the momentum begins.",
                 "Nothing yet, and that's fine. Start with {habit} and see how it feels."],
        "checked": ["Nice. {habit} is done. Keep rolling.", "Yes! {habit} ticked off. Next one?"],
        "unchecked": ["No worries, it happens. Make {habit} count later today."]
    ]
    static let strict: [String: [String]] = [
        "allDone": ["All habits complete. Acceptable. Same standard tomorrow."],
        "some": ["{left} remaining. {habit}. Now. No negotiating.", "{done} down, {left} to go. Move."],
        "none": ["Zero habits done. Start with {habit}. Move.", "The day is leaking. {habit}. Go."],
        "checked": ["{habit} logged. Next.", "Good. Don't stop."],
        "unchecked": ["Unchecked? Then earn it back. Today."]
    ]
    static let rude: [String: [String]] = [
        "allDone": ["Oh wow, you did your habits. Want a medal? ...Fine. Well done."],
        "some": ["Still {left} undone. The couch must be really comfortable.",
                 "{habit} is just sitting there, waiting. Like your potential."],
        "none": ["Nothing done yet? Bold strategy, hoping it does itself.",
                 "Zero habits. Impressive commitment to doing nothing."],
        "checked": ["Look at you doing {habit}. Try that again tomorrow, if you can manage."],
        "unchecked": ["Unchecking it? Cute. Lying to an app isn't discipline."]
    ]
    static let roast: [String: [String]] = [
        "allDone": ["All done?! Who are you, and what did you do with the professional procrastinator?"],
        "some": ["{left} habits left. Your excuses are getting more cardio than you.",
                 "Still not done with {habit}? Your goals are filing a missing-effort report."],
        "none": ["Zero habits. Your goals just reported your effort as a missing person.",
                 "Nothing done. Even your alarm clock has given up on you."],
        "checked": ["{habit} done. Frame this moment, it's rare."],
        "unchecked": ["You unchecked {habit}. Even your willpower is on 'last seen yesterday'."]
    ]

    static func pick(_ tone: CoachTone, _ c: CoachContext) -> String {
        let key: String
        switch c.kind {
        case .allDone: key = "allDone"
        case .checked: key = "checked"
        case .unchecked: key = "unchecked"
        default: key = c.left.isEmpty ? "allDone" : (c.doneCount == 0 ? "none" : "some")
        }
        let table: [String: [String]]
        switch tone {
        case .cheerleader, .mixed: table = cheer
        case .strict: table = strict
        case .rude: table = rude
        case .roast: table = roast
        }
        var line = (table[key] ?? cheer[key] ?? ["Go do the next habit."]).randomElement() ?? "Go do the next habit."
        line = line.replacingOccurrences(of: "{habit}", with: c.habit ?? c.left.first ?? "your next habit")
        line = line.replacingOccurrences(of: "{left}", with: String(c.left.count))
        line = line.replacingOccurrences(of: "{done}", with: String(c.doneCount))
        return line
    }
}

// MARK: - LLM routing
@MainActor
enum CoachLLM {
    private enum Backend { case apple, local, external }

    static func say(system: String, prompt: String, preferLocal: Bool) async -> (text: String, source: String)? {
        var order: [Backend]
        switch UserDefaults.standard.string(forKey: "llm.primary") {
        case "local": order = [.local, .apple, .external]
        case "external": order = [.external, .apple, .local]
        default: order = [.apple, .local, .external]
        }
        if preferLocal { order = [.local, .external, .apple] }

        for backend in order {
            guard !Task.isCancelled else { return nil }
            switch backend {
            case .apple where EventParser.aiAvailable:
                if let t = try? await appleReply(system, prompt), valid(t) {
                    guard !Task.isCancelled else { return nil }
                    return (t, "On-device AI")
                }
            case .local where LocalLLM.enabled:
                if let t = try? await LocalLLM.shared.generate(system: system, prompt: prompt), valid(t) {
                    guard !Task.isCancelled else { return nil }
                    return (t, "Local · \(LocalLLM.label)")
                }
            case .external where RemoteLLM.isConfigured:
                if let t = try? await RemoteLLM.chat(system: system, prompt: prompt), valid(t) {
                    guard !Task.isCancelled else { return nil }
                    return (t, "External · \(RemoteLLM.model)")
                }
            default:
                break
            }
        }
        return nil
    }

    private static func appleReply(_ system: String, _ prompt: String) async throws -> String {
        let session = LanguageModelSession(instructions: system)
        let response = try await session.respond(to: prompt)
        return response.content
    }

    private static func valid(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if t.isEmpty { return false }
        let refusals = ["i can't", "i cannot", "i'm sorry", "i am sorry", "as an ai", "i'm unable", "i am unable"]
        return !refusals.contains { t.contains($0) }
    }
}

extension RemoteLLM {
    static func chat(system: String, prompt: String) async throws -> String {
        let base = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard let url = URL(string: base + "/chat/completions"), !model.isEmpty else {
            throw URLError(.badURL)
        }
        let body: [String: Any] = [
            "model": model,
            "temperature": 0.9,
            "max_tokens": 120,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": prompt]
            ]
        ]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 20
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let key = Keychain.get("llm.apiKey")
        if !key.isEmpty { req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        try Task.checkCancellation()
        let (data, resp) = try await URLSession.shared.data(for: req)
        try Task.checkCancellation()
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }

        struct Reply: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }
        let reply = try JSONDecoder().decode(Reply.self, from: data)
        guard let text = reply.choices.first?.message.content else { throw URLError(.cannotParseResponse) }
        return text
    }
}

// MARK: - Coach state
@MainActor @Observable
final class Coach {
    static let shared = Coach()

    var message = ""
    var mood: MascotMood = .happy
    var thinking = false
    var source = ""
    var lastSpoke: Date = .distantPast

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var requestID = UUID()

    func cancel() {
        requestID = UUID()
        task?.cancel()
        task = nil
        thinking = false
        if mood == .thinking { mood = .happy }
    }

    func showInstant(_ ctx: CoachContext, tone: CoachTone = .mixed) {
        cancel()
        let actual = tone.resolved()
        displayBuiltIn(ctx, tone: actual)
    }

    func speak(_ ctx: CoachContext, tone: CoachTone) {
        switch ctx.kind {
        case .checked, .unchecked, .allDone:
            showInstant(ctx, tone: tone)
            return
        case .greeting, .talk:
            break
        }

        cancel()
        let actual = tone.resolved()
        let id = requestID

        // A usable message remains available if generation fails.
        displayBuiltIn(ctx, tone: actual)
        thinking = true
        mood = .thinking

        task = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(350))
                try Task.checkCancellation()
            } catch {
                return
            }

            let result = await CoachLLM.say(
                system: CoachPrompts.system(actual),
                prompt: ctx.prompt,
                preferLocal: actual == .rude || actual == .roast
            )

            guard !Task.isCancelled,
                  let self,
                  self.requestID == id else { return }

            if let result {
                let cleaned = CoachPrompts.clean(result.text)
                if !cleaned.isEmpty {
                    self.message = cleaned
                    self.source = result.source
                }
            }

            self.mood = actual.mood(for: ctx.kind)
            self.thinking = false
            self.lastSpoke = .now
            self.task = nil
        }
    }

    private func displayBuiltIn(_ ctx: CoachContext, tone: CoachTone) {
        message = CoachLines.pick(tone, ctx)
        source = "Built-in lines"
        mood = tone.mood(for: ctx.kind)
        thinking = false
        lastSpoke = .now
    }
}

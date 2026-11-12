import Foundation
import FoundationModels

// MARK: - Apple on-device schema
@Generable
struct EventDraft {
    @Guide(description: "Short event title. Remove date, time, repeat and priority words.")
    var title: String

    @Guide(description: "Local start time formatted exactly yyyy-MM-dd'T'HH:mm in 24-hour time. Resolve relative dates from today's date in the instructions. Use 09:00 if no time is given.")
    var start: String

    @Guide(description: "Duration in minutes. Use 60 if not stated.")
    var durationMinutes: Int

    @Guide(description: "Location or short note if mentioned, otherwise an empty string.")
    var place: String

    @Guide(description: "How often the event repeats.",
           .anyOf(["none", "daily", "weekdays", "weekly", "biweekly", "monthly", "yearly"]))
    var repeatRule: String

    @Guide(description: "Importance. Words like urgent, important, don't forget or critical raise it.",
           .anyOf(["low", "normal", "high", "critical"]))
    var importance: String
}

// MARK: - Shared result types
struct ParsedEvent {
    var title: String
    var start: Date
    var end: Date
    var place: String?
    var rule: RepeatRule
    var importance: Importance
}

struct ParseResult {
    var event: ParsedEvent
    var source: String
}

// MARK: - Parser
@MainActor
enum EventParser {
    private enum Backend { case apple, local, external }

    static var aiAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    static func parse(_ input: String, now: Date = .now) async -> ParseResult {
        let detected = detect(input)

        let order: [Backend]
        switch UserDefaults.standard.string(forKey: "llm.primary") {
        case "local":    order = [.local, .apple, .external]
        case "external": order = [.external, .apple, .local]
        default:         order = [.apple, .local, .external]
        }

        for backend in order {
            switch backend {
            case .apple where aiAvailable:
                if let c = try? await runAppleModel(input, now: now) {
                    let fields = DraftFields(title: c.title, start: c.start,
                                             durationMinutes: c.durationMinutes, place: c.place,
                                             repeatRule: c.repeatRule, importance: c.importance)
                    return ParseResult(event: build(fields, detected: detected, now: now),
                                       source: "On-device AI")
                }
            case .local where LocalLLM.enabled:
                if let fields = try? await LocalLLM.shared.parse(input, now: now) {
                    return ParseResult(event: build(fields, detected: detected, now: now),
                                       source: "Local · \(LocalLLM.label)")
                }
            case .external where RemoteLLM.isConfigured:
                if let fields = try? await RemoteLLM.parse(input, now: now) {
                    return ParseResult(event: build(fields, detected: detected, now: now),
                                       source: "External · \(RemoteLLM.model)")
                }
            default:
                break
            }
        }

        return ParseResult(event: fallback(input, detected: detected, now: now),
                           source: "Basic parser")
    }

    // MARK: Apple Foundation Models
    private static func runAppleModel(_ input: String, now: Date) async throws -> EventDraft {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEEE, yyyy-MM-dd HH:mm"
        let instructions = """
        You turn one casual sentence into a calendar event. \
        Today is \(f.string(from: now)) in time zone \(TimeZone.current.identifier). \
        Resolve words like tomorrow, next Friday or in two hours from that moment. \
        Keep the title short.
        """
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: input, generating: EventDraft.self)
        return response.content
    }

    // MARK: Build final event from any LLM's fields
    private static func build(_ d: DraftFields, detected: Detected?, now: Date) -> ParsedEvent {
        let cal = Calendar.current
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        let llmStart = f.date(from: d.start)

        var start: Date
        if let det = detected {
            let c = cal.dateComponents([.hour, .minute], from: det.date)
            let isNoonDefault = c.hour == 12 && c.minute == 0
            if !isNoonDefault {
                start = det.date
            } else if let l = llmStart {
                let t = cal.dateComponents([.hour, .minute], from: l)
                start = cal.date(bySettingHour: t.hour ?? 9, minute: t.minute ?? 0,
                                 second: 0, of: det.date) ?? det.date
            } else {
                start = det.date
            }
        } else if let l = llmStart {
            start = l
        } else {
            start = nextHour(now)
        }

        var minutes = min(max(d.durationMinutes, 5), 1440)
        if let det = detected, det.duration > 0 { minutes = Int(det.duration / 60) }

        let importanceMap: [String: Importance] =
            ["low": .low, "normal": .normal, "high": .high, "critical": .critical]

        return ParsedEvent(
            title: d.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "New event" : d.title,
            start: start,
            end: start.addingTimeInterval(Double(minutes) * 60),
            place: d.place.isEmpty ? nil : d.place,
            rule: RepeatRule(rawValue: d.repeatRule) ?? .none,
            importance: importanceMap[d.importance] ?? .normal
        )
    }

    // MARK: Fallback (no AI)
    private static func fallback(_ input: String, detected: Detected?, now: Date) -> ParsedEvent {
        let lower = input.lowercased()
        var title = input
        if let det = detected {
            title = (input as NSString).replacingCharacters(in: det.range, with: "")
        }

        let noise = "every weekday|every day|daily|every week|weekly|every month|monthly|every year|yearly|annually|high priority|important|urgent|asap|critical"
        title = title.replacingOccurrences(of: noise, with: "", options: [.regularExpression, .caseInsensitive])
        title = title.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,.-–:"))

        let rule: RepeatRule =
            lower.contains("weekday") ? .weekdays :
            (lower.contains("every day") || lower.contains("daily")) ? .daily :
            (lower.contains("every week") || lower.contains("weekly")) ? .weekly :
            (lower.contains("every month") || lower.contains("monthly")) ? .monthly :
            (lower.contains("every year") || lower.contains("yearly") || lower.contains("annually")) ? .yearly : .none

        let importance: Importance =
            (lower.contains("urgent") || lower.contains("critical") || lower.contains("asap")) ? .critical :
            (lower.contains("important") || lower.contains("high priority")) ? .high : .normal

        let start = detected?.date ?? nextHour(now)
        let dur: TimeInterval = (detected?.duration ?? 0) > 0 ? detected!.duration : 3600
        return ParsedEvent(title: title.isEmpty ? "New event" : title, start: start,
                           end: start.addingTimeInterval(dur), place: nil,
                           rule: rule, importance: importance)
    }

    // MARK: Date detection
    struct Detected { let date: Date; let duration: TimeInterval; let range: NSRange }

    private static func detect(_ s: String) -> Detected? {
        guard let det = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue),
              let m = det.matches(in: s, range: NSRange(s.startIndex..., in: s)).first,
              let date = m.date else { return nil }
        return Detected(date: date, duration: m.duration, range: m.range)
    }

    private static func nextHour(_ now: Date) -> Date {
        let cal = Calendar.current
        let h = cal.component(.hour, from: now) + 1
        return cal.date(bySettingHour: min(h, 23), minute: 0, second: 0, of: now) ?? now
    }
}

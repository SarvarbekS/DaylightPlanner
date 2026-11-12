import SwiftUI
import SwiftData

func paletteTint(_ key: String) -> Color {
    switch key {
    case "peach":  return Color.dlPeach
    case "green":  return Color.dlGreen
    case "blue":   return Color.dlBlue
    case "rose":   return Color.dlRose
    case "yellow": return Color.dlYellow
    default:       return Color.dlLilac
    }
}

func paletteDot(_ key: String) -> Color {
    switch key {
    case "peach":  return Color(hex: 0xE8A07C)
    case "green":  return Color(hex: 0x7CC4A0)
    case "blue":   return Color(hex: 0x7BA3D6)
    case "rose":   return Color(hex: 0xD9788A)
    case "yellow": return Color(hex: 0xE3B94F)
    default:       return Color.dlAccent
    }
}

extension Event {
    var tint: Color { paletteTint(colorKey) }
    var dot: Color { paletteDot(colorKey) }
}

let eventColorKeys = ["lilac", "peach", "green", "blue", "rose", "yellow"]

struct Occurrence: Identifiable {
    let event: Event
    let start: Date
    let end: Date
    var id: String { "\(event.persistentModelID.hashValue)-\(start.timeIntervalSince1970)" }
    var minutes: Int { max(Int(end.timeIntervalSince(start) / 60), 0) }
}

extension Event {
    func occurrences(from a: Date, to b: Date, cal: Calendar) -> [Occurrence] {
        let dur = end.timeIntervalSince(start)
        let limit = repeatUntil.flatMap { cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: $0)) }

        func make(_ s: Date) -> Occurrence? {
            let e = s.addingTimeInterval(dur)
            guard s < b, e > a else { return nil }
            return Occurrence(event: self, start: s, end: e)
        }

        let rule = repeatRule
        if rule == .none { return make(start).map { [$0] } ?? [] }

        let comp: Calendar.Component
        let n: Int
        switch rule {
        case .daily, .weekdays: comp = .day; n = 1
        case .weekly: comp = .weekOfYear; n = 1
        case .biweekly: comp = .weekOfYear; n = 2
        case .monthly: comp = .month; n = 1
        default: comp = .year; n = 1
        }

        var out: [Occurrence] = []
        var k = 0
        while k < 5000 {
            guard let s = cal.date(byAdding: comp, value: k * n, to: start) else { break }
            if s >= b { break }
            if let limit, s >= limit { break }
            let wd = cal.component(.weekday, from: s)
            let skip = rule == .weekdays && (wd == 1 || wd == 7)
            if !skip, let o = make(s) { out.append(o) }
            k += 1
        }
        return out
    }
}

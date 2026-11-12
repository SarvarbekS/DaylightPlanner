import Foundation

struct StreakInfo {
    let value: Int
    let weekly: Bool
    var text: String {
        let unit = weekly ? "week" : "day"
        return "\(value) \(unit)\(value == 1 ? "" : "s")"
    }
    var approxDays: Int { weekly ? value * 7 : value }
}

enum HabitMath {
    static var cal: Calendar {
        var calendar = cachedCalendar
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }

    private static let cachedCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }()

    static func startOfWeek(_ d: Date) -> Date {
        cal.dateInterval(of: .weekOfYear, for: d)?.start ?? cal.startOfDay(for: d)
    }

    static func weekEnd(_ start: Date) -> Date {
        cal.date(byAdding: .day, value: 6, to: start) ?? start
    }

    static func weekDays(_ start: Date) -> [Date] {
        (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    static func count(_ h: Habit, from a: Date, to b: Date) -> Int {
        let s = cal.startOfDay(for: a)
        let e = cal.startOfDay(for: b)
        return h.completedDays.filter { $0 >= s && $0 <= e }.count
    }

    static func isDue(_ h: Habit, on d: Date) -> Bool {
        if h.targetPerWeek >= 7 { return true }
        if h.isDone(d) { return true }
        let ws = startOfWeek(d)
        return count(h, from: ws, to: weekEnd(ws)) < h.targetPerWeek
    }

    // All-time longest consecutive run across the saved completion history.
    static func streak(_ h: Habit, today: Date = .now) -> StreakInfo {
        let calendar = cal
        let cutoff = calendar.startOfDay(for: today)
        let completed = Set(h.completedDays.map {
            calendar.startOfDay(for: $0)
        }).filter { $0 <= cutoff }

        if h.targetPerWeek >= 7 {
            return StreakInfo(
                value: longestRun(in: completed.sorted(), component: .day, calendar: calendar),
                weekly: false
            )
        }

        // Count distinct completion days in each Monday-based calendar week.
        var weeklyCounts: [Date: Int] = [:]
        for day in completed {
            guard let week = calendar.dateInterval(of: .weekOfYear, for: day)?.start else {
                continue
            }
            weeklyCounts[week, default: 0] += 1
        }

        let target = max(1, min(h.targetPerWeek, 7))
        let successfulWeeks = weeklyCounts.compactMap { entry -> Date? in
            entry.value >= target ? entry.key : nil
        }.sorted()

        return StreakInfo(
            value: longestRun(in: successfulWeeks, component: .weekOfYear, calendar: calendar),
            weekly: true
        )
    }

    private static func longestRun(
        in dates: [Date],
        component: Calendar.Component,
        calendar: Calendar
    ) -> Int {
        var best = 0
        var run = 0
        var previous: Date?

        for date in dates {
            if let previous,
               let expected = calendar.date(byAdding: component, value: 1, to: previous),
               calendar.isDate(expected, inSameDayAs: date) {
                run += 1
            } else {
                run = 1
            }

            best = max(best, run)
            previous = date
        }

        return best
    }

    static func currentStreak(_ h: Habit, today: Date = .now) -> StreakInfo {
        if h.targetPerWeek >= 7 {
            var d = cal.startOfDay(for: today)
            if !h.isDone(d) { d = cal.date(byAdding: .day, value: -1, to: d) ?? d }
            var n = 0
            while h.isDone(d), n < 3650 {
                n += 1
                d = cal.date(byAdding: .day, value: -1, to: d) ?? d
            }
            return StreakInfo(value: n, weekly: false)
        } else {
            var ws = startOfWeek(today)
            if count(h, from: ws, to: weekEnd(ws)) < h.targetPerWeek {
                ws = cal.date(byAdding: .weekOfYear, value: -1, to: ws) ?? ws
            }
            var n = 0
            while count(h, from: ws, to: weekEnd(ws)) >= h.targetPerWeek, n < 520 {
                n += 1
                ws = cal.date(byAdding: .weekOfYear, value: -1, to: ws) ?? ws
            }
            return StreakInfo(value: n, weekly: true)
        }
    }

    static func weeklyRate(_ hs: [Habit], endingAt end: Date) -> Double {
        let start = cal.date(byAdding: .day, value: -6, to: end) ?? end
        var done = 0.0
        var total = 0.0
        for h in hs {
            done += Double(min(count(h, from: start, to: end), h.targetPerWeek))
            total += Double(h.targetPerWeek)
        }
        return total == 0 ? 0 : min(done / total, 1)
    }

    static func consistency(_ hs: [Habit], days: Int, today: Date = .now) -> Double {
        let end = cal.startOfDay(for: today)
        let windowStart = cal.date(byAdding: .day, value: -(days - 1), to: end) ?? end
        var done = 0.0
        var possible = 0.0
        for h in hs {
            let start = max(windowStart, cal.startOfDay(for: h.createdAt))
            guard start <= end else { continue }
            let n = (cal.dateComponents([.day], from: start, to: end).day ?? 0) + 1
            possible += Double(h.targetPerWeek) / 7 * Double(n)
            done += Double(count(h, from: start, to: end))
        }
        return possible == 0 ? 0 : min(done / possible, 1)
    }

    static func perfectDays(_ hs: [Habit], inMonthOf date: Date) -> Int {
        let daily = hs.filter { $0.targetPerWeek >= 7 }
        guard !daily.isEmpty, let range = cal.range(of: .day, in: .month, for: date),
              let first = cal.date(from: cal.dateComponents([.year, .month], from: date)) else { return 0 }
        let today = cal.startOfDay(for: .now)
        var n = 0
        for i in range {
            guard let d = cal.date(byAdding: .day, value: i - 1, to: first), d <= today else { continue }
            if daily.allSatisfy({ $0.isDone(d) }) { n += 1 }
        }
        return n
    }

    static func ratio(_ hs: [Habit], on d: Date) -> Double {
        guard !hs.isEmpty else { return 0 }
        return Double(hs.filter { $0.isDone(d) }.count) / Double(hs.count)
    }

    static func bestLift(_ hs: [Habit], days: Int = 60) -> (habit: Habit, lift: Double)? {
        guard hs.count >= 2 else { return nil }
        let today = cal.startOfDay(for: .now)
        var best: (Habit, Double)?
        for h in hs {
            let others = hs.filter { $0 !== h }
            var withSum = 0.0, withN = 0.0, withoutSum = 0.0, withoutN = 0.0
            for i in 0..<days {
                guard let d = cal.date(byAdding: .day, value: -i, to: today) else { continue }
                let r = Double(others.filter { $0.isDone(d) }.count) / Double(others.count)
                if h.isDone(d) { withSum += r; withN += 1 } else { withoutSum += r; withoutN += 1 }
            }
            guard withN >= 6, withoutN >= 6 else { continue }
            let lift = withSum / withN - withoutSum / withoutN
            if lift > 0.05, lift > (best?.1 ?? 0) { best = (h, lift) }
        }
        return best.map { (habit: $0.0, lift: $0.1) }
    }
}

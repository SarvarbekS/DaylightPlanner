import SwiftData
import Foundation
import SwiftUI

enum Section: String, CaseIterable, Identifiable {
    case calendar = "Calendar", reminders = "Reminders", todo = "To-do List",
         goals = "Goals", habits = "Discipline Tracker"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .calendar: "calendar"
        case .reminders: "bell"
        case .todo: "checkmark.circle"
        case .goals: "target"
        case .habits: "chart.bar.xaxis"
        }
    }
}

enum RepeatRule: String, CaseIterable, Identifiable {
    case none, daily, weekdays, weekly, biweekly, monthly, yearly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: "Does not repeat"
        case .daily: "Every day"
        case .weekdays: "Every weekday"
        case .weekly: "Every week"
        case .biweekly: "Every 2 weeks"
        case .monthly: "Every month"
        case .yearly: "Every year"
        }
    }
}

enum Importance: Int, CaseIterable, Identifiable {
    case low = 0, normal, high, critical
    var id: Int { rawValue }
    var label: String { ["Low", "Normal", "High", "Critical"][rawValue] }
}

@Model final class Event {
    var title: String
    var start: Date
    var end: Date
    var place: String?
    var colorKey: String
    var repeatRaw: String = "none"
    var repeatUntil: Date? = nil
    var importanceRaw: Int = 1

    var repeatRule: RepeatRule {
        get { RepeatRule(rawValue: repeatRaw) ?? .none }
        set { repeatRaw = newValue.rawValue }
    }
    var importance: Importance {
        get { Importance(rawValue: importanceRaw) ?? .normal }
        set { importanceRaw = newValue.rawValue }
    }

    init(title: String, start: Date, end: Date, place: String? = nil, colorKey: String = "lilac",
         repeatRule: RepeatRule = .none, repeatUntil: Date? = nil, importance: Importance = .normal) {
        self.title = title; self.start = start; self.end = end
        self.place = place; self.colorKey = colorKey
        self.repeatRaw = repeatRule.rawValue; self.repeatUntil = repeatUntil
        self.importanceRaw = importance.rawValue
    }
}

@Model final class Reminder {
    var title: String
    var due: Date?
    var list: String
    var done = false
    var flagged = false
    var priority: Int = 0          // 0 none, 1 low, 2 medium, 3 high
    var durationMinutes: Int = 0
    var note: String = ""
    var completedAt: Date? = nil

    init(title: String, due: Date? = nil, list: String = "Personal", note: String = "",
         priority: Int = 0, durationMinutes: Int = 0, flagged: Bool = false) {
        self.title = title
        self.due = due
        self.list = list
        self.note = note
        self.priority = priority
        self.durationMinutes = durationMinutes
        self.flagged = flagged
    }
}

@Model final class TaskItem {
    var title: String; var project: String; var minutes: Int
    var priority: Int; var due: Date?; var done = false
    init(title: String, project: String, minutes: Int, priority: Int = 1, due: Date? = nil) {
        self.title = title; self.project = project; self.minutes = minutes
        self.priority = priority; self.due = due
    }
}

enum GoalCategory: String, CaseIterable, Identifiable {
    case wellbeing, creative, financial, learning, career, relationships
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .wellbeing: return "figure.run"
        case .creative: return "pencil.and.outline"
        case .financial: return "banknote"
        case .learning: return "book"
        case .career: return "briefcase"
        case .relationships: return "heart"
        }
    }
    var colorKey: String {
        switch self {
        case .wellbeing: return "green"
        case .creative: return "lilac"
        case .financial: return "blue"
        case .learning: return "peach"
        case .career: return "yellow"
        case .relationships: return "rose"
        }
    }
    var dot: Color { paletteDot(colorKey) }
    var tint: Color { paletteTint(colorKey) }
}

enum GoalStatus: String { case active, completed, archived }
enum GoalPace { case onTrack, behind, done }

@Model final class Goal {
    var title: String
    var category: String
    var current: Double
    var target: Double
    var unit: String
    var deadline: Date
    var detail: String = ""
    var nextAction: String = ""
    var nextActionDate: Date? = nil
    var statusRaw: String = "active"
    var year: Int = 0
    var createdAt: Date = Date()
    var completedAt: Date? = nil
    @Relationship(deleteRule: .cascade) var milestones: [Milestone] = []

    init(title: String, category: String, current: Double, target: Double, unit: String, deadline: Date) {
        self.title = title
        self.category = category
        self.current = current
        self.target = target
        self.unit = unit
        self.deadline = deadline
        self.year = Calendar.current.component(.year, from: Date())
    }

    var cat: GoalCategory {
        get { GoalCategory(rawValue: category) ?? .wellbeing }
        set { category = newValue.rawValue }
    }
    var status: GoalStatus {
        get { GoalStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }
    var progress: Double {
        if status == .completed { return 1 }
        return target <= 0 ? 0 : min(max(current / target, 0), 1)
    }
    var sortedMilestones: [Milestone] {
        milestones.sorted { $0.order < $1.order }
    }

    var pace: GoalPace {
        if status == .completed || progress >= 1 { return .done }
        let total = deadline.timeIntervalSince(createdAt)
        guard total > 0 else { return .behind }
        let expected = min(max(Date().timeIntervalSince(createdAt) / total, 0), 1)
        return progress >= expected - 0.08 ? .onTrack : .behind
    }

    var perWeekNeeded: Double? {
        let remaining = target - current
        let weeks = deadline.timeIntervalSince(Date()) / (7 * 86400)
        guard remaining > 0, weeks > 0.1 else { return nil }
        return remaining / weeks
    }

    @discardableResult
    func log(_ amount: Double) -> Bool {
        current = max(0, current + amount)
        if status == .active && target > 0 && current >= target {
            complete()
            return true
        }
        return false
    }

    func complete() {
        status = .completed
        completedAt = .now
    }
}

@Model final class Milestone {
    var title: String
    var done = false
    var date: Date?
    var completedAt: Date? = nil
    var order: Int = 0

    init(title: String, date: Date? = nil) {
        self.title = title
        self.date = date
    }

    func toggle() {
        done.toggle()
        completedAt = done ? .now : nil
    }
}

@Model final class Habit {
    var name: String
    var detail: String
    var icon: String
    var colorKey: String
    var completedDays: [Date] = []
    var targetPerWeek: Int = 7
    var createdAt: Date = Date()
    var order: Int = 0
    var archived: Bool = false

    init(name: String, detail: String = "", icon: String = "figure.walk",
         colorKey: String = "green", targetPerWeek: Int = 7) {
        self.name = name
        self.detail = detail
        self.icon = icon
        self.colorKey = colorKey
        self.targetPerWeek = targetPerWeek
    }

    func isDone(_ d: Date) -> Bool {
        let cal = Calendar.current
        return completedDays.contains { cal.isDate($0, inSameDayAs: d) }
    }

    func toggle(_ d: Date) {
        let cal = Calendar.current
        if let i = completedDays.firstIndex(where: { cal.isDate($0, inSameDayAs: d) }) {
            completedDays.remove(at: i)
        } else {
            completedDays.append(cal.startOfDay(for: d))
        }
    }
}

@Model final class HabitNote {
    var weekStart: Date
    var text: String
    init(weekStart: Date, text: String) {
        self.weekStart = weekStart
        self.text = text
    }
}

@Model final class ReminderList {
    var name: String
    var colorKey: String
    var order: Int
    init(name: String, colorKey: String = "lilac", order: Int = 0) {
        self.name = name
        self.colorKey = colorKey
        self.order = order
    }
}

extension Reminder {
    func toggleDone() {
        done.toggle()
        completedAt = done ? .now : nil
    }
}

@Model final class TodoList {
    var name: String
    var colorKey: String
    var order: Int
    @Relationship(deleteRule: .cascade, inverse: \TodoItem.list) var items: [TodoItem] = []

    init(name: String, colorKey: String = "lilac", order: Int = 0) {
        self.name = name
        self.colorKey = colorKey
        self.order = order
    }
}

@Model final class TodoItem {
    var title: String
    var done: Bool = false
    var order: Int = 0
    var createdAt: Date = Date()
    var completedAt: Date? = nil
    var list: TodoList?

    init(title: String, order: Int = 0) {
        self.title = title
        self.order = order
    }

    func toggle() {
        done.toggle()
        completedAt = done ? .now : nil
    }
}

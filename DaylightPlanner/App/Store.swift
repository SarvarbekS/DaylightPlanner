import SwiftData
import Foundation

enum Store {
    static let container: ModelContainer = {
        try! ModelContainer(for: Event.self, Reminder.self, TaskItem.self,
                            Goal.self, Milestone.self, Habit.self, ReminderList.self,
                            TodoList.self, TodoItem.self, HabitNote.self)
    }()
}

extension Notification.Name {
    static let eventAdded = Notification.Name("dl.eventAdded")
}

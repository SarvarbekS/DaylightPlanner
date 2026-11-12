import SwiftUI
import SwiftData

struct ReminderSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ReminderList.order) private var lists: [ReminderList]
    let editing: Reminder?

    @State private var title: String
    @State private var note: String
    @State private var hasDue: Bool
    @State private var due: Date
    @State private var list: String
    @State private var priority: Int
    @State private var duration: Int
    @State private var flagged: Bool

    init(editing: Reminder?, defaultList: String) {
        self.editing = editing
        let nextHour = Calendar.current.date(
            bySettingHour: min(Calendar.current.component(.hour, from: .now) + 1, 23),
            minute: 0, second: 0, of: .now) ?? .now
        _title = State(initialValue: editing?.title ?? "")
        _note = State(initialValue: editing?.note ?? "")
        _hasDue = State(initialValue: editing == nil ? true : editing?.due != nil)
        _due = State(initialValue: editing?.due ?? nextHour)
        _list = State(initialValue: editing?.list ?? defaultList)
        _priority = State(initialValue: editing?.priority ?? 0)
        _duration = State(initialValue: editing?.durationMinutes ?? 0)
        _flagged = State(initialValue: editing?.flagged ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(editing == nil ? "New reminder" : "Edit reminder")
                .font(.system(size: 20, weight: .bold))

            TextField("Title", text: $title).textFieldStyle(.roundedBorder)
            TextField("Context (e.g. When leaving the office)", text: $note)
                .textFieldStyle(.roundedBorder)

            Toggle("Due date", isOn: $hasDue)
            if hasDue { DatePicker("Due", selection: $due) }

            Picker("List", selection: $list) {
                ForEach(lists) { Text($0.name).tag($0.name) }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Priority")
                Picker("", selection: $priority) {
                    Text("None").tag(0)
                    Text("Low").tag(1)
                    Text("Medium").tag(2)
                    Text("High").tag(3)
                }
                .pickerStyle(.segmented).labelsHidden()
            }

            Picker("Estimated time", selection: $duration) {
                Text("None").tag(0)
                ForEach([15, 30, 45, 60, 90], id: \.self) { Text("\($0) min").tag($0) }
            }

            Toggle("Flagged", isOn: $flagged)

            HStack {
                if let editing {
                    Button("Delete", role: .destructive) { ctx.delete(editing); dismiss() }
                }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
        .foregroundStyle(Color.dlText)
    }

    private func save() {
        let dueValue: Date? = hasDue ? due : nil
        if let r = editing {
            r.title = title; r.note = note; r.due = dueValue; r.list = list
            r.priority = priority; r.durationMinutes = duration; r.flagged = flagged
        } else {
            ctx.insert(Reminder(title: title, due: dueValue, list: list, note: note,
                                priority: priority, durationMinutes: duration, flagged: flagged))
        }
        dismiss()
    }
}

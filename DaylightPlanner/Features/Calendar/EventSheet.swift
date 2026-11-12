import SwiftUI
import SwiftData

struct EventSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let editing: Event?

    @State private var title: String
    @State private var place: String
    @State private var start: Date
    @State private var end: Date
    @State private var colorKey: String
    @State private var rule: RepeatRule
    @State private var hasEnd: Bool
    @State private var until: Date
    @State private var importance: Importance

    init(start: Date, end: Date, editing: Event?) {
        self.editing = editing
        if let e = editing {
            _title = State(initialValue: e.title)
            _place = State(initialValue: e.place ?? "")
            _start = State(initialValue: e.start)
            _end = State(initialValue: e.end)
            _colorKey = State(initialValue: e.colorKey)
            _rule = State(initialValue: e.repeatRule)
            _hasEnd = State(initialValue: e.repeatUntil != nil)
            _until = State(initialValue: e.repeatUntil ?? e.start.addingTimeInterval(86400 * 90))
            _importance = State(initialValue: e.importance)
        } else {
            _title = State(initialValue: "")
            _place = State(initialValue: "")
            _start = State(initialValue: start)
            _end = State(initialValue: end)
            _colorKey = State(initialValue: "lilac")
            _rule = State(initialValue: .none)
            _hasEnd = State(initialValue: false)
            _until = State(initialValue: start.addingTimeInterval(86400 * 90))
            _importance = State(initialValue: .normal)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(editing == nil ? "New event" : "Edit event")
                .font(.system(size: 20, weight: .bold))

            TextField("Title", text: $title).textFieldStyle(.roundedBorder)
            TextField("Place or note (optional)", text: $place).textFieldStyle(.roundedBorder)

            DatePicker("Starts", selection: $start)
            DatePicker("Ends", selection: $end, in: start...)

            Picker("Repeat", selection: $rule) {
                ForEach(RepeatRule.allCases) { Text($0.label).tag($0) }
            }
            if rule != .none {
                Toggle("Stop repeating on a date", isOn: $hasEnd)
                if hasEnd { DatePicker("Until", selection: $until, in: start..., displayedComponents: .date) }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Importance")
                Picker("", selection: $importance) {
                    ForEach(Importance.allCases) { Text($0.label).tag($0) }
                }.pickerStyle(.segmented).labelsHidden()
                Text("More important events will send more reminders (coming soon).")
                    .font(.caption).foregroundStyle(Color.dlMuted)
            }

            HStack(spacing: 10) {
                Text("Color")
                ForEach(eventColorKeys, id: \.self) { k in
                    let probe = Event(title: "", start: .now, end: .now, colorKey: k)
                    Circle().fill(probe.dot).frame(width: 22, height: 22)
                        .overlay(Circle().stroke(Color.dlInk, lineWidth: colorKey == k ? 2 : 0).padding(-3))
                        .onTapGesture { colorKey = k }
                }
            }

            if editing != nil && rule != .none {
                Text("Changes apply to the whole series.").font(.caption).foregroundStyle(Color.dlMuted)
            }

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
        .padding(24).frame(width: 440)
        .foregroundStyle(Color.dlText)
        .onChange(of: start) { old, new in end = end.addingTimeInterval(new.timeIntervalSince(old)) }
    }

    private func save() {
        let finalEnd = max(end, start)
        let untilDate: Date? = (rule != .none && hasEnd) ? until : nil
        let placeValue = place.isEmpty ? nil : place
        if let e = editing {
            e.title = title; e.place = placeValue; e.start = start; e.end = finalEnd
            e.colorKey = colorKey; e.repeatRule = rule; e.repeatUntil = untilDate
            e.importance = importance
        } else {
            ctx.insert(Event(title: title, start: start, end: finalEnd, place: placeValue,
                             colorKey: colorKey, repeatRule: rule, repeatUntil: untilDate,
                             importance: importance))
        }
        dismiss()
    }
}

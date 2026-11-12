import SwiftUI
import SwiftData

enum CalMode: String, CaseIterable { case month = "Month", week = "Week", day = "Day" }

enum SheetKind: Identifiable {
    case new(Date, Date)
    case edit(Event)
    var id: String {
        switch self {
        case .new: "new"
        case .edit(let e): "edit-\(e.persistentModelID.hashValue)"
        }
    }
}

struct CalendarView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Event.start) private var events: [Event]
    @Query private var allReminders: [Reminder]
    @Query(sort: \ReminderList.order) private var reminderLists: [ReminderList]
    @State private var reminderSheet: Reminder?

    @State private var mode: CalMode = .month
    @State private var anchor = Date()
    @State private var selected = Date()
    @State private var sheet: SheetKind?

    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.firstWeekday = 2; return c }

    private func occ(on d: Date) -> [Occurrence] {
        let s = cal.startOfDay(for: d)
        let e = cal.date(byAdding: .day, value: 1, to: s)!
        return events.flatMap { $0.occurrences(from: s, to: e, cal: cal) }.sorted { $0.start < $1.start }
    }
    
    private func reminders(on d: Date) -> [Reminder] {
        allReminders
            .filter { r in
                guard let due = r.due else { return false }
                return cal.isDate(due, inSameDayAs: d)
            }
            .sorted { $0.due! < $1.due! }
    }

    private func reminderColor(_ r: Reminder) -> Color {
        colors(for: r.list, in: reminderLists).dot
    }
    
    private func defaultSlot(on day: Date) -> (Date, Date) {
        let s = cal.date(bySettingHour: 10, minute: 0, second: 0, of: day) ?? day
        return (s, s.addingTimeInterval(3600))
    }

    private func reschedule(_ o: Occurrence, newStart: Date, newEnd: Date) {
        let e = o.event
        e.start = e.start.addingTimeInterval(newStart.timeIntervalSince(o.start))
        e.end = e.end.addingTimeInterval(newEnd.timeIntervalSince(o.end))
        if e.end <= e.start { e.end = e.start.addingTimeInterval(900) }
    }

    private var weekDays: [Date] {
        let w = cal.dateInterval(of: .weekOfYear, for: anchor)!
        return (0..<7).map { cal.date(byAdding: .day, value: $0, to: w.start)! }
    }

    private var monthWeeks: [[Date]] {
        let m = cal.dateInterval(of: .month, for: anchor)!
        let start = cal.dateInterval(of: .weekOfYear, for: m.start)!.start
        let end = cal.dateInterval(of: .weekOfYear, for: m.end.addingTimeInterval(-1))!.end
        var days: [Date] = []; var d = start
        while d < end { days.append(d); d = cal.date(byAdding: .day, value: 1, to: d)! }
        return stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
    }

    private var weekTitle: String {
        let d = weekDays
        let a = d.first!.formatted(.dateTime.month(.abbreviated).day())
        let b = d.last!.formatted(.dateTime.month(.abbreviated).day().year())
        return "\(a) – \(b)"
    }

    private var title: String {
        switch mode {
        case .month: return anchor.formatted(.dateTime.month(.wide).year())
        case .week:  return weekTitle
        case .day:   return anchor.formatted(.dateTime.weekday(.wide).month().day())
        }
    }

    private func step(_ n: Int) {
        let comp: Calendar.Component = mode == .month ? .month : (mode == .week ? .weekOfYear : .day)
        anchor = cal.date(byAdding: comp, value: n, to: anchor)!
        if mode == .day { selected = anchor }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeader(title: "Calendar",
                       subtitle: "Shape your month, protect your focus, and leave room to breathe.") {
                PrimaryButton(title: "New event") {
                    let slot = defaultSlot(on: selected)
                    sheet = .new(slot.0, slot.1)
                }
            }
            toolbar
            HStack(alignment: .top, spacing: 20) {
                switch mode {
                case .month:
                    monthGrid
                case .week:
                    TimeGrid(days: weekDays, selected: selected,
                             occurrences: { occ(on: $0) },
                             onSelect: { selected = $0 },
                             onOpen: { sheet = .edit($0) },
                             onCreate: { s, e in selected = s; sheet = .new(s, e) },
                             onReschedule: { o, s, e in reschedule(o, newStart: s, newEnd: e) },
                             reminders: { reminders(on: $0) },
                             reminderColor: { reminderColor($0) },
                             onOpenReminder: { reminderSheet = $0 })
                case .day:
                    TimeGrid(days: [anchor], selected: anchor,
                             occurrences: { occ(on: $0) },
                             onSelect: { selected = $0 },
                             onOpen: { sheet = .edit($0) },
                             onCreate: { s, e in selected = s; sheet = .new(s, e) },
                             onReschedule: { o, s, e in reschedule(o, newStart: s, newEnd: e) },
                             reminders: { reminders(on: $0) },
                             reminderColor: { reminderColor($0) },
                             onOpenReminder: { reminderSheet = $0 })
                }
                DayPanel(date: selected, occs: occ(on: selected),
                         reminders: reminders(on: selected),
                         reminderColor: { reminderColor($0) },
                         onOpen: { sheet = .edit($0) },
                         onOpenReminder: { reminderSheet = $0 },
                         onDelete: { ctx.delete($0) })
                    .frame(width: 320)
            }
        }
        .padding(32)
        .sheet(item: $sheet) { kind in
            switch kind {
            case .new(let s, let e): EventSheet(start: s, end: e, editing: nil)
            case .edit(let ev): EventSheet(start: ev.start, end: ev.end, editing: ev)
            }
        }
        .sheet(item: $reminderSheet) { r in
            ReminderSheet(editing: r, defaultList: r.list)
        }
        .task { seedIfNeeded() }
        .onReceive(NotificationCenter.default.publisher(for: .eventAdded)) { n in
            if let d = n.object as? Date { anchor = d; selected = d }
        }
    }

    private var toolbar: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(CalMode.allCases, id: \.self) { m in
                    Button {
                        mode = m
                        anchor = selected
                    } label: {
                        Text(m.rawValue).font(.system(size: 13))
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(mode == m ? Color.white : .clear, in: RoundedRectangle(cornerRadius: 10))
                            .shadow(color: .black.opacity(mode == m ? 0.06 : 0), radius: 3, y: 1)
                    }.buttonStyle(.plain)
                }
            }
            .padding(4).background(Color.dlLine.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
            Spacer()
            Button("Today") { anchor = .now; selected = .now }
                .buttonStyle(.plain).padding(.horizontal, 14).padding(.vertical, 8)
                .background(.white, in: RoundedRectangle(cornerRadius: 10))
            navButton("chevron.left") { step(-1) }
            Text(title).font(.system(size: 18, weight: .semibold)).frame(minWidth: 200)
            navButton("chevron.right") { step(1) }
        }
    }

    private func navButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(.white, in: RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain)
    }

    private var monthGrid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(["MON","TUE","WED","THU","FRI","SAT","SUN"], id: \.self) {
                    Text($0).font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.dlMuted).frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 6)
                }
            }
            ForEach(monthWeeks, id: \.first) { week in
                HStack(spacing: 8) {
                    ForEach(week, id: \.self) { d in
                        DayCell(date: d,
                                inMonth: cal.isDate(d, equalTo: anchor, toGranularity: .month),
                                isToday: cal.isDateInToday(d),
                                isSelected: cal.isDate(d, inSameDayAs: selected),
                                occs: occ(on: d),
                                reminders: reminders(on: d),
                                reminderColor: { reminderColor($0) })
                        .onTapGesture(count: 2) {
                            let slot = defaultSlot(on: d)
                            selected = d
                            sheet = .new(slot.0, slot.1)
                        }
                        .onTapGesture { selected = d }
                    }
                }
            }
        }
        .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 24))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func seedIfNeeded() {
        guard events.isEmpty else { return }
        let now = Date()
        func make(_ title: String, _ dayOffset: Int, _ h: Int, _ m: Int, _ mins: Int,
                  _ place: String?, _ color: String, _ rule: RepeatRule = .none,
                  _ imp: Importance = .normal) {
            let day = cal.date(byAdding: .day, value: dayOffset, to: now)!
            let s = cal.date(bySettingHour: h, minute: m, second: 0, of: day)!
            ctx.insert(Event(title: title, start: s, end: s.addingTimeInterval(Double(mins) * 60),
                             place: place, colorKey: color, repeatRule: rule, importance: imp))
        }
        make("Design sync", 0, 10, 0, 45, "Studio", "peach", .weekly, .high)
        make("Deep work block", 0, 11, 30, 90, "Launch narrative", "lilac", .weekdays)
        make("Review roadmap", 0, 14, 0, 60, "With product team", "blue", .none, .critical)
        make("Pilates", 0, 17, 30, 60, "Westside studio", "green", .weekly)
        make("Weekly reset", 1, 9, 0, 30, nil, "yellow", .weekly)
        make("1:1 with Maya", 2, 15, 0, 30, nil, "rose")
        make("Standup", 0, 10, 15, 30, nil, "blue", .weekdays)
    }
}

// MARK: - Month cell
struct DayCell: View {
    let date: Date, inMonth: Bool, isToday: Bool, isSelected: Bool
    let occs: [Occurrence]
    let reminders: [Reminder]
    let reminderColor: (Reminder) -> Color
    private var cal: Calendar { Calendar.current }

    var body: some View {
        let slots = 2
        let shownEvents = Array(occs.prefix(slots))
        let shownReminders = Array(reminders.prefix(max(slots - shownEvents.count, 0)))
        let extra = occs.count + reminders.count - shownEvents.count - shownReminders.count

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(cal.component(.day, from: date))")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 24, height: 24)
                    .background(isToday ? Color.dlAccent : (inMonth ? Color.white : .clear), in: Circle())
                    .foregroundStyle(isToday ? .white : (inMonth ? Color.dlText : Color.dlMuted.opacity(0.6)))
                Spacer()
                if isToday { Text("TODAY").font(.system(size: 9, weight: .bold)).foregroundStyle(Color.dlAccent) }
            }
            ForEach(shownEvents) { o in
                HStack(spacing: 3) {
                    Text(o.event.title).lineLimit(1)
                    Spacer(minLength: 0)
                    if o.event.importance.rawValue >= 2 {
                        Image(systemName: "exclamationmark.circle.fill").font(.system(size: 9))
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(o.event.tint, in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(Color.dlText.opacity(0.75))
            }
            ForEach(shownReminders) { r in
                HStack(spacing: 4) {
                    Image(systemName: r.done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 9)).foregroundStyle(reminderColor(r))
                    Text(r.title).lineLimit(1).strikethrough(r.done)
                    Spacer(minLength: 0)
                }
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.dlLine, lineWidth: 1))
                .foregroundStyle(r.done ? Color.dlMuted : Color.dlText.opacity(0.75))
            }
            if extra > 0 {
                Text("+\(extra) more").font(.system(size: 10)).foregroundStyle(Color.dlMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(minHeight: 96)
        .background(inMonth ? Color.dlBg : Color.dlBg.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.dlAccent, lineWidth: isSelected ? 2 : 0))
        .contentShape(Rectangle())
    }
}

struct DayPanel: View {
    let date: Date
    let occs: [Occurrence]
    let reminders: [Reminder]
    let reminderColor: (Reminder) -> Color
    var onOpen: (Event) -> Void
    var onOpenReminder: (Reminder) -> Void
    var onDelete: (Event) -> Void

    private var focused: String {
        let m = occs.reduce(0) { $0 + $1.minutes }
        return "\(m / 60)h \(m % 60)m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.system(size: 22, weight: .bold))
            Text("\(occs.count) plans · \(reminders.count) reminders · \(focused) focused")
                .font(.system(size: 12)).foregroundStyle(Color.dlMuted)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(occs) { o in
                        HStack(alignment: .top, spacing: 14) {
                            VStack(spacing: 6) {
                                Text(o.start.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute()))
                                    .font(.system(size: 12, weight: .medium))
                                Circle().fill(o.event.dot).frame(width: 6, height: 6)
                            }.frame(width: 44)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 4) {
                                    Text(o.event.title).font(.system(size: 14, weight: .medium))
                                    if o.event.repeatRule != .none {
                                        Image(systemName: "repeat").font(.system(size: 10)).foregroundStyle(Color.dlMuted)
                                    }
                                    if o.event.importance.rawValue >= 2 {
                                        Image(systemName: "exclamationmark.circle.fill").font(.system(size: 11))
                                            .foregroundStyle(o.event.importance == .critical ? Color.red : o.event.dot)
                                    }
                                }
                                Text([o.event.place, "\(o.minutes) min"].compactMap { $0 }.joined(separator: " · "))
                                    .font(.system(size: 11)).foregroundStyle(Color.dlMuted)
                            }
                            Spacer()
                        }
                        .padding(12).background(Color.dlBg, in: RoundedRectangle(cornerRadius: 14))
                        .contentShape(Rectangle())
                        .onTapGesture { onOpen(o.event) }
                        .contextMenu {
                            Button("Edit") { onOpen(o.event) }
                            Button("Delete\(o.event.repeatRule != .none ? " series" : "")", role: .destructive) {
                                onDelete(o.event)
                            }
                        }
                    }

                    if !reminders.isEmpty {
                        Text("REMINDERS · \(reminders.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(hex: 0xE08A5E))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 6)
                        ForEach(reminders) { r in
                            HStack(spacing: 6) {
                                Button { withAnimation(.snappy) { r.toggleDone() } } label: {
                                    Image(systemName: r.done ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 16))
                                        .foregroundStyle(reminderColor(r))
                                        .frame(width: 30, height: 30)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                HStack {
                                    Text(r.title)
                                        .font(.system(size: 13, weight: .medium))
                                        .strikethrough(r.done)
                                        .foregroundStyle(r.done ? Color.dlMuted : Color.dlText)
                                        .lineLimit(2)
                                    Spacer(minLength: 0)
                                    if let d = r.due {
                                        Text(d.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute()))
                                            .font(.system(size: 11)).foregroundStyle(Color.dlMuted)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { onOpenReminder(r) }
                            }
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Color.dlBg, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }

                    if occs.isEmpty && reminders.isEmpty {
                        Text("Nothing planned. Enjoy the space.")
                            .font(.system(size: 13)).foregroundStyle(Color.dlMuted).padding(.top, 20)
                    }
                    nudge
                }
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
    }

    private var nudge: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Gentle nudge", systemImage: "sparkles")
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.dlAccent)
            Text("You have a quiet 90-minute window after lunch, ideal for deep work.")
                .font(.system(size: 12)).foregroundStyle(Color.dlMuted)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dlLilac.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
        .padding(.top, 6)
    }
}

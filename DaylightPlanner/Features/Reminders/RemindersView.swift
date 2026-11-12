import SwiftUI
import SwiftData

enum SmartList: String, CaseIterable, Identifiable {
    case inbox = "Inbox", today = "Today", scheduled = "Scheduled",
         flagged = "Flagged", completed = "Completed"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .inbox: return "tray"
        case .today: return "sun.max"
        case .scheduled: return "calendar.badge.clock"
        case .flagged: return "flag"
        case .completed: return "checkmark.circle"
        }
    }
}

enum ReminderFilter: Hashable {
    case smart(SmartList)
    case list(String)
}

enum ReminderSort: String, CaseIterable {
    case due = "Due date", priority = "Priority", title = "Title"
}

enum ReminderSheetKind: Identifiable {
    case new
    case edit(Reminder)
    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let r): return "edit-\(r.persistentModelID.hashValue)"
        }
    }
}

struct ReminderGroup: Identifiable {
    let id: String
    let title: String
    let tone: Color
    let items: [Reminder]
}

struct RemindersView: View {
    @Environment(\.modelContext) private var ctx
    @Query private var all: [Reminder]
    @Query(sort: \ReminderList.order) private var lists: [ReminderList]

    @State private var filter: ReminderFilter = .smart(.inbox)
    @State private var sort: ReminderSort = .due
    @State private var sheet: ReminderSheetKind?
    @State private var listSheet: ListSheetKind?
    @State private var pendingDelete: ReminderList?
    @State private var quickText = ""

    private var cal: Calendar { Calendar.current }
    private let orange = Color(hex: 0xE08A5E)

    private func listColors(_ name: String) -> (dot: Color, tint: Color) {
        colors(for: name, in: lists)
    }

    private var defaultListName: String {
        if case .list(let n) = filter { return n }
        return lists.first?.name ?? "Personal"
    }

    // MARK: filtering
    private func matches(_ r: Reminder, _ f: ReminderFilter) -> Bool {
        switch f {
        case .smart(let s):
            switch s {
            case .inbox: return !r.done
            case .today:
                guard !r.done, let d = r.due else { return false }
                return cal.startOfDay(for: d) <= cal.startOfDay(for: .now)
            case .scheduled: return !r.done && r.due != nil
            case .flagged: return !r.done && r.flagged
            case .completed: return r.done
            }
        case .list(let name):
            return !r.done && r.list == name
        }
    }

    private func count(_ f: ReminderFilter) -> Int { all.filter { matches($0, f) }.count }

    private func sorted(_ rs: [Reminder]) -> [Reminder] {
        switch sort {
        case .due:
            return rs.sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
        case .priority:
            return rs.sorted {
                $0.priority != $1.priority
                    ? $0.priority > $1.priority
                    : ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture)
            }
        case .title:
            return rs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    private var groups: [ReminderGroup] {
        let items = sorted(all.filter { matches($0, filter) })

        if case .smart(.completed) = filter {
            let done = items.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            return done.isEmpty ? [] : [ReminderGroup(id: "done", title: "COMPLETED", tone: Color.dlMuted, items: done)]
        }

        let startToday = cal.startOfDay(for: .now)
        let startTomorrow = cal.date(byAdding: .day, value: 1, to: startToday)!

        let overdue = items.filter { ($0.due ?? .distantFuture) < startToday }
        let today = items.filter {
            guard let d = $0.due else { return false }
            return d >= startToday && d < startTomorrow
        }
        let upcoming = items.filter { ($0.due ?? .distantPast) >= startTomorrow }
        let undated = items.filter { $0.due == nil }

        var out: [ReminderGroup] = []
        if !overdue.isEmpty { out.append(ReminderGroup(id: "overdue", title: "OVERDUE", tone: Color(hex: 0xD9788A), items: overdue)) }
        if !today.isEmpty { out.append(ReminderGroup(id: "today", title: "TODAY", tone: orange, items: today)) }
        if !upcoming.isEmpty { out.append(ReminderGroup(id: "upcoming", title: "UPCOMING", tone: orange, items: upcoming)) }
        if !undated.isEmpty { out.append(ReminderGroup(id: "undated", title: "NO DATE", tone: Color.dlAccent, items: undated)) }
        return out
    }

    private var title: String {
        switch filter {
        case .smart(let s): return s.rawValue
        case .list(let n): return n
        }
    }

    private var subtitle: String {
        let n = count(filter)
        switch filter {
        case .smart(.inbox): return "\(n) reminders waiting to be sorted"
        case .smart(.today): return "\(n) due today or overdue"
        case .smart(.scheduled): return "\(n) with a date"
        case .smart(.flagged): return "\(n) flagged"
        case .smart(.completed): return "\(n) finished"
        case .list(let name): return "\(n) open in \(name)"
        }
    }

    // MARK: stats
    private var dueToday: [Reminder] {
        all.filter { r in
            guard !r.done, let d = r.due else { return false }
            return cal.isDateInToday(d)
        }
    }
    private var beforeNoon: Int {
        dueToday.filter { cal.component(.hour, from: $0.due!) < 12 }.count
    }
    private var scheduledNext7: Int {
        let end = cal.date(byAdding: .day, value: 7, to: .now)!
        return all.filter { r in
            guard !r.done, let d = r.due else { return false }
            return d >= cal.startOfDay(for: .now) && d <= end
        }.count
    }
    private var completedThisMonth: Int {
        all.filter { r in
            guard r.done, let c = r.completedAt else { return false }
            return cal.isDate(c, equalTo: .now, toGranularity: .month)
        }.count
    }
    private var nextUp: [Reminder] {
        all.filter { !$0.done && ($0.due ?? .distantPast) >= .now }
            .sorted { $0.due! < $1.due! }
            .prefix(4).map { $0 }
    }

    // MARK: body
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeader(title: "Reminders",
                       subtitle: "Keep every promise visible, timely, and easy to act on.") {
                PrimaryButton(title: "New reminder") { sheet = .new }
            }

            HStack(spacing: 20) {
                StatCard(icon: "bell", tint: Color.dlPeach, fg: Color(hex: 0xE08A5E),
                         label: "Due today", value: dueToday.count, caption: "\(beforeNoon) before noon")
                StatCard(icon: "calendar.badge.clock", tint: Color.dlBlue, fg: Color(hex: 0x7BA3D6),
                         label: "Scheduled", value: scheduledNext7, caption: "Next 7 days")
                StatCard(icon: "checkmark.circle", tint: Color.dlGreen, fg: Color(hex: 0x7CC4A0),
                         label: "Completed", value: completedThisMonth, caption: "This month")
            }

            HStack(alignment: .top, spacing: 20) {
                listsPanel.frame(width: 230)
                centerPanel
                nextUpPanel.frame(width: 280)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(32)
        .sheet(item: $sheet) { kind in
            switch kind {
            case .new: ReminderSheet(editing: nil, defaultList: defaultListName)
            case .edit(let r): ReminderSheet(editing: r, defaultList: r.list)
            }
        }
        .sheet(item: $listSheet) { kind in
            switch kind {
            case .new:
                ListSheet(editing: nil)
            case .edit(let l):
                ListSheet(editing: l, onRenamed: { old, new in
                    if filter == .list(old) { filter = .list(new) }
                })
            }
        }
        .alert("Delete list?", isPresented: Binding(get: { pendingDelete != nil },
                                                    set: { if !$0 { pendingDelete = nil } }),
               presenting: pendingDelete) { l in
            Button("Delete", role: .destructive) {
                ListOps.delete(l, lists: lists, reminders: all, ctx: ctx)
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { l in
            let n = all.filter { $0.list == l.name }.count
            let target = lists.filter { $0 !== l }.sorted { $0.order < $1.order }.first?.name ?? ""
            Text("\(n) reminder\(n == 1 ? "" : "s") will move to \(target).")
        }
        .onChange(of: lists.map(\.name)) { _, names in
            if case .list(let n) = filter, !names.contains(n) { filter = .smart(.inbox) }
        }
        .task { seedIfNeeded() }
    }

    // MARK: left panel
    private var listsPanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 4) {
                sectionLabel("SMART LISTS")
                ForEach(SmartList.allCases) { s in smartRow(s) }

                HStack {
                    sectionLabel("MY LISTS")
                    Spacer()
                    Button { listSheet = .new } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.dlMuted)
                            .frame(width: 24, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("New list")
                }
                .padding(.top, 14)

                ForEach(lists) { l in
                    ListFilterRow(list: l,
                                  count: count(.list(l.name)),
                                  selected: filter == .list(l.name),
                                  canDelete: lists.count > 1,
                                  onSelect: { filter = .list(l.name) },
                                  onEdit: { listSheet = .edit(l) },
                                  onDelete: { pendingDelete = l })
                }
            }
            .padding(16)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
    }

    private func sectionLabel(_ s: String) -> some View {
        Text(s).font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.dlMuted).padding(.leading, 8).padding(.bottom, 4)
    }

    private func smartRow(_ s: SmartList) -> some View {
        let f = ReminderFilter.smart(s)
        let selected = filter == f
        return Button { filter = f } label: {
            HStack(spacing: 10) {
                Image(systemName: s.icon).frame(width: 20).foregroundStyle(Color.dlText.opacity(0.7))
                Text(s.rawValue).font(.system(size: 13))
                Spacer()
                Text("\(count(f))").font(.system(size: 11)).foregroundStyle(Color.dlMuted)
            }
            .padding(.horizontal, 10).padding(.vertical, 9)
            .background(selected ? Color.dlPeach : Color.clear, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: center panel
    private var centerPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 24, weight: .bold))
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(Color.dlMuted)
                }
                Spacer()
                Menu {
                    Picker("Sort by", selection: $sort) {
                        ForEach(ReminderSort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    Label(sort.rawValue, systemImage: "arrow.up.arrow.down")
                        .font(.system(size: 12))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.bottom, 10)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(groups) { g in
                        Text("\(g.title) · \(g.items.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(g.tone)
                            .padding(.top, 10).padding(.bottom, 6)
                        ForEach(g.items) { r in
                            ReminderRow(r: r, onEdit: { sheet = .edit(r) })
                            Divider()
                        }
                    }
                    if groups.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "leaf").font(.system(size: 26)).foregroundStyle(Color.dlMuted)
                            Text("All clear. Enjoy the space.").foregroundStyle(Color.dlMuted)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 50)
                    }
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "plus").foregroundStyle(Color.dlMuted)
                TextField("Add a reminder and press Return", text: $quickText)
                    .textFieldStyle(.plain)
                    .onSubmit(quickAdd)
            }
            .padding(12)
            .background(Color.dlBg, in: RoundedRectangle(cornerRadius: 12))
            .padding(.top, 10)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
    }

    private func quickAdd() {
        let t = quickText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        var due: Date? = nil
        var flagged = false
        switch filter {
        case .smart(.today):
            due = cal.date(bySettingHour: min(cal.component(.hour, from: .now) + 1, 23),
                           minute: 0, second: 0, of: .now)
        case .smart(.flagged): flagged = true
        default: break
        }
        ctx.insert(Reminder(title: t, due: due, list: defaultListName, flagged: flagged))
        quickText = ""
    }

    // MARK: right panel
    private var nextUpPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Next up").font(.system(size: 18, weight: .bold))
                Spacer()
                Image(systemName: "calendar").foregroundStyle(Color.dlBlue.opacity(0.9))
            }
            ForEach(nextUp) { r in
                let d = r.due!
                VStack(alignment: .leading, spacing: 4) {
                    Text(d.formatted(.dateTime.weekday(.abbreviated).day(.twoDigits)).uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.dlText.opacity(0.55))
                    Text(r.title).font(.system(size: 14, weight: .medium)).lineLimit(2)
                    Text(d.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute()))
                        .font(.system(size: 12)).foregroundStyle(Color.dlText.opacity(0.55))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(listColors(r.list).tint, in: RoundedRectangle(cornerRadius: 14))
                .contentShape(Rectangle())
                .onTapGesture { sheet = .edit(r) }
            }
            if nextUp.isEmpty {
                Text("Nothing coming up.").font(.system(size: 13)).foregroundStyle(Color.dlMuted)
            }
            Button { sheet = .new } label: {
                Label("Schedule reminder", systemImage: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.dlLine, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
    }

    // MARK: sample data
    private func seedIfNeeded() {
        guard all.isEmpty else { return }
        func at(_ days: Int, _ h: Int, _ m: Int = 0) -> Date {
            let d = cal.date(byAdding: .day, value: days, to: .now)!
            return cal.date(bySettingHour: h, minute: m, second: 0, of: d)!
        }
        func add(_ t: String, _ due: Date?, _ list: String, note: String = "", priority: Int = 0,
                 dur: Int = 0, flagged: Bool = false) {
            ctx.insert(Reminder(title: t, due: due, list: list, note: note,
                                priority: priority, durationMinutes: dur, flagged: flagged))
        }
        add("Send revised proposal to Nina", at(0, 10, 30), "Work", priority: 3)
        add("Book annual health check", at(0, 14), "Personal")
        add("Pick up oat milk and basil", nil, "Home", note: "When leaving the office")
        add("Call Mum", at(1, 11), "Personal", flagged: true)
        add("Renew library membership", at(2, 9), "Personal")
        add("Prepare quarterly reflection", at(3, 16, 30), "Work", dur: 30)
        add("Water the fiddle-leaf fig", at(5, 18), "Home")
        add("Plan a weekend trip", nil, "Someday")
        for i in 1...4 {
            let r = Reminder(title: "Finished task \(i)", due: at(-i, 9), list: "Personal")
            r.done = true
            r.completedAt = Date().addingTimeInterval(-86400 * Double(i))
            ctx.insert(r)
        }
    }
}

// MARK: - Stat card
struct StatCard: View {
    let icon: String
    let tint: Color
    let fg: Color
    let label: String
    let value: Int
    let caption: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(fg)
                .frame(width: 48, height: 48)
                .background(tint, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 13, weight: .medium))
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(value)").font(.system(size: 28))
                    Text(caption).font(.system(size: 11)).foregroundStyle(Color.dlMuted)
                }
            }
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
    }
}

// MARK: - Row
struct ReminderRow: View {
    @Environment(\.modelContext) private var ctx
    let r: Reminder
    var onEdit: () -> Void

    private var cal: Calendar { Calendar.current }
    private var overdue: Bool {
        guard !r.done, let d = r.due else { return false }
        return d < cal.startOfDay(for: .now)
    }

    private var subtitle: String {
        var parts: [String] = []
        if let d = r.due { parts.append(dueText(d)) }
        if !r.note.isEmpty { parts.append(r.note) }
        parts.append(r.list)
        return parts.joined(separator: " · ")
    }

    private func dueText(_ d: Date) -> String {
        let c = cal.dateComponents([.hour, .minute], from: d)
        let hasTime = !(c.hour == 0 && c.minute == 0)
        let t = d.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute())
        if cal.isDateInToday(d) { return hasTime ? "Today, \(t)" : "Today" }
        if cal.isDateInTomorrow(d) { return hasTime ? "Tomorrow, \(t)" : "Tomorrow" }
        let date = d.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        if d < cal.startOfDay(for: .now) { return "Overdue · " + date }
        return hasTime ? "\(date), \(t)" : date
    }

    var body: some View {
        HStack(spacing: 8) {
            Button { withAnimation(.snappy) { r.toggleDone() } } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(r.done ? Color(hex: 0x7CC4A0) : Color.clear)
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(r.done ? Color.clear : Color(hex: 0xCFCBDD), lineWidth: 1.5)
                    if r.done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 20, height: 20)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(r.title)
                        .font(.system(size: 14, weight: .medium))
                        .strikethrough(r.done)
                        .foregroundStyle(r.done ? Color.dlMuted : Color.dlText)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(overdue ? Color(hex: 0xD9788A) : Color.dlMuted)
                }
                Spacer(minLength: 0)

                if r.flagged {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: 0xE08A5E))
                }
                if r.priority > 0 { priorityChip }
                if r.durationMinutes > 0 {
                    chip("\(r.durationMinutes) min", fg: Color.dlMuted, bg: Color.dlBg)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)

            Menu {
                Button("Edit", action: onEdit)
                Button(r.flagged ? "Remove flag" : "Flag") { r.flagged.toggle() }
                Menu("Snooze") {
                    Button("In 1 hour") { snooze(hours: 1) }
                    Button("Tomorrow morning") { snoozeTomorrow() }
                    Button("Next week") { snooze(hours: 24 * 7) }
                }
                Divider()
                Button("Delete", role: .destructive) { ctx.delete(r) }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Color.dlMuted)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.vertical, 5)
    }

    @ViewBuilder private var priorityChip: some View {
        switch r.priority {
        case 3: chip("High", fg: Color(hex: 0xD9788A), bg: Color.dlRose)
        case 2: chip("Medium", fg: Color(hex: 0xB98A1E), bg: Color.dlYellow)
        default: chip("Low", fg: Color(hex: 0x4E9C78), bg: Color.dlGreen)
        }
    }

    private func chip(_ text: String, fg: Color, bg: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(fg)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(bg, in: RoundedRectangle(cornerRadius: 7))
    }

    private func snooze(hours: Int) {
        let base = max(r.due ?? .now, .now)
        r.due = base.addingTimeInterval(Double(hours) * 3600)
    }

    private func snoozeTomorrow() {
        let t = cal.date(byAdding: .day, value: 1, to: .now)!
        r.due = cal.date(bySettingHour: 9, minute: 0, second: 0, of: t)
    }
}

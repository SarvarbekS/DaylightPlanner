import SwiftUI
import SwiftData

enum HabitSheetKind: Identifiable {
    case new
    case edit(Habit)
    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let h): return "edit-\(h.persistentModelID.hashValue)"
        }
    }
}

// MARK: - Small components
struct MetricCard: View {
    let icon: String
    let tint: Color
    let fg: Color
    let label: String
    let value: String
    let caption: String
    var captionColor: Color = Color.dlMuted

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(fg)
                .frame(width: 46, height: 46)
                .background(tint, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 11)).foregroundStyle(Color.dlMuted)
                Text(value).font(.system(size: 22, weight: .semibold))
                Text(caption).font(.system(size: 11)).foregroundStyle(captionColor)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: 22))
    }
}

struct ConsistencyRing: View {
    let value: Double
    @State private var shown: Double = 0

    var body: some View {
        ZStack {
            Circle().stroke(Color.dlLine, lineWidth: 12)
            Circle()
                .trim(from: 0, to: shown)
                .stroke(Color(hex: 0x7CC4A0), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(Int(value * 100))%").font(.system(size: 30, weight: .semibold))
                Text("CONSISTENT").font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.dlMuted)
            }
        }
        .frame(width: 150, height: 150)
        .onAppear { withAnimation(.easeOut(duration: 1.0)) { shown = value } }
        .onChange(of: value) { _, v in withAnimation(.easeOut(duration: 0.6)) { shown = v } }
    }
}

// MARK: - Main screen
struct DisciplineView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Habit.order) private var allHabits: [Habit]
    @Query private var notes: [HabitNote]

    @State private var weekOffset = 0
    @State private var monthOffset = 0
    @State private var window = 30
    @State private var sheet: HabitSheetKind?
    @State private var showNote = false
    @State private var pendingDelete: Habit?
    @State private var metrics = DisciplineMetrics()
    @State private var today = Calendar.current.startOfDay(for: .now)

    private let green = Color(hex: 0x7CC4A0)
    private let rose = Color(hex: 0xD9788A)
    private let peach = Color(hex: 0xE8A07C)

    private static let cachedCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }()
    private var cal: Calendar { Self.cachedCalendar }

    private var metricsInput: DisciplineMetricsInput {
        DisciplineMetricsInput(day: today, habits: allHabits.map {
            DisciplineHabitInput(id: $0.persistentModelID,
                                 days: $0.completedDays,
                                 target: $0.targetPerWeek,
                                 archived: $0.archived,
                                 createdAt: $0.createdAt,
                                 name: $0.name)
        })
    }

    private func refreshMetrics() {
        let active = habits
        var next = DisciplineMetrics()
        for habit in active {
            next.days[habit.persistentModelID] = Set(habit.completedDays.map { cal.startOfDay(for: $0) })
            next.streaks[habit.persistentModelID] = HabitMath.streak(habit, today: today)
        }
        next.weeklyRate = HabitMath.weeklyRate(active, endingAt: today)
        next.lastWeekRate = HabitMath.weeklyRate(active, endingAt: cal.date(byAdding: .day, value: -7, to: today) ?? today)
        next.perfectDays = HabitMath.perfectDays(active, inMonthOf: today)
        next.consistency30 = HabitMath.consistency(active, days: 30, today: today)
        next.consistency90 = HabitMath.consistency(active, days: 90, today: today)
        if let result = HabitMath.bestLift(active) {
            next.lift = (name: result.habit.name, value: result.lift)
        }
        metrics = next
    }

    private func streakInfo(_ habit: Habit) -> StreakInfo {
        metrics.streaks[habit.persistentModelID] ?? StreakInfo(value: 0, weekly: habit.targetPerWeek < 7)
    }

    private func isComplete(_ habit: Habit, on day: Date) -> Bool {
        metrics.days[habit.persistentModelID]?.contains(cal.startOfDay(for: day)) ?? false
    }
    private var habits: [Habit] { allHabits.filter { !$0.archived } }

    // MARK: derived stats
    private var archivedHabits: [Habit] { allHabits.filter { $0.archived } }
    private var dueToday: [Habit] { habits.filter { HabitMath.isDue($0, on: .now) } }
    private var doneToday: Int { dueToday.filter { $0.isDone(.now) }.count }
    private var weeklyRate: Double { metrics.weeklyRate }
    private var lastWeekRate: Double { metrics.lastWeekRate }
    private var bestStreak: (Habit, Int)? {
        habits.filter { $0.targetPerWeek >= 7 }
            .map { ($0, streakInfo($0).value) }
            .max(by: { $0.1 < $1.1 })
    }
    private var currentNote: HabitNote? {
        let ws = HabitMath.startOfWeek(.now)
        return notes.first { cal.isDate($0.weekStart, inSameDayAs: ws) }
    }

    // MARK: body
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(title: "Discipline Tracker",
                           subtitle: "Build quiet consistency through small promises kept each day.") {
                    PrimaryButton(title: "Add habit") { sheet = .new }
                }

                statRow

                HStack(alignment: .top, spacing: 20) {
                    VStack(spacing: 20) {
                        weekCard
                        monthCard
                    }
                    VStack(spacing: 20) {
                        consistencyCard
                        reflectionCard
                    }
                    .frame(width: 330)
                }
            }
            .padding(32)
        }
        .sheet(item: $sheet) { kind in
            switch kind {
            case .new: HabitSheet(editing: nil)
            case .edit(let h): HabitSheet(editing: h)
            }
        }
        .sheet(isPresented: $showNote) {
            NoteSheet(weekStart: HabitMath.startOfWeek(.now), existing: currentNote)
        }
        .alert("Delete habit?", isPresented: Binding(get: { pendingDelete != nil },
                                                     set: { if !$0 { pendingDelete = nil } }),
               presenting: pendingDelete) { h in
            Button("Delete", role: .destructive) { ctx.delete(h); pendingDelete = nil }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { h in
            Text("\"\(h.name)\" and all of its history will be removed.")
        }
        .onChange(of: metricsInput, initial: true) { _, _ in
            refreshMetrics()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                today = cal.startOfDay(for: .now)
                refreshMetrics()
            }
        }
        .task {
            seedIfNeeded()
            refreshMetrics()

            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(60))
                } catch {
                    return
                }

                let day = cal.startOfDay(for: .now)

                if day != today {
                    today = day
                }
            }
        }
        .onDisappear {
            Coach.shared.cancel()
        }
    }

    // MARK: stat row
    private var statRow: some View {
        let due = dueToday.count
        let left = due - doneToday
        let delta = Int(((weeklyRate - lastWeekRate) * 100).rounded())
        let best = bestStreak
        let streakValue = best.map { streakInfo($0.0).text } ?? "0 days"
        let perfect = metrics.perfectDays

        return HStack(spacing: 16) {
            MetricCard(icon: "sun.max", tint: Color.dlYellow, fg: Color(hex: 0xE3B94F),
                       label: "Today", value: "\(doneToday) / \(due)",
                       caption: left == 0 ? "all done" : (left == 1 ? "one habit left" : "\(left) habits left"),
                       captionColor: Color(hex: 0xE3A53F))
            MetricCard(icon: "chart.bar.fill", tint: Color.dlGreen, fg: green,
                       label: "Weekly rate", value: "\(Int(weeklyRate * 100))%",
                       caption: (delta >= 0 ? "+" : "") + "\(delta)% vs last week",
                       captionColor: delta >= 0 ? green : rose)
            MetricCard(icon: "flame.fill", tint: Color.dlPeach, fg: peach,
                       label: "Best streak", value: streakValue,
                       caption: best?.0.name.lowercased() ?? "no streak yet",
                       captionColor: peach)
            MetricCard(icon: "sparkles", tint: Color.dlLilac, fg: Color.dlAccent,
                       label: "Perfect days", value: "\(perfect)", caption: "this month",
                       captionColor: Color.dlAccent)
        }
    }

    // MARK: week card
    private var weekStart: Date {
        let base = HabitMath.startOfWeek(.now)
        return cal.date(byAdding: .weekOfYear, value: weekOffset, to: base) ?? base
    }

    private var weekCard: some View {
        let days = HabitMath.weekDays(weekStart)
        let end = HabitMath.weekEnd(weekStart)
        let title = weekOffset == 0 ? "This week"
            : (weekOffset == -1 ? "Last week"
               : "Week of " + weekStart.formatted(.dateTime.month(.abbreviated).day()))

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 18, weight: .bold))
                    Text(weekStart.formatted(.dateTime.month(.wide).day()) + " – "
                         + end.formatted(.dateTime.month(.wide).day()))
                        .font(.system(size: 12)).foregroundStyle(Color.dlMuted)
                }
                Spacer()
                smallNav("chevron.left") { weekOffset -= 1 }
                Button("Current week") { weekOffset = 0 }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Color.dlBg, in: RoundedRectangle(cornerRadius: 9))
                smallNav("chevron.right") { weekOffset += 1 }
                    .disabled(weekOffset >= 0)
            }

            if habits.isEmpty {
                Text("Add your first habit to start tracking.")
                    .font(.system(size: 13)).foregroundStyle(Color.dlMuted)
                    .frame(maxWidth: .infinity).padding(.vertical, 30)
            } else {
                weekGrid(days)
            }
            if !archivedHabits.isEmpty {
                Menu {
                    ForEach(archivedHabits) { h in
                        Button("Restore \(h.name)") { h.archived = false }
                    }
                } label: {
                    Label("Archived (\(archivedHabits.count))", systemImage: "archivebox")
                        .font(.system(size: 11))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
    }

    private func weekGrid(_ days: [Date]) -> some View {
        Grid(alignment: .center, horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                Text("HABIT").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.dlMuted)
                    .frame(width: 200, alignment: .leading)
                ForEach(days, id: \.self) { d in dayHeader(d) }
                Text("STREAK").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.dlMuted)
                    .frame(width: 74, alignment: .trailing)
            }
            Divider().gridCellUnsizedAxes(.horizontal)

            ForEach(habits) { h in
                GridRow {
                    HabitLabelView(habit: h,
                                   subtitle: subtitle(h),
                                   onEdit: { sheet = .edit(h) },
                                   onArchive: { h.archived = true },
                                   onDelete: { pendingDelete = h })
                    ForEach(days, id: \.self) { d in cell(h, d) }
                    Text(streakInfo(h).text)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(habitColor(h))
                        .frame(width: 74, alignment: .trailing)
                }
            }
        }
    }

    private func dayHeader(_ d: Date) -> some View {
        let isToday = cal.isDateInToday(d)
        let letter = d.formatted(.dateTime.weekday(.narrow))
        let num = String(cal.component(.day, from: d))
        return Text(letter + " " + num)
            .font(.system(size: 10, weight: isToday ? .bold : .medium))
            .foregroundStyle(isToday ? Color.dlAccent : Color.dlMuted)
            .frame(maxWidth: .infinity)
    }

    private func habitColor(_ h: Habit) -> Color { paletteDot(h.colorKey) }

    private func subtitle(_ h: Habit) -> String {
        if h.targetPerWeek < 7 { return "\(h.targetPerWeek) × week" }
        return h.detail.isEmpty ? "Daily" : h.detail
    }

    private func habitLabel(_ h: Habit) -> some View {
        HStack(spacing: 12) {
            Image(systemName: h.icon)
                .font(.system(size: 14))
                .foregroundStyle(habitColor(h))
                .frame(width: 34, height: 34)
                .background(paletteTint(h.colorKey), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(h.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text(subtitle(h)).font(.system(size: 11)).foregroundStyle(Color.dlMuted)
            }
        }
        .frame(width: 200, alignment: .leading)
        .contextMenu {
            Button("Edit habit…") { sheet = .edit(h) }
            Button("Archive") { h.archived = true }
            Divider()
            Button("Delete…", role: .destructive) { pendingDelete = h }
        }
    }

    private func cell(_ h: Habit, _ d: Date) -> some View {
        let done = isComplete(h, on: d)
        let future = cal.startOfDay(for: d) > cal.startOfDay(for: .now)
        return Button { toggle(h, d) } label: {
            RoundedRectangle(cornerRadius: 10)
                .fill(done ? habitColor(h) : Color.dlBg)
                .overlay {
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(height: 36)
                .contentShape(Rectangle())
                .animation(.easeOut(duration: 0.15), value: done)
        }
        .buttonStyle(.plain)
        .disabled(future)
        .opacity(future ? 0.4 : 1)
    }

    private func smallNav(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                .frame(width: 30, height: 30)
                .background(Color.dlBg, in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }

    // MARK: month card
    private var monthStart: Date {
        let base = cal.date(from: cal.dateComponents([.year, .month], from: .now)) ?? .now
        return cal.date(byAdding: .month, value: monthOffset, to: base) ?? base
    }

    private var monthCells: [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: monthStart) else { return [] }
        let lead = (cal.component(.weekday, from: monthStart) - cal.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: lead)
        for i in 0..<range.count {
            cells.append(cal.date(byAdding: .day, value: i, to: monthStart))
        }
        return cells
    }

    private var monthCard: some View {
        let lift = metrics.lift
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Monthly consistency").font(.system(size: 18, weight: .bold))
                    Text(monthStart.formatted(.dateTime.month(.wide).year()) + " · habits completed each day")
                        .font(.system(size: 12)).foregroundStyle(Color.dlMuted)
                }
                Spacer()
                smallNav("chevron.left") { monthOffset -= 1 }
                smallNav("chevron.right") { monthOffset += 1 }.disabled(monthOffset >= 0)
            }

            HStack(alignment: .top, spacing: 28) {
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        ForEach(["M", "T", "W", "T", "F", "S", "S"].indices, id: \.self) { i in
                            Text(["M", "T", "W", "T", "F", "S", "S"][i])
                                .font(.system(size: 10, weight: .medium)).foregroundStyle(Color.dlMuted)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                        ForEach(Array(monthCells.enumerated()), id: \.offset) { _, d in
                            heatCell(d)
                        }
                    }
                    HStack(spacing: 6) {
                        Spacer()
                        Text("Less").font(.system(size: 10)).foregroundStyle(Color.dlMuted)
                        ForEach([0.0, 0.2, 0.5, 0.8, 1.0], id: \.self) { r in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(heatColor(r, future: false))
                                .frame(width: 14, height: 14)
                        }
                        Text("More").font(.system(size: 10)).foregroundStyle(Color.dlMuted)
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    Text("PATTERN NOTICED")
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(Color.dlAccent)
                    if let l = lift {
                        Text("Your best days begin with \(l.name.lowercased()).")
                            .font(.system(size: 18, weight: .bold))
                        Text("On \(l.name.lowercased()) days, you complete \(Int((l.value * 100).rounded()))% more of your remaining habits.")
                            .font(.system(size: 12)).foregroundStyle(Color.dlMuted)
                    } else {
                        Text("Keep logging.").font(.system(size: 18, weight: .bold))
                        Text("Patterns show up after a couple of weeks of data.")
                            .font(.system(size: 12)).foregroundStyle(Color.dlMuted)
                    }
                }
                .frame(width: 230, alignment: .leading)
            }
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
    }

    private func heatCell(_ d: Date?) -> some View {
        Group {
            if let d {
                let future = cal.startOfDay(for: d) > cal.startOfDay(for: .now)
                let n = habits.filter { isComplete($0, on: d) }.count
                let r = habits.isEmpty ? 0 : Double(n) / Double(habits.count)
                Text(n > 0 ? "\(n)" : "")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(r > 0.6 ? Color.white : Color.dlText.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .frame(height: 26)
                    .background(heatColor(r, future: future), in: RoundedRectangle(cornerRadius: 8))
            } else {
                Color.clear.frame(height: 26)
            }
        }
    }

    private func heatColor(_ r: Double, future: Bool) -> Color {
        if future { return Color.dlLine.opacity(0.25) }
        if r <= 0 { return Color.dlLine.opacity(0.45) }
        if r < 0.34 { return green.opacity(0.28) }
        if r < 0.67 { return green.opacity(0.5) }
        if r < 1 { return green.opacity(0.75) }
        return green
    }

    // MARK: consistency card
    private var topStreaks: [(Habit, StreakInfo)] {
        habits.map { ($0, streakInfo($0)) }
            .filter { $0.1.value > 0 }
            .sorted { $0.1.approxDays > $1.1.approxDays }
            .prefix(3)
            .map { $0 }
    }

    private var consistencyCard: some View {
        let value = window == 90 ? metrics.consistency90 : metrics.consistency30
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Consistency").font(.system(size: 18, weight: .bold))
                Spacer()
                HStack(spacing: 2) {
                    ForEach([30, 90], id: \.self) { w in
                        Button { window = w } label: {
                            Text("\(w)d").font(.system(size: 12))
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(window == w ? Color.white : .clear, in: RoundedRectangle(cornerRadius: 8))
                                .shadow(color: .black.opacity(window == w ? 0.06 : 0), radius: 2, y: 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3).background(Color.dlBg, in: RoundedRectangle(cornerRadius: 11))
            }

            ConsistencyRing(value: value).frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                Text("TOP STREAKS").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.dlMuted)
                ForEach(Array(topStreaks.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 10) {
                        Image(systemName: item.0.icon).font(.system(size: 12))
                            .foregroundStyle(habitColor(item.0)).frame(width: 20)
                        Text(item.0.name).font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text(item.1.text).font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(habitColor(item.0))
                    }
                }
                if topStreaks.isEmpty {
                    Text("No active streaks yet.").font(.system(size: 12)).foregroundStyle(Color.dlMuted)
                }
            }
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
    }

    // MARK: reflection card
    private var reflectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Weekly reflection", systemImage: "sparkles")
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.dlAccent)
            Text("What made your routines feel easier this week?")
                .font(.system(size: 13)).foregroundStyle(Color.dlMuted)
            if let n = currentNote, !n.text.isEmpty {
                Text(n.text).font(.system(size: 13)).lineLimit(4)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
            }
            Button { showNote = true } label: {
                Text(currentNote == nil ? "Write a note" : "Edit note")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(Color.dlLilac.opacity(0.55), in: RoundedRectangle(cornerRadius: 24))
    }

    private func toggle(_ h: Habit, _ day: Date) {
        h.toggle(day)
    }

    // MARK: sample data
    private func seedIfNeeded() {
        guard allHabits.isEmpty else { return }
        let c = HabitMath.cal
        let today = c.startOfDay(for: .now)

        func make(_ name: String, _ detail: String, _ icon: String, _ color: String,
                  target: Int, order: Int, p: Double, forced: Int = 0, doneToday: Bool) {
            let h = Habit(name: name, detail: detail, icon: icon, colorKey: color, targetPerWeek: target)
            h.order = order
            h.createdAt = c.date(byAdding: .day, value: -110, to: today) ?? today
            var days: [Date] = []
            for i in 0..<110 {
                guard let d = c.date(byAdding: .day, value: -i, to: today) else { continue }
                let done: Bool
                if i == 0 { done = doneToday }
                else if i < forced { done = true }
                else { done = Double.random(in: 0..<1) < (Double(target) / 7.0) * p }
                if done { days.append(d) }
            }
            h.completedDays = days
            ctx.insert(h)
        }

        make("Morning walk", "20 min", "figure.walk", "green", target: 7, order: 0, p: 0.9, forced: 12, doneToday: true)
        make("Read deeply", "30 min", "book", "lilac", target: 7, order: 1, p: 0.8, doneToday: true)
        make("Strength session", "", "dumbbell.fill", "peach", target: 3, order: 2, p: 0.95, doneToday: false)
        make("Meditate", "10 min", "brain", "blue", target: 7, order: 3, p: 0.75, doneToday: true)
        make("No screens after 10", "Daily", "moon.stars", "rose", target: 7, order: 4, p: 0.7, doneToday: false)
    }
}

// MARK: - Habit sheet
struct HabitSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query private var habits: [Habit]
    let editing: Habit?

    @State private var name: String
    @State private var detail: String
    @State private var icon: String
    @State private var colorKey: String
    @State private var target: Int
    @State private var confirmDelete = false

    private let icons = ["figure.walk", "book", "dumbbell.fill", "brain", "moon.stars", "drop.fill",
                         "fork.knife", "pencil", "music.note", "bed.double.fill", "leaf", "heart.fill"]

    init(editing: Habit?) {
        self.editing = editing
        _name = State(initialValue: editing?.name ?? "")
        _detail = State(initialValue: editing?.detail ?? "")
        _icon = State(initialValue: editing?.icon ?? "figure.walk")
        _colorKey = State(initialValue: editing?.colorKey ?? "green")
        _target = State(initialValue: editing?.targetPerWeek ?? 7)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(editing == nil ? "Add habit" : "Edit habit")
                .font(.system(size: 20, weight: .bold))

            TextField("Habit name (e.g. Morning walk)", text: $name).textFieldStyle(.roundedBorder)
            TextField("Detail (e.g. 20 min)", text: $detail).textFieldStyle(.roundedBorder)

            Stepper(target == 7 ? "Every day" : "\(target) × per week", value: $target, in: 1...7)

            VStack(alignment: .leading, spacing: 8) {
                Text("Icon").font(.system(size: 12)).foregroundStyle(Color.dlMuted)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                    ForEach(icons, id: \.self) { i in
                        Button { icon = i } label: {
                            Image(systemName: i)
                                .font(.system(size: 15))
                                .foregroundStyle(icon == i ? paletteDot(colorKey) : Color.dlText)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(icon == i ? paletteTint(colorKey) : Color.dlBg,
                                            in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 10) {
                Text("Color")
                ForEach(eventColorKeys, id: \.self) { k in
                    Circle().fill(paletteDot(k)).frame(width: 22, height: 22)
                        .overlay(Circle().stroke(Color.dlInk, lineWidth: colorKey == k ? 2 : 0).padding(-3))
                        .onTapGesture { colorKey = k }
                }
            }

            HStack {
                if let h = editing {
                    Button("Archive") { h.archived = true; dismiss() }
                    Button("Delete", role: .destructive) { confirmDelete = true }
                }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
        .foregroundStyle(Color.dlText)
        .alert("Delete this habit?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                if let h = editing { ctx.delete(h) }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its history will be removed too.")
        }
    }

    private func save() {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let h = editing {
            h.name = n; h.detail = detail; h.icon = icon
            h.colorKey = colorKey; h.targetPerWeek = target
        } else {
            let h = Habit(name: n, detail: detail, icon: icon, colorKey: colorKey, targetPerWeek: target)
            h.order = (habits.map(\.order).max() ?? -1) + 1
            ctx.insert(h)
        }
        dismiss()
    }
}

// MARK: - Weekly note sheet
struct NoteSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let weekStart: Date
    let existing: HabitNote?
    @State private var text: String

    init(weekStart: Date, existing: HabitNote?) {
        self.weekStart = weekStart
        self.existing = existing
        _text = State(initialValue: existing?.text ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Weekly reflection").font(.system(size: 20, weight: .bold))
            Text("What made your routines feel easier this week?")
                .font(.system(size: 13)).foregroundStyle(Color.dlMuted)
            TextEditor(text: $text)
                .font(.system(size: 13))
                .frame(height: 150)
                .padding(6)
                .background(Color.dlBg, in: RoundedRectangle(cornerRadius: 10))
                .scrollContentBackground(.hidden)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    if let n = existing { n.text = text }
                    else { ctx.insert(HabitNote(weekStart: weekStart, text: text)) }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 440)
        .foregroundStyle(Color.dlText)
    }
}


struct HabitLabelView: View {
    let habit: Habit
    let subtitle: String
    var onEdit: () -> Void
    var onArchive: () -> Void
    var onDelete: () -> Void

    @State private var hover = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: habit.icon)
                .font(.system(size: 14))
                .foregroundStyle(paletteDot(habit.colorKey))
                .frame(width: 34, height: 34)
                .background(paletteTint(habit.colorKey), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text(subtitle).font(.system(size: 11)).foregroundStyle(Color.dlMuted)
            }
            Spacer(minLength: 0)
            if hover {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dlMuted)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .frame(width: 200, alignment: .leading)
        .background(hover ? Color.dlBg.opacity(0.8) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .onHover { hover = $0 }
        .help("Click to edit")
        .contextMenu {
            Button("Edit habit…", action: onEdit)
            Button("Archive", action: onArchive)
            Divider()
            Button("Delete…", role: .destructive, action: onDelete)
        }
    }
}

// MARK: - Cached metrics inputs
private struct DisciplineHabitInput: Equatable {
    let id: PersistentIdentifier
    let days: [Date]
    let target: Int
    let archived: Bool
    let createdAt: Date
    let name: String
}

private struct DisciplineMetricsInput: Equatable {
    let day: Date
    let habits: [DisciplineHabitInput]
}

private struct DisciplineMetrics {
    var days: [PersistentIdentifier: Set<Date>] = [:]
    var streaks: [PersistentIdentifier: StreakInfo] = [:]
    var weeklyRate: Double = 0
    var lastWeekRate: Double = 0
    var perfectDays: Int = 0
    var consistency30: Double = 0
    var consistency90: Double = 0
    var lift: (name: String, value: Double)?
}

// Only this view observes the coach's display state.

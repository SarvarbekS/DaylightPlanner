import SwiftUI
import SwiftData

enum GoalTab: String, CaseIterable {
    case active = "Active", completed = "Completed", archived = "Archived"
    var status: GoalStatus {
        switch self {
        case .active: return .active
        case .completed: return .completed
        case .archived: return .archived
        }
    }
}

enum GoalSheetKind: Identifiable {
    case new(Int)
    case edit(Goal)
    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let g): return "edit-\(g.persistentModelID.hashValue)"
        }
    }
}

struct Celebration: Identifiable {
    let id = UUID()
    let title: String
}

// MARK: - Formatting helpers
enum GoalFormat {
    static let currency: Set<String> = ["$", "€", "£", "₩", "¥"]

    static func number(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }

    static func amount(_ v: Double, unit: String) -> String {
        let s = number(v)
        if currency.contains(unit) { return unit + s }
        return unit.isEmpty ? s : "\(s) \(unit)"
    }

    static func progress(_ g: Goal) -> String {
        var s: String
        if currency.contains(g.unit) {
            s = "\(amount(g.current, unit: g.unit)) of \(amount(g.target, unit: g.unit))"
        } else {
            s = "\(number(g.current)) of \(amount(g.target, unit: g.unit))"
        }
        if !g.detail.isEmpty { s += " · \(g.detail)" }
        return s
    }

    static func shortDate(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.component(.year, from: d) == cal.component(.year, from: .now) {
            return d.formatted(.dateTime.month(.abbreviated).day())
        }
        return d.formatted(.dateTime.month(.abbreviated).year())
    }

    static func remaining(_ g: Goal) -> (value: String, caption: String, overdue: Bool) {
        if g.status == .completed { return ("Done", "Completed", false) }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: .now),
                                      to: cal.startOfDay(for: g.deadline)).day ?? 0
        if days < 0 { return ("Overdue", "\(-days) days ago", true) }
        if days == 0 { return ("Today", "Deadline", false) }
        if days >= 14 { return ("\(Int((Double(days) / 7).rounded())) wks", "Remaining", false) }
        return ("\(days) days", "Remaining", false)
    }

    static func steps(for target: Double) -> [Double] {
        let t = max(target, 10)
        let m = pow(10, floor(log10(t)))
        return [m / 10, m / 5, m / 2]
    }
}

// MARK: - Main screen
struct GoalsView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Goal.createdAt) private var allGoals: [Goal]

    @State private var tab: GoalTab = .active
    @State private var year = Calendar.current.component(.year, from: .now)
    @State private var selectedID: PersistentIdentifier?
    @State private var sheet: GoalSheetKind?
    @State private var pendingDelete: Goal?
    @State private var celebration: Celebration?

    private var yearGoals: [Goal] { allGoals.filter { $0.year == year } }
    private var shown: [Goal] { yearGoals.filter { $0.status == tab.status } }
    private var selected: Goal? {
        shown.first { $0.persistentModelID == selectedID } ?? shown.first
    }
    private var live: [Goal] { yearGoals.filter { $0.status != .archived } }
    private var avg: Double {
        live.isEmpty ? 0 : live.map(\.progress).reduce(0, +) / Double(live.count)
    }
    private var milestonesReached: Int { live.flatMap(\.milestones).filter(\.done).count }
    private var activeCount: Int { yearGoals.filter { $0.status == .active }.count }

    var body: some View {
        ZStack(alignment: .top) {
            content

            if let c = celebration {
                ConfettiView()
                    .id(c.id)
                    .allowsHitTesting(false)
                HStack(spacing: 8) {
                    Image(systemName: "sparkles").foregroundStyle(Color.dlAccent)
                    Text("Goal complete: \(c.title)").font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(.white, in: Capsule())
                .shadow(color: .black.opacity(0.15), radius: 14, y: 4)
                .padding(.top, 24)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task(id: celebration?.id) {
            guard celebration != nil else { return }
            try? await Task.sleep(for: .seconds(3.6))
            withAnimation(.easeOut(duration: 0.3)) { celebration = nil }
        }
        .task { seedIfNeeded() }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeader(title: "Goals",
                       subtitle: "Connect daily effort to outcomes that matter over time.") {
                PrimaryButton(title: "Create goal") { sheet = .new(year) }
            }

            toolbar

            HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 16) {
                    YearlyHero(avg: avg, active: activeCount,
                               milestones: milestonesReached, hasGoals: !live.isEmpty)
                    if shown.isEmpty {
                        emptyState
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 14) {
                                ForEach(shown) { g in
                                    GoalCard(goal: g, selected: g === selected)
                                        .onTapGesture {
                                            withAnimation(.snappy(duration: 0.25)) {
                                                selectedID = g.persistentModelID
                                            }
                                        }
                                }
                            }
                            .padding(.bottom, 8)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                Group {
                    if let g = selected {
                        GoalDetail(goal: g,
                                   onEdit: { sheet = .edit(g) },
                                   onDelete: { pendingDelete = g },
                                   onCelebrate: { celebrate($0) })
                            .id(g.persistentModelID)
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "scope").font(.system(size: 30)).foregroundStyle(Color.dlMuted)
                            Text("Select a goal to see its details")
                                .font(.system(size: 13)).foregroundStyle(Color.dlMuted)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.white, in: RoundedRectangle(cornerRadius: 24))
                    }
                }
                .frame(width: 400)
                .frame(maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(32)
        .sheet(item: $sheet) { kind in
            switch kind {
            case .new(let y): GoalSheet(editing: nil, year: y)
            case .edit(let g): GoalSheet(editing: g, year: g.year)
            }
        }
        .alert("Delete goal?", isPresented: Binding(get: { pendingDelete != nil },
                                                    set: { if !$0 { pendingDelete = nil } }),
               presenting: pendingDelete) { g in
            Button("Delete", role: .destructive) {
                selectedID = nil
                ctx.delete(g)
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { g in
            Text("\"\(g.title)\" and its milestones will be removed.")
        }
    }

    private func celebrate(_ g: Goal) {
        withAnimation(.spring(duration: 0.4)) { celebration = Celebration(title: g.title) }
    }

    // MARK: toolbar
    private var toolbar: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(GoalTab.allCases, id: \.self) { t in
                    Button { tab = t } label: {
                        Text(t.rawValue).font(.system(size: 13))
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(tab == t ? Color.white : .clear, in: RoundedRectangle(cornerRadius: 10))
                            .shadow(color: .black.opacity(tab == t ? 0.06 : 0), radius: 3, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4).background(Color.dlLine.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))

            Spacer()

            yearButton("chevron.left") { year -= 1 }
            Text(String(year) + " goals").font(.system(size: 17, weight: .semibold)).frame(minWidth: 110)
            yearButton("chevron.right") { year += 1 }
        }
    }

    private func yearButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(.white, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "flag.checkered").font(.system(size: 30)).foregroundStyle(Color.dlMuted)
            Text("No \(tab.rawValue.lowercased()) goals for \(String(year))")
                .font(.system(size: 14, weight: .medium))
            if tab == .active {
                Text("Pick one thing you want to look back on with pride.")
                    .font(.system(size: 12)).foregroundStyle(Color.dlMuted)
                Button("Create a goal") { sheet = .new(year) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
    }

    // MARK: sample data
    private func seedIfNeeded() {
        guard allGoals.isEmpty else { return }
        let cal = Calendar.current
        let y = cal.component(.year, from: .now)

        func d(_ month: Int, _ day: Int, _ yr: Int? = nil) -> Date {
            cal.date(from: DateComponents(year: yr ?? y, month: month, day: day, hour: 12)) ?? .now
        }

        func make(_ title: String, _ cat: GoalCategory, _ cur: Double, _ tgt: Double, _ unit: String,
                  _ deadline: Date, detail: String = "", next: String = "", nextDate: Date? = nil,
                  milestones: [(String, Date, Bool)]) {
            let g = Goal(title: title, category: cat.rawValue, current: cur, target: tgt,
                         unit: unit, deadline: deadline)
            g.year = y
            g.createdAt = d(1, 1)
            g.detail = detail
            g.nextAction = next
            g.nextActionDate = nextDate
            ctx.insert(g)
            for (i, m) in milestones.enumerated() {
                let ms = Milestone(title: m.0, date: m.1)
                ms.order = i
                ms.done = m.2
                ms.completedAt = m.2 ? m.1 : nil
                ctx.insert(ms)
                g.milestones.append(ms)
            }
        }

        let nextSunday = cal.nextDate(after: .now, matching: DateComponents(weekday: 1),
                                      matchingPolicy: .nextTime) ?? .now

        make("Run a comfortable 10K", .wellbeing, 6.8, 10, "km", d(12, 12), detail: "longest run",
             next: "Easy 7.2 km route along the river", nextDate: nextSunday,
             milestones: [("Run 3 km without stopping", d(8, 18), true),
                          ("Complete first 5K", d(9, 8), true),
                          ("Run 6 km at an easy pace", d(9, 29), true),
                          ("Reach an 8 km long run", d(10, 25), false),
                          ("Complete the 10K route", d(12, 12), false)])

        make("Publish 12 thoughtful essays", .creative, 5, 12, "essays", d(12, 31),
             milestones: [("Outline all 12 topics", d(2, 14), true),
                          ("Publish the fifth essay", d(8, 30), true),
                          ("Publish eight essays", d(11, 15), false),
                          ("Publish the twelfth essay", d(12, 31), false)])

        make("Build a 6-month safety fund", .financial, 8850, 12000, "$", d(3, 31, y + 1),
             milestones: [("Save the first $3,000", d(4, 20), true),
                          ("Reach $9,000", d(11, 1), false),
                          ("Reach $12,000", d(3, 31, y + 1), false)])

        make("Read 24 books this year", .learning, 19, 24, "books", d(12, 31),
             milestones: [("Reach 12 books", d(7, 1), true),
                          ("Reach 20 books", d(11, 15), false)])
    }
}

// MARK: - Hero
struct YearlyHero: View {
    let avg: Double
    let active: Int
    let milestones: Int
    let hasGoals: Bool

    @State private var shown: Double = 0

    private var headline: String {
        if !hasGoals { return "A fresh page. Add a goal that matters to you." }
        if avg >= 0.85 { return "Almost there. Finish strong." }
        if avg >= 0.6 { return "Steady progress across every life area." }
        if avg >= 0.3 { return "Momentum is building. Keep going." }
        return "Plant the seeds. Small steps count."
    }

    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("YEARLY DIRECTION")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
                Text(headline)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(active) active goals · \(milestones) milestones reached · \(Int(avg * 100))% average completion")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer(minLength: 0)

            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: shown)
                    .stroke(AngularGradient(colors: [Color.dlAccent, Color(hex: 0xB9A6F0)], center: .center),
                            style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(avg * 100))%")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 84, height: 84)
        }
        .padding(24)
        .background(
            LinearGradient(colors: [Color(hex: 0x1F1F26), Color(hex: 0x2B2740)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26)
        )
        .onAppear { withAnimation(.easeOut(duration: 1.1)) { shown = avg } }
        .onChange(of: avg) { _, new in withAnimation(.easeOut(duration: 0.8)) { shown = new } }
    }
}

// MARK: - Progress bar
struct GoalBar: View {
    let progress: Double
    let color: Color
    var height: CGFloat = 7

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.dlLine.opacity(0.9))
                Capsule().fill(color)
                    .frame(width: max(geo.size.width * progress, progress > 0 ? height : 0))
                    .animation(.snappy(duration: 0.5), value: progress)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Goal card
struct GoalCard: View {
    let goal: Goal
    let selected: Bool

    private var overdue: Bool {
        goal.status == .active && goal.deadline < Calendar.current.startOfDay(for: .now)
    }

    private var deadlineText: String {
        switch goal.status {
        case .completed: return "Completed"
        case .archived: return "Archived"
        case .active: return GoalFormat.shortDate(goal.deadline)
        }
    }

    var body: some View {
        let cat = goal.cat
        HStack(spacing: 16) {
            Image(systemName: cat.symbol)
                .font(.system(size: 20))
                .foregroundStyle(cat.dot)
                .frame(width: 52, height: 52)
                .background(cat.tint, in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(cat.label.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(cat.dot)
                    Spacer()
                    HStack(spacing: 4) {
                        if goal.status == .completed {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 10))
                        }
                        Text(deadlineText)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(overdue ? Color(hex: 0xD9788A) : Color.dlMuted)
                }
                Text(goal.title).font(.system(size: 17, weight: .bold)).lineLimit(1)
                Text(GoalFormat.progress(goal))
                    .font(.system(size: 12)).foregroundStyle(Color.dlMuted).lineLimit(1)
                HStack(spacing: 12) {
                    GoalBar(progress: goal.progress, color: cat.dot)
                    Text("\(Int(goal.progress * 100))%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(cat.dot)
                        .frame(width: 38, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .background(selected ? cat.tint.opacity(0.55) : Color.white, in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(selected ? cat.dot.opacity(0.75) : Color.dlLine, lineWidth: selected ? 1.5 : 1)
        )
        .contentShape(Rectangle())
    }
}

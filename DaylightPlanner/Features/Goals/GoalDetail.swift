import SwiftUI
import SwiftData

struct GoalDetail: View {
    @Environment(\.modelContext) private var ctx
    let goal: Goal
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onCelebrate: (Goal) -> Void

    @State private var logText = ""
    @State private var newMilestone = ""

    private var cat: GoalCategory { goal.cat }
    private var done: Int { goal.milestones.filter(\.done).count }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                tiles
                paceRow
                if goal.status == .active { logRow }
                milestonesSection
                nextCard
            }
            .padding(22)
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 26))
    }

    // MARK: header
    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: cat.symbol)
                .font(.system(size: 22))
                .foregroundStyle(cat.dot)
                .frame(width: 56, height: 56)
                .background(cat.tint, in: RoundedRectangle(cornerRadius: 18))
            VStack(alignment: .leading, spacing: 4) {
                Text(cat.label.uppercased())
                    .font(.system(size: 10, weight: .bold)).foregroundStyle(cat.dot)
                Text(goal.title).font(.system(size: 21, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Menu {
                Button("Edit goal…", action: onEdit)
                if goal.status == .active {
                    Button("Mark complete") {
                        withAnimation(.snappy) { goal.complete() }
                        onCelebrate(goal)
                    }
                }
                if goal.status == .completed {
                    Button("Reopen") { goal.status = .active; goal.completedAt = nil }
                }
                if goal.status == .archived {
                    Button("Restore") { goal.status = .active }
                } else {
                    Button("Archive") { goal.status = .archived }
                }
                Divider()
                Button("Delete goal…", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Color.dlMuted)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    // MARK: tiles
    private var tiles: some View {
        let r = GoalFormat.remaining(goal)
        return HStack(spacing: 10) {
            tile(GoalFormat.amount(goal.current, unit: goal.unit), "Current",
                 Color.dlGreen, Color(hex: 0x4E9C78))
            tile(GoalFormat.amount(goal.target, unit: goal.unit), "Target",
                 Color.dlBlue, Color(hex: 0x5C86B8))
            tile(r.value, r.caption, Color.dlPeach,
                 r.overdue ? Color(hex: 0xD9788A) : Color(hex: 0xC9774F))
        }
    }

    private func tile(_ value: String, _ caption: String, _ tint: Color, _ fg: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.system(size: 17, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
            Text(caption).font(.system(size: 11)).foregroundStyle(fg)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: pace
    private var paceRow: some View {
        HStack(spacing: 10) {
            switch goal.pace {
            case .done:
                chip("Complete", "checkmark.seal.fill", Color(hex: 0x4E9C78), Color.dlGreen)
            case .onTrack:
                chip("On track", "arrow.up.right", Color(hex: 0x4E9C78), Color.dlGreen)
            case .behind:
                chip("Behind pace", "hourglass", Color(hex: 0xC9774F), Color.dlPeach)
            }
            if goal.status == .active, let w = goal.perWeekNeeded {
                Text("≈ \(GoalFormat.amount(w, unit: goal.unit)) per week to finish on time")
                    .font(.system(size: 11)).foregroundStyle(Color.dlMuted)
            }
            Spacer(minLength: 0)
        }
    }

    private func chip(_ text: String, _ icon: String, _ fg: Color, _ bg: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(fg)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(bg, in: Capsule())
    }

    // MARK: log progress
    private var logRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Log progress").font(.system(size: 15, weight: .bold))
            HStack(spacing: 8) {
                ForEach(GoalFormat.steps(for: goal.target), id: \.self) { s in
                    Button { log(s) } label: {
                        Text("+" + GoalFormat.number(s))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(cat.dot)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(cat.tint, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
                TextField("Custom", text: $logText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .onSubmit(logCustom)
                Button("Log", action: logCustom)
                    .disabled(Double(logText.replacingOccurrences(of: ",", with: ".")) == nil)
            }
        }
    }

    private func log(_ amount: Double) {
        let finished = withAnimation(.snappy) { goal.log(amount) }
        if finished { onCelebrate(goal) }
    }

    private func logCustom() {
        guard let v = Double(logText.replacingOccurrences(of: ",", with: ".")) else { return }
        logText = ""
        log(v)
    }

    // MARK: milestones
    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Milestones").font(.system(size: 15, weight: .bold))
                Spacer()
                Text("\(done) of \(goal.milestones.count) complete")
                    .font(.system(size: 11)).foregroundStyle(cat.dot)
            }
            .padding(.bottom, 4)

            ForEach(goal.sortedMilestones) { m in
                MilestoneRow(milestone: m, color: cat.dot)
            }

            HStack(spacing: 8) {
                Image(systemName: "plus").font(.system(size: 11)).foregroundStyle(Color.dlMuted)
                TextField("Add a milestone and press Return", text: $newMilestone)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit(addMilestone)
            }
            .padding(10)
            .background(Color.dlBg, in: RoundedRectangle(cornerRadius: 10))
            .padding(.top, 4)
        }
    }

    private func addMilestone() {
        let t = newMilestone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let m = Milestone(title: t)
        m.order = (goal.milestones.map(\.order).max() ?? -1) + 1
        ctx.insert(m)
        goal.milestones.append(m)
        newMilestone = ""
    }

    // MARK: next action
    @ViewBuilder private var nextCard: some View {
        if !goal.nextAction.isEmpty {
            nextCardView(label: "Next action",
                         day: goal.nextActionDate?.formatted(.dateTime.weekday(.wide)),
                         text: goal.nextAction, sub: nil)
        } else if let m = goal.sortedMilestones.first(where: { !$0.done }) {
            nextCardView(label: "Next milestone",
                         day: m.date.map { GoalFormat.shortDate($0) },
                         text: m.title, sub: "Break it into one small step today.")
        }
    }

    private func nextCardView(label: String, day: String?, text: String, sub: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(cat.dot)
                Spacer()
                if let day { Text(day).font(.system(size: 11)).foregroundStyle(Color.dlMuted) }
            }
            Text(text).font(.system(size: 14, weight: .medium))
            if let sub { Text(sub).font(.system(size: 11)).foregroundStyle(Color.dlMuted) }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cat.tint.opacity(0.7), in: RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Milestone row
struct MilestoneRow: View {
    @Environment(\.modelContext) private var ctx
    let milestone: Milestone
    let color: Color

    @State private var editing = false
    @State private var draft = ""
    @State private var showDate = false
    @State private var tmpDate = Date()
    @FocusState private var focused: Bool

    private var subtitle: String? {
        if milestone.done {
            let d = milestone.completedAt ?? milestone.date
            return d.map { "Completed " + GoalFormat.shortDate($0) } ?? "Completed"
        }
        return milestone.date.map { "Target " + GoalFormat.shortDate($0) }
    }

    var body: some View {
        HStack(spacing: 8) {
            Button { withAnimation(.snappy) { milestone.toggle() } } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 6).fill(milestone.done ? color : Color.clear)
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(milestone.done ? Color.clear : Color(hex: 0xCFCBDD), lineWidth: 1.5)
                    if milestone.done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                    }
                }
                .frame(width: 20, height: 20)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                if editing {
                    TextField("Milestone", text: $draft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .semibold))
                        .focused($focused)
                        .onSubmit(commit)
                        .onExitCommand { editing = false }
                } else {
                    Text(milestone.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(milestone.done ? Color.dlText : Color.dlText)
                        .onTapGesture(perform: beginEdit)
                }
                if let subtitle {
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(Color.dlMuted)
                }
            }
            Spacer(minLength: 0)

            Menu {
                Button("Rename", action: beginEdit)
                Button("Set target date…") {
                    tmpDate = milestone.date ?? .now
                    showDate = true
                }
                if milestone.date != nil {
                    Button("Clear date") { milestone.date = nil }
                }
                Divider()
                Button("Delete", role: .destructive) { ctx.delete(milestone) }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 11)).foregroundStyle(Color.dlMuted)
                    .frame(width: 24, height: 24).contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .popover(isPresented: $showDate) {
                VStack(spacing: 10) {
                    DatePicker("", selection: $tmpDate, displayedComponents: .date)
                        .datePickerStyle(.graphical).labelsHidden()
                    HStack {
                        Button("Clear") { milestone.date = nil; showDate = false }
                        Spacer()
                        Button("Set") { milestone.date = tmpDate; showDate = false }
                            .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(14).frame(width: 280)
            }
        }
        .onChange(of: focused) { _, isFocused in
            if !isFocused && editing { commit() }
        }
    }

    private func beginEdit() {
        draft = milestone.title
        editing = true
        DispatchQueue.main.async { focused = true }
    }

    private func commit() {
        let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { milestone.title = t }
        editing = false
    }
}

import SwiftUI
import SwiftData

struct GoalSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let editing: Goal?

    @State private var title: String
    @State private var category: GoalCategory
    @State private var year: Int
    @State private var unit: String
    @State private var current: Double
    @State private var target: Double
    @State private var detail: String
    @State private var deadline: Date
    @State private var nextAction: String
    @State private var hasNextDate: Bool
    @State private var nextDate: Date

    init(editing: Goal?, year: Int) {
        self.editing = editing
        let cal = Calendar.current
        let endOfYear = cal.date(from: DateComponents(year: year, month: 12, day: 31, hour: 12)) ?? .now
        _title = State(initialValue: editing?.title ?? "")
        _category = State(initialValue: editing?.cat ?? .wellbeing)
        _year = State(initialValue: editing?.year ?? year)
        _unit = State(initialValue: editing?.unit ?? "")
        _current = State(initialValue: editing?.current ?? 0)
        _target = State(initialValue: editing?.target ?? 10)
        _detail = State(initialValue: editing?.detail ?? "")
        _deadline = State(initialValue: editing?.deadline ?? endOfYear)
        _nextAction = State(initialValue: editing?.nextAction ?? "")
        _hasNextDate = State(initialValue: editing?.nextActionDate != nil)
        _nextDate = State(initialValue: editing?.nextActionDate ?? .now)
    }

    private var valid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && target > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(editing == nil ? "Create goal" : "Edit goal")
                .font(.system(size: 20, weight: .bold))

            TextField("What do you want to achieve?", text: $title).textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 8) {
                Text("Area of life").font(.system(size: 12)).foregroundStyle(Color.dlMuted)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(GoalCategory.allCases) { c in
                        Button { category = c } label: {
                            HStack(spacing: 6) {
                                Image(systemName: c.symbol).font(.system(size: 12))
                                Text(c.label).font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(category == c ? c.dot : Color.dlText)
                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                            .background(category == c ? c.tint : Color.dlBg, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(category == c ? c.dot.opacity(0.7) : Color.clear, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 10) {
                field("Current") { TextField("0", value: $current, format: .number).textFieldStyle(.roundedBorder) }
                field("Target") { TextField("10", value: $target, format: .number).textFieldStyle(.roundedBorder) }
                field("Unit") { TextField("km, $, books…", text: $unit).textFieldStyle(.roundedBorder) }
            }

            TextField("Short note (e.g. longest run)", text: $detail).textFieldStyle(.roundedBorder)

            HStack {
                DatePicker("Deadline", selection: $deadline, displayedComponents: .date)
                Spacer()
                Stepper("Year " + String(year), value: $year, in: 2020...2100)
                    .fixedSize()
            }

            TextField("Next action (optional)", text: $nextAction).textFieldStyle(.roundedBorder)
            if !nextAction.isEmpty {
                Toggle("Plan it for a day", isOn: $hasNextDate)
                if hasNextDate { DatePicker("Day", selection: $nextDate, displayedComponents: .date) }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!valid)
            }
        }
        .padding(24)
        .frame(width: 480)
        .foregroundStyle(Color.dlText)
    }

    private func field<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12)).foregroundStyle(Color.dlMuted)
            content()
        }
    }

    private func save() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let next = nextAction.trimmingCharacters(in: .whitespacesAndNewlines)
        let nd: Date? = (!next.isEmpty && hasNextDate) ? nextDate : nil

        if let g = editing {
            g.title = t; g.cat = category; g.year = year; g.unit = unit
            g.current = current; g.target = target; g.detail = detail
            g.deadline = deadline; g.nextAction = next; g.nextActionDate = nd
        } else {
            let g = Goal(title: t, category: category.rawValue, current: current,
                         target: target, unit: unit, deadline: deadline)
            g.year = year
            g.detail = detail
            g.nextAction = next
            g.nextActionDate = nd
            ctx.insert(g)
        }
        dismiss()
    }
}

// MARK: - Confetti
struct ConfettiView: View {
    private struct Piece {
        let vx: Double, vy: Double, spin: Double, phase: Double
        let w: CGFloat, h: CGFloat
        let color: Color
    }

    @State private var start = Date()
    @State private var pieces: [Piece] = ConfettiView.make()

    private static func make() -> [Piece] {
        (0..<150).map { _ in
            let angle = Double.random(in: (-Double.pi * 0.95)...(-Double.pi * 0.05))
            let speed = Double.random(in: 380...900)
            return Piece(vx: cos(angle) * speed,
                         vy: sin(angle) * speed,
                         spin: Double.random(in: -8...8),
                         phase: Double.random(in: 0...6.28),
                         w: CGFloat.random(in: 6...10),
                         h: CGFloat.random(in: 3...6),
                         color: paletteDot(eventColorKeys.randomElement() ?? "lilac"))
        }
    }

    var body: some View {
        TimelineView(.animation) { ctx in
            Canvas { gc, size in
                let t = ctx.date.timeIntervalSince(start)
                let origin = CGPoint(x: size.width * 0.5, y: size.height * 0.38)
                for p in pieces {
                    let x = origin.x + p.vx * t * 0.8 + sin(t * 3 + p.phase) * 12
                    let y = origin.y + p.vy * t + 0.5 * 900 * t * t
                    let alpha = max(0, 1 - max(0, t - 1.8) / 1.4)
                    guard alpha > 0, y < size.height + 40 else { continue }
                    var c = gc
                    c.opacity = alpha
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(p.spin * t + p.phase))
                    c.fill(Path(roundedRect: CGRect(x: -p.w / 2, y: -p.h / 2, width: p.w, height: p.h),
                                cornerRadius: 1.5),
                           with: .color(p.color))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

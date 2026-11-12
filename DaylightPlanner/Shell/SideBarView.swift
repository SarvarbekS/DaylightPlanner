import SwiftUI

struct SidebarView: View {
    @Binding var selection: Section

    private func tint(_ s: Section) -> Color {
        switch s {
        case .calendar: .dlLilac
        case .reminders: .dlPeach
        case .todo: .dlBlue
        case .goals: .dlGreen
        case .habits: .dlRose
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "sun.max")
                    .foregroundStyle(.white).frame(width: 40, height: 40)
                    .background(Color.dlAccent, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading) {
                    Text("Daylight").font(.system(size: 16, weight: .bold))
                    Text(Date.now.formatted(.dateTime.weekday(.abbreviated).month(.wide).day()))
                        .font(.caption).foregroundStyle(Color.dlMuted)
                }
            }.padding(.bottom, 12)

            Text("PLAN & REFLECT").font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.dlMuted).padding(.leading, 8)

            ForEach(Section.allCases) { s in
                Button { selection = s } label: {
                    HStack {
                        Image(systemName: s.icon).frame(width: 22)
                        Text(s.rawValue)
                        Spacer()
                        if selection == s { Circle().fill(Color.dlAccent).frame(width: 6, height: 6) }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(selection == s ? tint(s) : .clear,
                                in: RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }

            Spacer()
            WeeklyPulse(value: 0.82)
            PlannerProfileFooter()
        }
        .padding(16)
        .background(Color.dlSidebar)
    }
}

struct WeeklyPulse: View {
    let value: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Weekly pulse").font(.system(size: 12))
                Spacer()
                Text("\(Int(value * 100))%").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.dlAccent)
            }
            ProgressView(value: value).tint(Color.dlAccent)
            Text("A calm, consistent week.\nKeep the rhythm gentle.")
                .font(.caption).foregroundStyle(Color.dlMuted)
        }.card(Color.dlLilac.opacity(0.45))
    }
}

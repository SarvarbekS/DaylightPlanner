import SwiftUI

struct ReminderStrip: View {
    let items: [Reminder]
    let color: (Reminder) -> Color
    let onOpen: (Reminder) -> Void
    private let maxShown = 3

    var body: some View {
        VStack(spacing: 3) {
            ForEach(items.prefix(maxShown)) { r in
                HStack(spacing: 2) {
                    Button { withAnimation(.snappy) { r.toggleDone() } } label: {
                        Image(systemName: r.done ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 11))
                            .foregroundStyle(color(r))
                            .frame(width: 18, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Text(r.title)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                        .strikethrough(r.done)
                        .foregroundStyle(r.done ? Color.dlMuted : Color.dlText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 20)
                        .contentShape(Rectangle())
                        .onTapGesture { onOpen(r) }
                        .help(r.due.map { $0.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute()) } ?? "")
                }
                .padding(.horizontal, 3)
                .background(Color.dlBg, in: RoundedRectangle(cornerRadius: 6))
            }
            if items.count > maxShown {
                Text("+\(items.count - maxShown) more")
                    .font(.system(size: 9)).foregroundStyle(Color.dlMuted)
            }
        }
    }
}

import SwiftUI
import AppKit

struct Placed: Identifiable {
    let occ: Occurrence
    let col: Int
    let cols: Int
    var id: String { occ.id }
}

func placeOccurrences(_ occs: [Occurrence]) -> [Placed] {
    var result: [Placed] = []
    var cluster: [Occurrence] = []
    var clusterEnd = Date.distantPast

    func flush() {
        var colEnds: [Date] = []
        var tmp: [(Occurrence, Int)] = []
        for o in cluster {
            if let i = colEnds.firstIndex(where: { $0 <= o.start }) {
                colEnds[i] = o.end; tmp.append((o, i))
            } else {
                colEnds.append(o.end); tmp.append((o, colEnds.count - 1))
            }
        }
        for (o, c) in tmp { result.append(Placed(occ: o, col: c, cols: colEnds.count)) }
        cluster = []
    }

    for o in occs.sorted(by: { $0.start < $1.start }) {
        if !cluster.isEmpty && o.start >= clusterEnd { flush() }
        clusterEnd = cluster.isEmpty ? o.end : max(clusterEnd, o.end)
        cluster.append(o)
    }
    flush()
    return result
}

// MARK: - Grid
struct TimeGrid: View {
    let days: [Date]
    let selected: Date
    let occurrences: (Date) -> [Occurrence]
    var onSelect: (Date) -> Void
    var onOpen: (Event) -> Void
    var onCreate: (Date, Date) -> Void
    var onReschedule: (Occurrence, Date, Date) -> Void
    var reminders: (Date) -> [Reminder]
    var reminderColor: (Reminder) -> Color
    var onOpenReminder: (Reminder) -> Void

    @State private var activeColumn: Int?
    private let hourH: CGFloat = 56
    private let gutter: CGFloat = 56
    private var cal: Calendar { Calendar.current }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        hourLines
                        GeometryReader { geo in
                            let colW = (geo.size.width - gutter) / CGFloat(days.count)
                            ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                                DayColumn(date: d, occs: occurrences(d), width: colW, hourH: hourH,
                                          isToday: cal.isDateInToday(d),
                                          isSelected: cal.isDate(d, inSameDayAs: selected),
                                          onSelect: { onSelect(d) },
                                          onOpen: onOpen,
                                          onCreate: onCreate,
                                          onReschedule: onReschedule,
                                          onActive: { activeColumn = $0 ? i : nil })
                                    .frame(width: colW, height: hourH * 24)
                                    .offset(x: gutter + CGFloat(i) * colW)
                                    .zIndex(activeColumn == i ? 10 : 0)
                            }
                        }
                        .frame(height: hourH * 24)
                    }
                    .padding(.bottom, 8)
                }
                .onAppear { proxy.scrollTo(7, anchor: .top) }
            }
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 0) {
            Spacer().frame(width: gutter)
            ForEach(days, id: \.self) { d in
                let today = cal.isDateInToday(d)
                VStack(spacing: 6) {
                    VStack(spacing: 4) {
                        Text(d.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.dlMuted)
                        Text("\(cal.component(.day, from: d))")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .background(today ? Color.dlAccent : .clear, in: Circle())
                            .foregroundStyle(today ? .white : Color.dlText)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(d) }

                    ReminderStrip(items: reminders(d), color: reminderColor, onOpen: onOpenReminder)
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.horizontal, 3)
            }
        }
        .padding(.vertical, 10)
    }

    private var hourLines: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { h in
                HStack(alignment: .top, spacing: 8) {
                    Text(String(format: "%02d:00", h))
                        .font(.system(size: 10)).foregroundStyle(Color.dlMuted)
                        .frame(width: gutter - 8, alignment: .trailing)
                        .offset(y: -6)
                    VStack(spacing: 0) { Divider(); Spacer() }
                }
                .frame(height: hourH)
                .id(h)
            }
        }
    }
}

// MARK: - One day column
struct DayColumn: View {
    let date: Date
    let occs: [Occurrence]
    let width: CGFloat
    let hourH: CGFloat
    let isToday: Bool
    let isSelected: Bool
    var onSelect: () -> Void
    var onOpen: (Event) -> Void
    var onCreate: (Date, Date) -> Void
    var onReschedule: (Occurrence, Date, Date) -> Void
    var onActive: (Bool) -> Void

    @State private var ghostTop: CGFloat?
    @State private var ghostBottom: CGFloat = 0

    private var cal: Calendar { Calendar.current }
    private var snapPx: CGFloat { hourH / 4 }

    private func minutesFromMidnight(_ d: Date) -> CGFloat {
        let m = d.timeIntervalSince(cal.startOfDay(for: date)) / 60
        return CGFloat(min(max(m, 0), 1440))
    }

    private func date(atY y: CGFloat) -> Date {
        let mins = min(max(Int((y / hourH * 60).rounded()), 0), 1440)
        return cal.date(byAdding: .minute, value: mins, to: cal.startOfDay(for: date)) ?? date
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(isSelected ? Color.dlAccent.opacity(0.05) : Color.clear)
                .overlay(alignment: .leading) { Rectangle().fill(Color.dlLine).frame(width: 1) }
                .contentShape(Rectangle())
                .onTapGesture(count: 2, coordinateSpace: .local) { p in
                    let top = (p.y / snapPx).rounded(.down) * snapPx
                    onSelect()
                    onCreate(date(atY: top), date(atY: top + hourH))
                }
                .onTapGesture(perform: onSelect)
                .gesture(createGesture)

            if let top = ghostTop { ghostView(top: top, bottom: ghostBottom) }

            ForEach(placeOccurrences(occs)) { p in
                let y = minutesFromMidnight(p.occ.start) / 60 * hourH
                let endY = minutesFromMidnight(p.occ.end) / 60 * hourH
                let h = max(endY - y - 2, snapPx)
                let w = (width - 8) / CGFloat(p.cols)
                DraggableEvent(occ: p.occ,
                               baseY: y + 1, baseH: h,
                               baseX: 4 + CGFloat(p.col) * w, baseW: w - 2,
                               colWidth: width, hourH: hourH,
                               onOpen: onOpen,
                               onReschedule: onReschedule,
                               onActive: onActive)
            }

            if isToday {
                let y = minutesFromMidnight(Date()) / 60 * hourH
                HStack(spacing: 0) {
                    Circle().fill(Color.dlAccent).frame(width: 8, height: 8)
                    Rectangle().fill(Color.dlAccent).frame(height: 1.5)
                }
                .frame(width: width)
                .offset(x: -4, y: y - 4)
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: drag to create
    private var createGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { v in
                let lo = min(v.startLocation.y, v.location.y)
                let hi = max(v.startLocation.y, v.location.y)
                let top = max((lo / snapPx).rounded(.down) * snapPx, 0)
                var bottom = min((hi / snapPx).rounded(.up) * snapPx, hourH * 24)
                if bottom - top < snapPx { bottom = top + snapPx }
                if ghostTop == nil { onActive(true) }
                ghostTop = top
                ghostBottom = bottom
            }
            .onEnded { _ in
                if let top = ghostTop {
                    onSelect()
                    onCreate(date(atY: top), date(atY: ghostBottom))
                }
                ghostTop = nil
                onActive(false)
            }
    }

    private func ghostView(top: CGFloat, bottom: CGFloat) -> some View {
        let a = date(atY: top).formatted(date: .omitted, time: .shortened)
        let b = date(atY: bottom).formatted(date: .omitted, time: .shortened)
        return RoundedRectangle(cornerRadius: 8)
            .fill(Color.dlAccent.opacity(0.16))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.dlAccent, lineWidth: 1.5))
            .overlay(alignment: .topLeading) {
                Text("\(a) – \(b)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.dlAccent)
                    .padding(5)
            }
            .frame(width: width - 8, height: bottom - top)
            .offset(x: 4, y: top)
            .allowsHitTesting(false)
    }
}

// MARK: - Event you can move and resize
struct DraggableEvent: View {
    let occ: Occurrence
    let baseY: CGFloat
    let baseH: CGFloat
    let baseX: CGFloat
    let baseW: CGFloat
    let colWidth: CGFloat
    let hourH: CGFloat
    var onOpen: (Event) -> Void
    var onReschedule: (Occurrence, Date, Date) -> Void
    var onActive: (Bool) -> Void

    private enum Mode { case idle, move, top, bottom }
    @State private var mode: Mode = .idle
    @State private var translation: CGSize = .zero
    @State private var lastSnap = 0

    private var cal: Calendar { Calendar.current }
    private var snapPx: CGFloat { hourH / 4 }

    private func snapped(_ v: CGFloat) -> CGFloat { (v / snapPx).rounded() * snapPx }
    private var dyMinutes: Int { Int((snapped(translation.height) / hourH * 60).rounded()) }
    private var dayDelta: Int { mode == .move ? Int((translation.width / colWidth).rounded()) : 0 }

    private func shift(_ d: Date, minutes: Int, days: Int) -> Date {
        let a = cal.date(byAdding: .minute, value: minutes, to: d) ?? d
        return cal.date(byAdding: .day, value: days, to: a) ?? a
    }

    private var previewStart: Date {
        switch mode {
        case .move:
            return shift(occ.start, minutes: dyMinutes, days: dayDelta)
        case .top:
            return min(shift(occ.start, minutes: dyMinutes, days: 0), occ.end.addingTimeInterval(-900))
        default:
            return occ.start
        }
    }

    private var previewEnd: Date {
        switch mode {
        case .move:
            return previewStart.addingTimeInterval(occ.end.timeIntervalSince(occ.start))
        case .bottom:
            return max(shift(occ.end, minutes: dyMinutes, days: 0), occ.start.addingTimeInterval(900))
        default:
            return occ.end
        }
    }

    private var liveHeight: CGFloat {
        let s = snapped(translation.height)
        switch mode {
        case .bottom: return max(baseH + s, snapPx)
        case .top:    return max(baseH - s, snapPx)
        default:      return baseH
        }
    }

    private var liveY: CGFloat {
        let s = snapped(translation.height)
        switch mode {
        case .move: return baseY + s
        case .top:  return baseY + baseH - liveHeight
        default:    return baseY
        }
    }

    private var liveX: CGFloat { baseX + CGFloat(dayDelta) * colWidth }

    var body: some View {
        EventBlock(event: occ.event, start: previewStart, end: previewEnd, height: liveHeight)
            .frame(width: baseW, height: liveHeight)
            .overlay(alignment: .top) { handle(.top) }
            .overlay(alignment: .bottom) { handle(.bottom) }
            .scaleEffect(mode == .idle ? 1 : 1.02)
            .shadow(color: .black.opacity(mode == .idle ? 0 : 0.2), radius: 10, y: 4)
            .offset(x: liveX, y: liveY)
            .gesture(dragGesture(.move))
            .onTapGesture { onOpen(occ.event) }
    }

    private func handle(_ m: Mode) -> some View {
        Color.clear
            .frame(height: 7)
            .contentShape(Rectangle())
            .pointerStyle(.rowResize)
            .gesture(dragGesture(m))
    }

    private func dragGesture(_ m: Mode) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { v in
                if mode == .idle { mode = m; onActive(true) }
                translation = v.translation
                let key = dyMinutes + dayDelta * 10_000
                if key != lastSnap {
                    lastSnap = key
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                }
            }
            .onEnded { _ in commit() }
    }

    private func commit() {
        let ns = previewStart
        let ne = previewEnd
        let changed = mode != .idle && (ns != occ.start || ne != occ.end)
        mode = .idle
        translation = .zero
        lastSnap = 0
        onActive(false)
        if changed { onReschedule(occ, ns, ne) }
    }
}

// MARK: - Visual block
struct EventBlock: View {
    let event: Event
    let start: Date
    let end: Date
    let height: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(event.dot).frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(event.title).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                    Spacer(minLength: 0)
                    if event.repeatRule != .none {
                        Image(systemName: "repeat").font(.system(size: 9))
                    }
                    if event.importance.rawValue >= Importance.high.rawValue {
                        Image(systemName: "exclamationmark.circle.fill").font(.system(size: 10))
                            .foregroundStyle(event.importance == .critical ? Color.red : event.dot)
                    }
                }
                if height > 34 {
                    Text("\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 10)).foregroundStyle(Color.dlMuted)
                }
                if height > 56, let p = event.place {
                    Text(p).font(.system(size: 10)).foregroundStyle(Color.dlMuted).lineLimit(1)
                }
            }
            .padding(.horizontal, 6).padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .foregroundStyle(Color.dlText.opacity(0.85))
        .background(event.tint)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

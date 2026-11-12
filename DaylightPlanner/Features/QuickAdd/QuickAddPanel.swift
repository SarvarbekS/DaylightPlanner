import SwiftUI
import SwiftData
import AppKit

final class QuickAddPanel: NSPanel {
    var onResign: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func resignKey() { super.resignKey(); onResign?() }
}

@MainActor
final class QuickAddController {
    static let shared = QuickAddController()
    private var panel: QuickAddPanel?

    func toggle() { panel == nil ? show() : hide() }

    func show() {
        guard panel == nil else { return }
        let size = NSSize(width: 600, height: 340)
        let p = QuickAddPanel(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.borderless, .nonactivatingPanel],
                              backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = .floating
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = false
        p.isReleasedWhenClosed = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.onResign = { [weak self] in self?.hide() }

        let root = QuickAddView(onClose: { [weak self] in self?.hide() })
            .modelContainer(Store.container)
        p.contentView = NSHostingView(rootView: root)

        if let sf = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame {
            p.setFrameOrigin(NSPoint(x: sf.midX - size.width / 2,
                                     y: sf.maxY - sf.height * 0.22 - size.height))
        }
        p.makeKeyAndOrderFront(nil)
        panel = p
    }

    func hide() {
        panel?.onResign = nil
        panel?.orderOut(nil)
        panel = nil
    }
}

struct QuickAddView: View {
    @Environment(\.modelContext) private var ctx
    var onClose: () -> Void

    @State private var text = ""
    @State private var result: ParseResult?
    @State private var busy = false
    @FocusState private var focused: Bool

    private var hint: String {
        if busy { return "Esc to cancel" }
        return result == nil ? "Return to parse   ·   Esc to close"
                             : "Return to add   ·   keep typing to change"
    }

    var body: some View {
        VStack(spacing: 12) {
            inputBar

            if busy {
                ThinkingCard()
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if let r = result {
                preview(r)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Text(hint)
                .font(.system(size: 11)).foregroundStyle(Color.dlMuted)
                .shadow(color: .white, radius: 3)
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 600, height: 340, alignment: .top)
        .foregroundStyle(Color.dlText)
        .preferredColorScheme(.light)
        .onAppear { DispatchQueue.main.async { focused = true } }
        .onChange(of: text) { result = nil }
        .onExitCommand(perform: onClose)
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles").foregroundStyle(Color.dlAccent)
            TextField("Dentist next Tuesday 3pm, important", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 20))
                .focused($focused)
                .onSubmit(submit)
        }
        .padding(18)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
        .overlay { if busy { AIGlowBorder() } }
        .shadow(color: .black.opacity(0.18), radius: 20, y: 6)
    }

    private func preview(_ r: ParseResult) -> some View {
        let e = r.event
        let mins = Int(e.end.timeIntervalSince(e.start) / 60)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(e.title).font(.system(size: 16, weight: .semibold))
                Spacer()
                Text(r.source)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.dlLilac, in: Capsule())
            }
            Label(e.start.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute())
                  + " · \(mins) min", systemImage: "calendar")
            HStack(spacing: 14) {
                Label(e.rule.label, systemImage: "repeat")
                Label(e.importance.label, systemImage: "exclamationmark.circle")
                if let p = e.place { Label(p, systemImage: "mappin") }
            }
        }
        .font(.system(size: 13))
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.12), radius: 14, y: 4)
    }

    private func submit() {
        guard !busy else { return }
        if let r = result { save(r.event); return }
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }

        withAnimation(.easeOut(duration: 0.25)) { busy = true }
        Task { @MainActor in
            let started = Date()
            let r = await EventParser.parse(t)

            let remaining = 0.9 - Date().timeIntervalSince(started)
            if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }

            let stillSame = text.trimmingCharacters(in: .whitespacesAndNewlines) == t
            withAnimation(.spring(duration: 0.4)) {
                if stillSame { result = r }
                busy = false
            }
        }
    }

    private func save(_ e: ParsedEvent) {
        ctx.insert(Event(title: e.title, start: e.start, end: e.end, place: e.place,
                         colorKey: "lilac", repeatRule: e.rule, importance: e.importance))
        try? ctx.save()
        NotificationCenter.default.post(name: .eventAdded, object: e.start)
        onClose()
    }
}

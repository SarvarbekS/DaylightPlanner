import SwiftUI
import SwiftData

func colors(for list: String, in lists: [ReminderList]) -> (dot: Color, tint: Color) {
    let key = lists.first(where: { $0.name == list })?.colorKey ?? "lilac"
    return (paletteDot(key), paletteTint(key))
}

enum ListOps {
    @MainActor
    static func ensureDefaults(_ ctx: ModelContext) {
        let existing = (try? ctx.fetch(FetchDescriptor<ReminderList>())) ?? []
        guard existing.isEmpty else { return }
        let defaults: [(String, String)] = [("Personal", "lilac"), ("Work", "blue"),
                                            ("Home", "green"), ("Someday", "peach")]
        var names: [String] = []
        for (i, d) in defaults.enumerated() {
            ctx.insert(ReminderList(name: d.0, colorKey: d.1, order: i))
            names.append(d.0)
        }
        let reminders = (try? ctx.fetch(FetchDescriptor<Reminder>())) ?? []
        for n in Set(reminders.map(\.list)).subtracting(names).sorted() {
            ctx.insert(ReminderList(name: n, colorKey: "rose", order: names.count))
            names.append(n)
        }
    }

    @MainActor
    static func delete(_ list: ReminderList, lists: [ReminderList], reminders: [Reminder], ctx: ModelContext) {
        guard let fallback = lists.filter({ $0 !== list }).sorted(by: { $0.order < $1.order }).first else { return }
        for r in reminders where r.list == list.name { r.list = fallback.name }
        ctx.delete(list)
    }
}

enum ListSheetKind: Identifiable {
    case new
    case edit(ReminderList)
    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let l): return "edit-\(l.persistentModelID.hashValue)"
        }
    }
}

// MARK: - Create / edit sheet
struct ListSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ReminderList.order) private var lists: [ReminderList]
    @Query private var reminders: [Reminder]

    let editing: ReminderList?
    var onRenamed: (String, String) -> Void

    @State private var name: String
    @State private var colorKey: String
    @State private var confirmDelete = false

    init(editing: ReminderList?, onRenamed: @escaping (String, String) -> Void = { _, _ in }) {
        self.editing = editing
        self.onRenamed = onRenamed
        _name = State(initialValue: editing?.name ?? "")
        _colorKey = State(initialValue: editing?.colorKey ?? "lilac")
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var duplicate: Bool {
        lists.contains { $0 !== editing && $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }
    }
    private var fallbackName: String {
        lists.filter { $0 !== editing }.sorted { $0.order < $1.order }.first?.name ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(editing == nil ? "New list" : "Edit list")
                .font(.system(size: 20, weight: .bold))

            TextField("List name", text: $name).textFieldStyle(.roundedBorder)
            if duplicate {
                Text("A list with this name already exists.")
                    .font(.caption).foregroundStyle(Color(hex: 0xD9788A))
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
                if editing != nil {
                    Button("Delete list", role: .destructive) { confirmDelete = true }
                        .disabled(lists.count <= 1)
                }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmed.isEmpty || duplicate)
            }
        }
        .padding(24)
        .frame(width: 400)
        .foregroundStyle(Color.dlText)
        .alert("Delete this list?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                if let l = editing {
                    ListOps.delete(l, lists: lists, reminders: reminders, ctx: ctx)
                }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its reminders will move to \(fallbackName).")
        }
    }

    private func save() {
        if let l = editing {
            let old = l.name
            if old != trimmed {
                for r in reminders where r.list == old { r.list = trimmed }
                l.name = trimmed
                onRenamed(old, trimmed)
            }
            l.colorKey = colorKey
        } else {
            let next = (lists.map(\.order).max() ?? -1) + 1
            ctx.insert(ReminderList(name: trimmed, colorKey: colorKey, order: next))
        }
        dismiss()
    }
}

// MARK: - Sidebar row
struct ListFilterRow: View {
    let list: ReminderList
    let count: Int
    let selected: Bool
    let canDelete: Bool
    var onSelect: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var hover = false

    var body: some View {
        HStack(spacing: 4) {
            HStack(spacing: 10) {
                Circle().fill(paletteDot(list.colorKey)).frame(width: 9, height: 9).frame(width: 20)
                Text(list.name).font(.system(size: 13)).lineLimit(1)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)

            if hover {
                Menu {
                    Button("Edit list…", action: onEdit)
                    Button("Delete list…", role: .destructive, action: onDelete).disabled(!canDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Color.dlMuted)
                        .frame(width: 24, height: 20)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            } else {
                Text("\(count)").font(.system(size: 11)).foregroundStyle(Color.dlMuted)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 9)
        .background(selected ? Color.dlPeach : (hover ? Color.dlBg : Color.clear),
                    in: RoundedRectangle(cornerRadius: 10))
        .onHover { hover = $0 }
        .contextMenu {
            Button("Edit list…", action: onEdit)
            Button("Delete list…", role: .destructive, action: onDelete).disabled(!canDelete)
        }
    }
}

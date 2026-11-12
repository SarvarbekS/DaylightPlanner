import SwiftUI
import SwiftData

enum TodoListSheetKind: Identifiable {
    case new
    case edit(TodoList)
    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let l): return "edit-\(l.persistentModelID.hashValue)"
        }
    }
}

struct TodoView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \TodoList.order) private var lists: [TodoList]
    @Query(sort: \TodoItem.createdAt) private var allItems: [TodoItem]

    @State private var selected: TodoList?        // nil = All tasks
    @State private var listSheet: TodoListSheetKind?
    @State private var pendingDelete: TodoList?
    @State private var quickText = ""
    @State private var quickTarget: TodoList?
    @State private var showCompleted = true
    @State private var pulse = false
    @FocusState private var quickFocused: Bool

    private let blue = Color(hex: 0x7BA3D6)

    // MARK: data
    private var scoped: [TodoItem] {
        guard let s = selected else { return allItems }
        return allItems.filter { $0.list === s }
    }
    private var open: [TodoItem] {
        scoped.filter { !$0.done }.sorted {
            $0.order != $1.order ? $0.order < $1.order : $0.createdAt < $1.createdAt
        }
    }
    private func addTaskTapped() {
        if lists.isEmpty {
            listSheet = .new
            return
        }
        quickFocused = false
        DispatchQueue.main.async {
            quickFocused = true
            withAnimation(.easeOut(duration: 0.2)) { pulse = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(.easeOut(duration: 0.3)) { pulse = false }
            }
        }
    }
    private var done: [TodoItem] {
        scoped.filter { $0.done }.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }
    private var fraction: Double { scoped.isEmpty ? 0 : Double(done.count) / Double(scoped.count) }
    private var target: TodoList? { selected ?? quickTarget ?? lists.first }
    private var title: String { selected?.name ?? "All tasks" }

    private func openCount(_ l: TodoList) -> Int { l.items.filter { !$0.done }.count }

    // MARK: body
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeader(title: "To-do List",
                       subtitle: "Turn the important work into a focused, finishable day.") {
                PrimaryButton(title: "Add task") { addTaskTapped() }
            }

            progressCard

            HStack(alignment: .top, spacing: 20) {
                listsPanel.frame(width: 260)
                tasksPanel
            }
            .frame(maxHeight: .infinity)
        }
        .padding(32)
        .sheet(item: $listSheet) { kind in
            switch kind {
            case .new:
                TodoListSheet(editing: nil, onCreated: { selected = $0 })
            case .edit(let l):
                TodoListSheet(editing: l, onDeleted: { if selected === $0 { selected = nil } })
            }
        }
        .alert("Delete list?", isPresented: Binding(get: { pendingDelete != nil },
                                                    set: { if !$0 { pendingDelete = nil } }),
               presenting: pendingDelete) { l in
            Button("Delete", role: .destructive) {
                if selected === l { selected = nil }
                if quickTarget === l { quickTarget = nil }
                ctx.delete(l)
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { l in
            let n = l.items.count
            Text("\"\(l.name)\" and its \(n) task\(n == 1 ? "" : "s") will be deleted.")
        }
        .task { seedIfNeeded() }
    }

    // MARK: progress
    private var progressCard: some View {
        HStack(spacing: 28) {
            VStack(alignment: .leading, spacing: 4) {
                Text(selected == nil ? "Overall progress" : "\(title) progress")
                    .font(.system(size: 12)).foregroundStyle(Color.dlMuted)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(done.count)").font(.system(size: 30, weight: .semibold))
                    Text("of \(scoped.count) complete").font(.system(size: 13)).foregroundStyle(Color.dlMuted)
                }
            }
            .frame(minWidth: 190, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(scoped.isEmpty ? "Add a task to get started."
                         : open.isEmpty ? "Everything is done. Lovely."
                         : "\(open.count) left to go.")
                        .font(.system(size: 12)).foregroundStyle(Color.dlMuted)
                    Spacer()
                    Text("\(Int(fraction * 100))%")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(blue)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.dlLine)
                        Capsule().fill(blue).frame(width: geo.size.width * fraction)
                            .animation(.snappy, value: fraction)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
    }

    // MARK: lists panel
    private var listsPanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("LISTS").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.dlMuted)
                        .padding(.leading, 8)
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
                .padding(.bottom, 4)

                Button { selected = nil } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "tray.full").frame(width: 20).foregroundStyle(Color.dlText.opacity(0.7))
                        Text("All tasks").font(.system(size: 13))
                        Spacer()
                        Text("\(allItems.filter { !$0.done }.count)")
                            .font(.system(size: 11)).foregroundStyle(Color.dlMuted)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 9)
                    .background(selected == nil ? Color.dlBlue : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                ForEach(lists) { l in
                    TodoListFilterRow(list: l,
                                      count: openCount(l),
                                      selected: selected === l,
                                      onSelect: { selected = l },
                                      onEdit: { listSheet = .edit(l) },
                                      onDelete: { pendingDelete = l })
                }

                if lists.isEmpty {
                    Text("Create a list for anything: groceries, a bucket list, project ideas.")
                        .font(.system(size: 12)).foregroundStyle(Color.dlMuted)
                        .padding(10)
                }
            }
            .padding(16)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
    }

    // MARK: tasks panel
    private var tasksPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 24, weight: .bold))
                Text("\(open.count) open · \(done.count) done")
                    .font(.system(size: 12)).foregroundStyle(Color.dlMuted)
            }
            .padding(.bottom, 10)

            if lists.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle").font(.system(size: 30)).foregroundStyle(Color.dlMuted)
                    Text("Create your first list to start adding tasks.").foregroundStyle(Color.dlMuted)
                    Button("New list") { listSheet = .new }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(open) { item in
                            TodoRow(item: item, lists: lists, showListChip: selected == nil)
                            Divider()
                        }

                        if scoped.isEmpty {
                            emptyState("No tasks yet", "Add your first one below.", "sparkles")
                        } else if open.isEmpty {
                            emptyState("All done", "Nothing left on this list.", "leaf")
                        }

                        if !done.isEmpty {
                            HStack {
                                Button {
                                    withAnimation(.snappy) { showCompleted.toggle() }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                                            .font(.system(size: 9, weight: .bold))
                                        Text("COMPLETED · \(done.count)")
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    .foregroundStyle(Color.dlMuted)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Spacer()
                                Button("Clear") {
                                    for i in done { ctx.delete(i) }
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 11)).foregroundStyle(Color.dlMuted)
                            }
                            .padding(.top, 16).padding(.bottom, 6)

                            if showCompleted {
                                ForEach(done) { item in
                                    TodoRow(item: item, lists: lists, showListChip: selected == nil)
                                    Divider()
                                }
                            }
                        }
                    }
                }

                quickAddBar
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
    }

    private func emptyState(_ title: String, _ sub: String, _ icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 24)).foregroundStyle(Color.dlMuted)
            Text(title).font(.system(size: 14, weight: .medium))
            Text(sub).font(.system(size: 12)).foregroundStyle(Color.dlMuted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 36)
    }

    private var quickAddBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus").foregroundStyle(Color.dlMuted)
            TextField("Add a task and press Return", text: $quickText)
                .textFieldStyle(.plain)
                .focused($quickFocused)
                .onSubmit(quickAdd)

            if selected == nil, lists.count > 1, let t = target {
                Menu {
                    ForEach(lists) { l in
                        Button(l.name) { quickTarget = l }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Circle().fill(paletteDot(t.colorKey)).frame(width: 7, height: 7)
                        Text(t.name).font(.system(size: 11))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.white, in: Capsule())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
        }
        .padding(12)
        .background(Color.dlBg, in: RoundedRectangle(cornerRadius: 12))
        .background(Color.dlBg, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: 0x7BA3D6), lineWidth: pulse ? 2 : 0)
        )
        .padding(.top, 10)
    }

    private func quickAdd() {
        let t = quickText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let list = target else { return }
        let order = (list.items.map(\.order).max() ?? -1) + 1
        let item = TodoItem(title: t, order: order)
        ctx.insert(item)
        item.list = list
        quickText = ""
        quickFocused = true
    }

    // MARK: sample data
    private func seedIfNeeded() {
        guard lists.isEmpty, allItems.isEmpty else { return }
        let mine = TodoList(name: "My tasks", colorKey: "lilac", order: 0)
        let bucket = TodoList(name: "Bucket list", colorKey: "peach", order: 1)
        ctx.insert(mine)
        ctx.insert(bucket)

        func add(_ t: String, to l: TodoList, order: Int, done: Bool = false) {
            let i = TodoItem(title: t, order: order)
            ctx.insert(i)
            i.list = l
            if done { i.done = true; i.completedAt = .now }
        }
        add("Reply to Maya's email", to: mine, order: 0)
        add("Tidy the desk", to: mine, order: 1)
        add("Back up photos", to: mine, order: 2, done: true)
        add("See the northern lights", to: bucket, order: 0)
        add("Run a half marathon", to: bucket, order: 1)
        add("Visit Kyoto in autumn", to: bucket, order: 2)
        add("Learn to surf", to: bucket, order: 3)
    }
}

// MARK: - Task row
struct TodoRow: View {
    @Environment(\.modelContext) private var ctx
    let item: TodoItem
    let lists: [TodoList]
    let showListChip: Bool

    @State private var editing = false
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button { withAnimation(.snappy) { item.toggle() } } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(item.done ? Color(hex: 0x7BA3D6) : Color.clear)
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(item.done ? Color.clear : Color(hex: 0xCFCBDD), lineWidth: 1.5)
                    if item.done {
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

            Group {
                if editing {
                    TextField("Task", text: $draft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .medium))
                        .focused($focused)
                        .onSubmit(commit)
                        .onExitCommand { editing = false }
                } else {
                    Text(item.title)
                        .font(.system(size: 14, weight: .medium))
                        .strikethrough(item.done)
                        .foregroundStyle(item.done ? Color.dlMuted : Color.dlText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture(perform: begin)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showListChip, let l = item.list {
                HStack(spacing: 5) {
                    Circle().fill(paletteDot(l.colorKey)).frame(width: 7, height: 7)
                    Text(l.name).font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(paletteTint(l.colorKey), in: Capsule())
            }

            Menu {
                Button("Rename", action: begin)
                Menu("Move to") {
                    ForEach(lists.filter { $0 !== item.list }) { l in
                        Button(l.name) { item.list = l }
                    }
                }
                Divider()
                Button("Delete", role: .destructive) { ctx.delete(item) }
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
        .padding(.vertical, 4)
        .onChange(of: focused) { _, isFocused in
            if !isFocused && editing { commit() }
        }
    }

    private func begin() {
        draft = item.title
        editing = true
        DispatchQueue.main.async { focused = true }
    }

    private func commit() {
        let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { item.title = t }
        editing = false
    }
}

// MARK: - Sidebar list row
struct TodoListFilterRow: View {
    let list: TodoList
    let count: Int
    let selected: Bool
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
                    Button("Delete list…", role: .destructive, action: onDelete)
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
        .background(selected ? Color.dlBlue : (hover ? Color.dlBg : Color.clear),
                    in: RoundedRectangle(cornerRadius: 10))
        .onHover { hover = $0 }
        .contextMenu {
            Button("Edit list…", action: onEdit)
            Button("Delete list…", role: .destructive, action: onDelete)
        }
    }
}

// MARK: - Create / edit list
struct TodoListSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TodoList.order) private var lists: [TodoList]

    let editing: TodoList?
    var onCreated: (TodoList) -> Void
    var onDeleted: (TodoList) -> Void

    @State private var name: String
    @State private var colorKey: String
    @State private var confirmDelete = false

    init(editing: TodoList?,
         onCreated: @escaping (TodoList) -> Void = { _ in },
         onDeleted: @escaping (TodoList) -> Void = { _ in }) {
        self.editing = editing
        self.onCreated = onCreated
        self.onDeleted = onDeleted
        _name = State(initialValue: editing?.name ?? "")
        _colorKey = State(initialValue: editing?.colorKey ?? "lilac")
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(editing == nil ? "New list" : "Edit list")
                .font(.system(size: 20, weight: .bold))

            TextField("List name (e.g. Bucket list)", text: $name)
                .textFieldStyle(.roundedBorder)

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
                }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmed.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
        .foregroundStyle(Color.dlText)
        .alert("Delete this list?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                if let l = editing {
                    onDeleted(l)
                    ctx.delete(l)
                }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            let n = editing?.items.count ?? 0
            Text("Its \(n) task\(n == 1 ? "" : "s") will be deleted too.")
        }
    }

    private func save() {
        if let l = editing {
            l.name = trimmed
            l.colorKey = colorKey
        } else {
            let next = (lists.map(\.order).max() ?? -1) + 1
            let l = TodoList(name: trimmed, colorKey: colorKey, order: next)
            ctx.insert(l)
            onCreated(l)
        }
        dismiss()
    }
}

import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("settings.reduceAnimations")
    private var reduceAnimations = false

    @Environment(\.accessibilityReduceMotion)
    private var systemReduceMotion
    @Environment(\.modelContext) private var ctx
    @State private var selection: Section = .calendar

    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            Divider()
            HStack(spacing: 0) {
                SidebarView(selection: $selection)
                    .frame(width: 230)
                Divider()
                Group {
                    switch selection {
                    case .calendar:  CalendarView()
                    case .reminders: RemindersView()
                    case .todo: TodoView()
                    case .goals: GoalsView()
                    case .habits: DisciplineView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.dlBg)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 1100, minHeight: 720)
        .foregroundStyle(Color.dlText)
        .transaction { transaction in
            if reduceAnimations || systemReduceMotion {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
        .task { await ListOps.ensureDefaults(ctx) }
    }
}

struct PlaceholderView: View {
    let title: String, subtitle: String, action: String
    var body: some View {
        VStack(alignment: .leading) {
            PageHeader(title: title, subtitle: subtitle) { PrimaryButton(title: action) {} }
            Spacer()
        }.padding(32)
    }
}

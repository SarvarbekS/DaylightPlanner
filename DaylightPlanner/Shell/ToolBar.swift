import SwiftUI

struct TopBar: View {
    var body: some View {
        ZStack {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.dlAccent)
                Text("Daylight Planner")
                    .font(.system(size: 13, weight: .semibold))
            }

            HStack(spacing: 4) {
                Spacer()
                barButton("magnifyingglass") { QuickAddController.shared.toggle() }
                Menu {
                    Button("Quick Add Event") { QuickAddController.shared.toggle() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.dlMuted)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
            .padding(.trailing, 16)
        }
        .frame(height: 52)
        .frame(maxWidth: .infinity)
        .background(Color.dlSidebar)
        .gesture(WindowDragGesture())
    }

    private func barButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.dlMuted)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

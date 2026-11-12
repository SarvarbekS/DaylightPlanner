import SwiftUI

extension Color {
    init(hex: UInt32) {
            self.init(red: Double((hex >> 16) & 0xFF) / 255,
                      green: Double((hex >> 8) & 0xFF) / 255,
                      blue: Double(hex & 0xFF) / 255)
        }
    static let dlAccent  = Color(hex: 0x8B6FD9)
    static let dlInk     = Color(hex: 0x1F1F26)
    static let dlText    = Color(hex: 0x2A2A33)
    static let dlMuted   = Color(hex: 0x8C8C99)
    static let dlBg      = Color(hex: 0xF7F6FB)
    static let dlSidebar = Color(hex: 0xFBFAFD)
    static let dlCard    = Color.white
    static let dlLine    = Color(hex: 0xECEAF3)

    static let dlPeach   = Color(hex: 0xFBE6DC)
    static let dlBlue    = Color(hex: 0xE2EDF9)
    static let dlGreen   = Color(hex: 0xDDF2E5)
    static let dlLilac   = Color(hex: 0xE9E3FA)
    static let dlRose    = Color(hex: 0xFCE4E8)
    static let dlYellow  = Color(hex: 0xFBF1D4)
}

struct Card: ViewModifier {
    var fill: Color = .dlCard
    func body(content: Content) -> some View {
        content.padding(16)
            .background(fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
extension View { func card(_ fill: Color = .dlCard) -> some View { modifier(Card(fill: fill)) } }

struct PrimaryButton: View {
    let title: String; var icon = "plus"; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color.dlInk, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
        }.buttonStyle(.plain)
    }
}

struct PageHeader<Trailing: View>: View {
    let title: String, subtitle: String
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 30, weight: .bold))
                Text(subtitle).foregroundStyle(Color.dlMuted)
            }
            Spacer()
            trailing
        }
    }
}

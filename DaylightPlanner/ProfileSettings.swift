import SwiftUI

// MARK: - Avatar colors

private enum ProfileAvatarColor: String, CaseIterable, Identifiable {
    case peach, lilac, green, blue, rose

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var tint: Color {
        switch self {
        case .peach:
            return Color(red: 0.98, green: 0.90, blue: 0.85)
        case .lilac:
            return Color(red: 0.92, green: 0.88, blue: 0.99)
        case .green:
            return Color(red: 0.86, green: 0.94, blue: 0.88)
        case .blue:
            return Color(red: 0.86, green: 0.92, blue: 0.99)
        case .rose:
            return Color(red: 0.98, green: 0.87, blue: 0.90)
        }
    }

    var foreground: Color {
        switch self {
        case .peach:
            return Color(red: 0.88, green: 0.49, blue: 0.25)
        case .lilac:
            return Color(red: 0.52, green: 0.38, blue: 0.76)
        case .green:
            return Color(red: 0.28, green: 0.56, blue: 0.39)
        case .blue:
            return Color(red: 0.30, green: 0.48, blue: 0.72)
        case .rose:
            return Color(red: 0.73, green: 0.37, blue: 0.48)
        }
    }
}

// MARK: - Shared avatar

struct PlannerProfileAvatar: View {
    let name: String
    let colorKey: String
    var size: CGFloat = 48

    private var avatarColor: ProfileAvatarColor {
        ProfileAvatarColor(rawValue: colorKey) ?? .peach
    }

    private var initials: String {
        let words = name.split(whereSeparator: { $0.isWhitespace })

        let letters: String

        if let first = words.first, let last = words.last,
           words.count > 1 {
            letters = String(first.prefix(1)) + String(last.prefix(1))
        } else {
            letters = String(words.first?.prefix(2) ?? "")
        }

        return letters.isEmpty ? "ME" : letters.uppercased()
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.29, weight: .semibold))
            .foregroundStyle(avatarColor.foreground)
            .frame(width: size, height: size)
            .background(avatarColor.tint, in: Circle())
            .accessibilityHidden(true)
    }
}

// MARK: - Sidebar footer

struct PlannerProfileFooter: View {
    @AppStorage("profile.displayName")
    private var displayName = "Sam"

    @AppStorage("profile.workspaceName")
    private var workspaceName = "Personal workspace"

    @AppStorage("profile.avatarColor")
    private var avatarColor = "peach"

    @AppStorage("profile.showWorkspace")
    private var showWorkspace = true

    @State private var showSettings = false

    private var visibleName: String {
        let trimmed = displayName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return trimmed.isEmpty ? "My profile" : trimmed
    }

    private var visibleWorkspace: String {
        let trimmed = workspaceName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return trimmed.isEmpty ? "Personal workspace" : trimmed
    }

    var body: some View {
        Button {
            showSettings = true
        } label: {
            HStack(spacing: 12) {
                PlannerProfileAvatar(
                    name: visibleName,
                    colorKey: avatarColor
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(visibleName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.dlText)
                        .lineLimit(1)

                    if showWorkspace {
                        Text(visibleWorkspace)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.dlMuted)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.dlMuted)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Profile & Settings")
        .accessibilityLabel("Profile and settings for \(visibleName)")
        .sheet(isPresented: $showSettings) {
            PlannerProfileSettingsView()
        }
    }
}

// MARK: - Profile & Settings panel

struct PlannerProfileSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("profile.displayName")
    private var displayName = "Sam"

    @AppStorage("profile.workspaceName")
    private var workspaceName = "Personal workspace"

    @AppStorage("profile.avatarColor")
    private var avatarColor = "peach"

    @AppStorage("profile.showWorkspace")
    private var showWorkspace = true

    @AppStorage("settings.reduceAnimations")
    private var reduceAnimations = false

    @State private var confirmReset = false

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    profileSection
                    preferencesSection
                    localStorageSection
                }
                .padding(24)
            }

            Divider()

            footer
        }
        .frame(width: 540, height: 650)
        .foregroundStyle(Color.dlText)
        .background(Color.dlBg)
        .preferredColorScheme(.light)
        .alert(
            "Reset profile preferences?",
            isPresented: $confirmReset
        ) {
            Button("Reset", role: .destructive) {
                resetPreferences()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This resets your profile and the preferences shown here. " +
                "Your events, reminders, goals and habit history stay untouched."
            )
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Profile & Settings")
                    .font(.system(size: 22, weight: .semibold))

                Text("Make Daylight feel like your space.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dlMuted)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.dlMuted)
                    .frame(width: 28, height: 28)
                    .background(
                        Color.white,
                        in: RoundedRectangle(cornerRadius: 9)
                    )
            }
            .buttonStyle(.plain)
            .help("Close settings")
            .accessibilityLabel("Close settings")
        }
        .padding(24)
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("Your profile", icon: "person.crop.circle")

            HStack(spacing: 16) {
                PlannerProfileAvatar(
                    name: displayName,
                    colorKey: avatarColor,
                    size: 72
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(
                        displayName.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty ? "My profile" : displayName
                    )
                    .font(.system(size: 18, weight: .semibold))
                    .lineLimit(1)

                    Text("Your initials update with your name.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dlMuted)
                }
            }

            labeledField("Display name", text: $displayName)
            labeledField("Workspace name", text: $workspaceName)

            VStack(alignment: .leading, spacing: 10) {
                Text("Avatar color")
                    .font(.system(size: 12, weight: .medium))

                HStack(spacing: 12) {
                    ForEach(ProfileAvatarColor.allCases) { color in
                        Button {
                            avatarColor = color.rawValue
                        } label: {
                            Circle()
                                .fill(color.tint)
                                .frame(width: 32, height: 32)
                                .overlay {
                                    if avatarColor == color.rawValue {
                                        Image(systemName: "checkmark")
                                            .font(
                                                .system(
                                                    size: 12,
                                                    weight: .bold
                                                )
                                            )
                                            .foregroundStyle(
                                                color.foreground
                                            )
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .help(color.title)
                        .accessibilityLabel(
                            "\(color.title) avatar color"
                        )
                        .accessibilityValue(
                            avatarColor == color.rawValue
                                ? "Selected"
                                : "Not selected"
                        )
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Preferences", icon: "slider.horizontal.3")

            Toggle(
                "Show workspace name in sidebar",
                isOn: $showWorkspace
            )

            Divider()

            Toggle(
                "Reduce animations",
                isOn: $reduceAnimations
            )

            Text("Use simpler transitions throughout the planner.")
                .font(.system(size: 11))
                .foregroundStyle(Color.dlMuted)
            Divider()

            LaunchAtLoginSetting()
        }
        .font(.system(size: 13))
        .toggleStyle(.switch)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private var localStorageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("This Mac", icon: "internaldrive")

            Text("Local personal workspace")
                .font(.system(size: 13, weight: .medium))

            Text(
                "These profile preferences are stored on this Mac. " +
                "No account or cloud sync is connected."
            )
            .font(.system(size: 12))
            .foregroundStyle(Color.dlMuted)

            Button("Reset profile preferences…") {
                confirmReset = true
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.dlAccent)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private var footer: some View {
        HStack {
            Text("Changes save automatically")
                .font(.system(size: 11))
                .foregroundStyle(Color.dlMuted)

            Spacer()

            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .tint(Color.dlAccent)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private func sectionTitle(
        _ title: String,
        icon: String
    ) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.dlText)
    }

    private func labeledField(
        _ title: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))

            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func resetPreferences() {
        displayName = "Sam"
        workspaceName = "Personal workspace"
        avatarColor = "peach"
        showWorkspace = true
        reduceAnimations = false
    }
}

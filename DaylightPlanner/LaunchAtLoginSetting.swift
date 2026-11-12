import SwiftUI
import ServiceManagement

struct LaunchAtLoginSetting: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var status = SMAppService.mainApp.status
    @State private var errorMessage: String?

    private var isRegistered: Bool {
        status == .enabled || status == .requiresApproval
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(
                "Launch Daylight at login",
                isOn: Binding(
                    get: { isRegistered },
                    set: { setEnabled($0) }
                )
            )
            .toggleStyle(.switch)

            Text("Open Daylight Planner when you sign in to this Mac.")
                .font(.system(size: 11))
                .foregroundStyle(Color.dlMuted)

            if status == .requiresApproval {
                Text("Allow Daylight in System Settings to finish enabling it.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dlMuted)

                Button("Open Login Items Settings") {
                    SMAppService.openSystemSettingsLoginItems()
                }
                .buttonStyle(.borderless)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
        .onAppear {
            refreshStatus()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshStatus()
            }
        }
    }

    private func refreshStatus() {
        status = SMAppService.mainApp.status
    }

    private func setEnabled(_ enabled: Bool) {
        errorMessage = nil

        do {
            if enabled {
                switch SMAppService.mainApp.status {
                case .enabled:
                    break

                case .requiresApproval:
                    SMAppService.openSystemSettingsLoginItems()

                default:
                    try SMAppService.mainApp.register()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        refreshStatus()
    }
}

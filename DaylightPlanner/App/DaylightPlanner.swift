import SwiftUI
import SwiftData
import Carbon.HIToolbox

@main
struct DaylightPlannerApp: App {
    init() {
        HotKey.shared.onPress = {
            Task { @MainActor in QuickAddController.shared.toggle() }
        }
        // Control + Option + E
        HotKey.shared.register(keyCode: kVK_ANSI_E, modifiers: controlKey | optionKey)
        Task.detached(priority: .utility) {
            try? await Task.sleep(for: .seconds(5))
            if LocalLLM.enabled { await LocalLLM.shared.warmUp() }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView().preferredColorScheme(.light)
        }
        .modelContainer(Store.container)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1400, height: 900)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Quick Add Event") { QuickAddController.shared.toggle() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
        
        Settings {
                SettingsView()
            }
    }
}

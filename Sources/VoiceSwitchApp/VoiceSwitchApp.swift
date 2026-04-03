import SwiftUI
import VoiceSwitchKit

@main
struct VoiceSwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = VoiceSwitchAppModel(
        settingsStore: UserDefaultsSettingsStore(),
        inputSourceProvider: SystemInputSourceProvider(),
        permissionProvider: SystemPermissionStatusProvider(),
        keyboardEventService: KeyboardEventTapService(permissionProvider: SystemPermissionStatusProvider())
    )

    var body: some Scene {
        MenuBarExtra("VoiceSwitch", systemImage: "waveform.and.mic") {
            StatusMenuView(model: model)
        }

        Settings {
            SettingsView(model: model)
        }

        Window("Logs", id: "logs") {
            LogPanelView(model: model)
        }
    }
}

import SwiftUI
import VoiceSwitchKit

@main
struct VoiceSwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model: VoiceSwitchAppModel = {
        let permissionProvider = SystemPermissionStatusProvider()
        let inputSourceSwitchingService = InputSourceSwitchingService()

        return VoiceSwitchAppModel(
            settingsStore: UserDefaultsSettingsStore(),
            inputSourceProvider: SystemInputSourceProvider(),
            inputSourceSwitchingService: inputSourceSwitchingService,
            inputSourceObservationService: InputSourceObservationService(
                inputSourceSwitchingService: inputSourceSwitchingService
            ),
            permissionProvider: permissionProvider,
            launchAtLoginController: LaunchAtLoginService(),
            keyboardEventService: KeyboardEventTapService(permissionProvider: permissionProvider),
            cooldownScheduler: CooldownScheduler()
        )
    }()

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

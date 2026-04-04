import SwiftUI
import VoiceSwitchKit

@main
struct VoiceSwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model: VoiceSwitchAppModel

    init() {
        let model = {
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

        _model = State(initialValue: model)
        AppDelegate.sharedModel = model
    }

    var body: some Scene {
        MenuBarExtra("VoiceSwitch", systemImage: "waveform.and.mic") {
            StatusMenuView(model: model)
        }

        Window("Logs", id: "logs") {
            LogPanelView(model: model)
        }
    }
}

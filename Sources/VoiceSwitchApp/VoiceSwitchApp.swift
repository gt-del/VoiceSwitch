import SwiftUI
import VoiceSwitchKit
import AppKit

enum VoiceSwitchWindowID {
    static let main = "main"
    static let title = "VoiceSwitch"
}

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
                switchToVoiceScheduler: CooldownScheduler(),
                switchToPrimaryScheduler: CooldownScheduler(),
                cooldownScheduler: CooldownScheduler()
            )
        }()

        _model = State(initialValue: model)
    }

    var body: some Scene {
        Window(VoiceSwitchWindowID.title, id: VoiceSwitchWindowID.main) {
            MainWindowView(model: model)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    model.handleApplicationDidBecomeActive()
                }
        }
        .defaultLaunchBehavior(.suppressed)

        MenuBarExtra("VoiceSwitch", systemImage: "waveform.and.mic") {
            StatusMenuView(model: model)
        }
    }
}

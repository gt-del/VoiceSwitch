import Foundation
import VoiceSwitchKit

@MainActor
func makeVoiceSwitchAppModel(
    settingsStore: SettingsStoring = UserDefaultsSettingsStore(),
    inputSourceProvider: InputSourceProviding = SystemInputSourceProvider(),
    inputSourceSwitchingService: InputSourceSwitching = InputSourceSwitchingService(),
    inputSourceObservationService: InputSourceObserving? = nil,
    permissionProvider: PermissionStatusProviding = SystemPermissionStatusProvider(),
    launchAtLoginController: LaunchAtLoginControlling = LaunchAtLoginService(),
    engineBridge: any EngineBridging = RustEngineBridge(),
    keyboardEventService: KeyboardEventListening? = nil,
    switchToVoiceScheduler: CooldownScheduling = CooldownScheduler(),
    switchToPrimaryScheduler: CooldownScheduling = CooldownScheduler(),
    cooldownScheduler: CooldownScheduling = CooldownScheduler(),
    inputSourceConfirmationScheduler: CooldownScheduling = CooldownScheduler(),
    voiceInputSourceSettleScheduler: CooldownScheduling = CooldownScheduler(),
    nowProvider: @escaping @Sendable () -> Date = Date.init
) -> VoiceSwitchAppModel {
    let resolvedInputSourceObservationService = inputSourceObservationService ?? InputSourceObservationService(
        inputSourceSwitchingService: inputSourceSwitchingService
    )
    let resolvedKeyboardEventService = keyboardEventService ?? KeyboardEventTapService(
        permissionProvider: permissionProvider
    )

    let model = VoiceSwitchAppModel(
        settingsStore: settingsStore,
        inputSourceProvider: inputSourceProvider,
        inputSourceSwitchingService: inputSourceSwitchingService,
        inputSourceObservationService: resolvedInputSourceObservationService,
        permissionProvider: permissionProvider,
        launchAtLoginController: launchAtLoginController,
        engineBridge: engineBridge,
        keyboardEventService: resolvedKeyboardEventService,
        switchToVoiceScheduler: switchToVoiceScheduler,
        switchToPrimaryScheduler: switchToPrimaryScheduler,
        cooldownScheduler: cooldownScheduler,
        inputSourceConfirmationScheduler: inputSourceConfirmationScheduler,
        voiceInputSourceSettleScheduler: voiceInputSourceSettleScheduler,
        nowProvider: nowProvider
    )

    try? model.load()
    return model
}

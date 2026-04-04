import Foundation
import Testing
@testable import VoiceSwitchKit

@MainActor
struct VoiceSwitchAppModelKeyboardEventTests {
    @Test
    func loadStartsKeyboardService() throws {
        let service = StubKeyboardEventService()
        let model = VoiceSwitchAppModel(
            settingsStore: KeyboardTestSettingsStore(initial: .configured),
            inputSourceProvider: KeyboardTestInputSourceProvider(sources: .configuredSources),
            inputSourceSwitchingService: StubKeyboardInputSourceSwitchingService(currentInputSourceID: "com.apple.keylayout.ABC"),
            permissionProvider: KeyboardTestPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .authorized)),
            engineBridge: StubKeyboardEngineBridge(result: .idlePrimaryResult),
            keyboardEventService: service
        )

        try model.load()

        #expect(service.startCallCount == 1)
        #expect(model.eventTapStatus == .running)
    }

    @Test
    func disabledModelDoesNotStartKeyboardService() throws {
        let service = StubKeyboardEventService()
        let model = VoiceSwitchAppModel(
            settingsStore: KeyboardTestSettingsStore(
                initial: VoiceSwitchSettings(
                    primaryInputSourceID: "com.apple.keylayout.ABC",
                    voiceInputSourceID: "com.example.voice",
                    isEnabled: false
                )
            ),
            inputSourceProvider: KeyboardTestInputSourceProvider(sources: .configuredSources),
            inputSourceSwitchingService: StubKeyboardInputSourceSwitchingService(currentInputSourceID: "com.apple.keylayout.ABC"),
            permissionProvider: KeyboardTestPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .authorized)),
            engineBridge: StubKeyboardEngineBridge(result: .idlePrimaryResult),
            keyboardEventService: service
        )

        try model.load()

        #expect(service.startCallCount == 0)
        #expect(model.statusSummary == "已停用")
    }

    @Test
    func disablingModelClearsStaleMonitoringErrorsAndStopsServices() throws {
        let service = StubKeyboardEventService()
        let model = VoiceSwitchAppModel(
            settingsStore: KeyboardTestSettingsStore(initial: .configured),
            inputSourceProvider: KeyboardTestInputSourceProvider(sources: .configuredSources),
            inputSourceSwitchingService: StubKeyboardInputSourceSwitchingService(currentInputSourceID: "com.apple.keylayout.ABC"),
            permissionProvider: KeyboardTestPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .authorized)),
            engineBridge: StubKeyboardEngineBridge(result: .idlePrimaryResult),
            keyboardEventService: service
        )

        try model.load()
        service.emit(.listenerInactive(reason: "Accessibility permission denied"))

        model.setEnabled(false)

        #expect(model.statusSummary == "已停用")
        #expect(model.keyboardMonitoringErrorMessage == nil)
        #expect(model.eventTapStatus == .stopped)
        #expect(service.stopCallCount == 0)
        #expect(model.logEntries.contains { $0.contains("reason=disabled") })
    }

    @Test
    func unavailableConfigurationLogsStopReason() throws {
        let service = StubKeyboardEventService()
        let model = VoiceSwitchAppModel(
            settingsStore: KeyboardTestSettingsStore(initial: .configured),
            inputSourceProvider: KeyboardTestInputSourceProvider(sources: []),
            inputSourceSwitchingService: StubKeyboardInputSourceSwitchingService(currentInputSourceID: "com.apple.keylayout.ABC"),
            permissionProvider: KeyboardTestPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .authorized)),
            engineBridge: StubKeyboardEngineBridge(result: .idlePrimaryResult),
            keyboardEventService: service
        )

        try model.load()

        #expect(model.statusSummary == "不可用")
        #expect(service.stopCallCount >= 1)
        #expect(model.logEntries.contains { $0.contains("reason=stopped_due_to_blocking_issue") })
    }

    @Test
    func keyboardEventIsMappedIntoEngineTransitionAndLogsFullChain() throws {
        let service = StubKeyboardEventService()
        let model = VoiceSwitchAppModel(
            settingsStore: KeyboardTestSettingsStore(initial: .configured),
            inputSourceProvider: KeyboardTestInputSourceProvider(sources: .configuredSources),
            inputSourceSwitchingService: StubKeyboardInputSourceSwitchingService(currentInputSourceID: "com.apple.keylayout.ABC"),
            permissionProvider: KeyboardTestPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .authorized)),
            engineBridge: StubKeyboardEngineBridge(
                result: EngineTransitionResult(
                    state: .voiceMode,
                    action: .switchToVoice,
                    diagnostic: DiagnosticEntry(
                        trigger: "controlPressed",
                        reason: "pressed_control_switch_to_voice",
                        sourceState: .idlePrimary,
                        targetState: .voiceMode
                    ),
                    timer: EngineTimer(kind: .switchToVoiceDelay, delaySeconds: 0.05)
                )
            ),
            keyboardEventService: service
        )

        try model.load()
        service.emit(.controlPressed(keyCode: 59))

        #expect(model.lastInputBehavior == .controlPressed)
        #expect(model.currentEngineState == .voiceMode)
        #expect(model.lastEngineAction == .switchToVoice)
        #expect(model.eventTapStatus == .running)
        #expect(model.lastRawKeyboardEventSummary == "leftControlDown(keyCode:59)")
        #expect(model.logEntries.contains { $0.contains("raw_event=leftControlDown(keyCode:59)") })
        #expect(model.logEntries.contains { $0.contains("trigger=controlPressed") })
        #expect(model.logEntries.contains { $0.contains("target_state=voiceMode") })
        #expect(model.logEntries.contains { $0.contains("reason=pressed_control_switch_to_voice") })
        #expect(model.logEntries.contains { $0.contains("timer_delay_seconds=0.05") })
    }

    @Test
    func leftControlReleaseDoesNotSwitchBackToPrimary() throws {
        let service = StubKeyboardEventService()
        let bridge = RecordingToggleKeyboardEngineBridge()
        let model = VoiceSwitchAppModel(
            settingsStore: KeyboardTestSettingsStore(initial: .configured),
            inputSourceProvider: KeyboardTestInputSourceProvider(sources: .configuredSources),
            inputSourceSwitchingService: StubKeyboardInputSourceSwitchingService(currentInputSourceID: "com.apple.keylayout.ABC"),
            permissionProvider: KeyboardTestPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .authorized)),
            engineBridge: bridge,
            keyboardEventService: service
        )

        try model.load()
        service.emit(.controlPressed(keyCode: 59))
        service.emit(.controlReleased(keyCode: 59))

        #expect(bridge.recordedEvents == [.controlPressed])
        #expect(model.currentEngineState == .voiceMode)
        #expect(model.lastEngineAction == .switchToVoice)
        #expect(model.lastInputBehavior == .controlPressed)
        #expect(model.lastRawKeyboardEventSummary == "leftControlUp(keyCode:59)")
        #expect(model.logEntries.contains { $0.contains("Keyboard raw=leftControlUp(keyCode:59)") })
        #expect(!model.logEntries.contains { $0.contains("trigger=controlReleased") })
    }

    @Test
    func appModelForwardsSecondLeftControlPressWithoutSynthesizingRelease() throws {
        let service = StubKeyboardEventService()
        let bridge = RecordingToggleKeyboardEngineBridge()
        let model = VoiceSwitchAppModel(
            settingsStore: KeyboardTestSettingsStore(initial: .configured),
            inputSourceProvider: KeyboardTestInputSourceProvider(sources: .configuredSources),
            inputSourceSwitchingService: StubKeyboardInputSourceSwitchingService(currentInputSourceID: "com.apple.keylayout.ABC"),
            permissionProvider: KeyboardTestPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .authorized)),
            engineBridge: bridge,
            keyboardEventService: service
        )

        try model.load()
        service.emit(.controlPressed(keyCode: 59))
        service.emit(.controlPressed(keyCode: 59))

        #expect(bridge.recordedEvents == [.controlPressed, .controlPressed])
        #expect(model.currentEngineState == .idlePrimary)
        #expect(model.lastEngineAction == .switchToPrimary)
        #expect(model.lastInputBehavior == .controlPressed)
        #expect(!model.logEntries.contains { $0.contains("trigger=controlReleased") })
    }

    @Test
    func secondLeftControlPressSwitchesBackToPrimary() throws {
        let service = StubKeyboardEventService()
        let model = VoiceSwitchAppModel(
            settingsStore: KeyboardTestSettingsStore(initial: .configured),
            inputSourceProvider: KeyboardTestInputSourceProvider(sources: .configuredSources),
            inputSourceSwitchingService: StubKeyboardInputSourceSwitchingService(currentInputSourceID: "com.apple.keylayout.ABC"),
            permissionProvider: KeyboardTestPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .authorized)),
            engineBridge: ToggleKeyboardEngineBridge(),
            keyboardEventService: service
        )

        try model.load()
        service.emit(.controlPressed(keyCode: 59))
        service.emit(.controlPressed(keyCode: 59))

        #expect(model.currentEngineState == .idlePrimary)
        #expect(model.lastEngineAction == .switchToPrimary)
        #expect(model.lastInputBehavior == .controlPressed)
        #expect(model.logEntries.contains { $0.contains("trigger=controlPressed") })
    }

    @Test
    func permissionDegradePathIsLoggedWithoutEngineTransition() throws {
        let service = StubKeyboardEventService()
        let model = VoiceSwitchAppModel(
            settingsStore: KeyboardTestSettingsStore(initial: .configured),
            inputSourceProvider: KeyboardTestInputSourceProvider(sources: .configuredSources),
            inputSourceSwitchingService: StubKeyboardInputSourceSwitchingService(currentInputSourceID: "com.apple.keylayout.ABC"),
            permissionProvider: KeyboardTestPermissionProvider(current: PermissionSnapshot(accessibility: .denied, inputMonitoring: .unknown)),
            engineBridge: StubKeyboardEngineBridge(result: .idlePrimaryResult),
            keyboardEventService: service
        )

        try model.load()
        model.handleKeyboardEvent(.listenerInactive(reason: "Accessibility permission denied"))

        #expect(model.eventTapStatus == .stopped)
        #expect(model.lastRawKeyboardEventSummary == "listenerInactive(reason:Accessibility permission denied)")
        #expect(model.lastInputBehavior == nil)
        #expect(model.logEntries.contains { $0.contains("listenerInactive(reason:Accessibility permission denied)") })
        #expect(model.keyboardMonitoringErrorMessage?.contains("Accessibility permission denied") == true)
    }

    @Test
    func retryKeyboardMonitoringWithoutPermissionKeepsListenerStopped() throws {
        let service = StubKeyboardEventService()
        let permissions = MutableKeyboardPermissionProvider(
            current: PermissionSnapshot(accessibility: .denied, inputMonitoring: .unknown)
        )
        let model = VoiceSwitchAppModel(
            settingsStore: KeyboardTestSettingsStore(initial: .configured),
            inputSourceProvider: KeyboardTestInputSourceProvider(sources: .configuredSources),
            inputSourceSwitchingService: StubKeyboardInputSourceSwitchingService(currentInputSourceID: "com.apple.keylayout.ABC"),
            permissionProvider: permissions,
            engineBridge: StubKeyboardEngineBridge(result: .idlePrimaryResult),
            keyboardEventService: service
        )

        try model.load()
        model.retryKeyboardMonitoring()

        #expect(model.eventTapStatus == .stopped)
        #expect(model.keyboardMonitoringErrorMessage?.contains("辅助功能权限") == true)
        #expect(model.logEntries.contains { $0.contains("retryResult=skipped") })
    }

    @Test
    func retryKeyboardMonitoringDoesNotRestartHealthyListener() throws {
        let service = StubKeyboardEventService()
        service.isRunning = false
        let permissions = MutableKeyboardPermissionProvider(
            current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .authorized)
        )
        let model = VoiceSwitchAppModel(
            settingsStore: KeyboardTestSettingsStore(initial: .configured),
            inputSourceProvider: KeyboardTestInputSourceProvider(sources: .configuredSources),
            inputSourceSwitchingService: StubKeyboardInputSourceSwitchingService(currentInputSourceID: "com.apple.keylayout.ABC"),
            permissionProvider: permissions,
            engineBridge: StubKeyboardEngineBridge(result: .idlePrimaryResult),
            keyboardEventService: service
        )

        try model.load()
        model.retryKeyboardMonitoring()

        #expect(service.startCallCount == 1)
        #expect(model.eventTapStatus == .running)
        #expect(model.keyboardMonitoringErrorMessage == nil)
        #expect(model.logEntries.contains { $0.contains("reason=already_running") })
    }

    @Test
    func repeatedAutomationRefreshDoesNotDuplicateAutomationStateLogs() throws {
        let service = StubKeyboardEventService()
        let observationService = StubKeyboardInputObservationService()
        let model = VoiceSwitchAppModel(
            settingsStore: KeyboardTestSettingsStore(initial: .configured),
            inputSourceProvider: KeyboardTestInputSourceProvider(sources: .configuredSources),
            inputSourceSwitchingService: StubKeyboardInputSourceSwitchingService(currentInputSourceID: "com.apple.keylayout.ABC"),
            inputSourceObservationService: observationService,
            permissionProvider: KeyboardTestPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .authorized)),
            engineBridge: StubKeyboardEngineBridge(result: .idlePrimaryResult),
            keyboardEventService: service
        )

        try model.load()
        let initialAutomationStateLogs = model.logEntries.filter { $0.contains("trigger=automation_state") }.count

        model.refreshAutomationStateForTesting()
        model.refreshAutomationStateForTesting()

        let finalAutomationStateLogs = model.logEntries.filter { $0.contains("trigger=automation_state") }.count
        #expect(finalAutomationStateLogs == initialAutomationStateLogs)
        #expect(service.startCallCount == 1)
        #expect(observationService.startCallCount == 1)
    }

    @Test
    func repeatedSetEnabledCallsDoNotAddDuplicateAutomationLogs() throws {
        let service = StubKeyboardEventService()
        let observationService = StubKeyboardInputObservationService()
        let model = VoiceSwitchAppModel(
            settingsStore: KeyboardTestSettingsStore(initial: .configured),
            inputSourceProvider: KeyboardTestInputSourceProvider(sources: .configuredSources),
            inputSourceSwitchingService: StubKeyboardInputSourceSwitchingService(currentInputSourceID: "com.apple.keylayout.ABC"),
            inputSourceObservationService: observationService,
            permissionProvider: KeyboardTestPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .authorized)),
            engineBridge: StubKeyboardEngineBridge(result: .idlePrimaryResult),
            keyboardEventService: service
        )

        try model.load()
        model.setEnabled(false)
        let afterFirstDisable = model.logEntries.filter { $0.contains("trigger=automation_state") }.count

        model.setEnabled(false)
        let afterSecondDisable = model.logEntries.filter { $0.contains("trigger=automation_state") }.count

        #expect(afterSecondDisable == afterFirstDisable)

        model.setEnabled(true)
        let afterFirstEnable = model.logEntries.filter { $0.contains("trigger=automation_state") }.count

        model.setEnabled(true)
        let afterSecondEnable = model.logEntries.filter { $0.contains("trigger=automation_state") }.count

        #expect(afterSecondEnable == afterFirstEnable)
        #expect(observationService.startCallCount == 2)
    }

    @Test
    func retryKeyboardMonitoringWhileHealthyDoesNotAddAutomationStateLogs() throws {
        let service = StubKeyboardEventService()
        let model = VoiceSwitchAppModel(
            settingsStore: KeyboardTestSettingsStore(initial: .configured),
            inputSourceProvider: KeyboardTestInputSourceProvider(sources: .configuredSources),
            inputSourceSwitchingService: StubKeyboardInputSourceSwitchingService(currentInputSourceID: "com.apple.keylayout.ABC"),
            permissionProvider: KeyboardTestPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .authorized)),
            engineBridge: StubKeyboardEngineBridge(result: .idlePrimaryResult),
            keyboardEventService: service
        )

        try model.load()
        let initialAutomationStateLogs = model.logEntries.filter { $0.contains("trigger=automation_state") }.count

        model.retryKeyboardMonitoring()

        let finalAutomationStateLogs = model.logEntries.filter { $0.contains("trigger=automation_state") }.count
        #expect(finalAutomationStateLogs == initialAutomationStateLogs)
        #expect(model.logEntries.contains { $0.contains("retryResult=skipped") && $0.contains("reason=already_running") })
        #expect(!model.logEntries.contains { $0.contains("trigger=automation_state") && ($0.contains("reason=restarted") || $0.contains("reason=running")) && finalAutomationStateLogs > initialAutomationStateLogs })
    }

    @Test
    func repeatedStoppedRefreshDoesNotRepeatStopOrAutomationStateLogs() throws {
        let service = StubKeyboardEventService()
        let observationService = StubKeyboardInputObservationService()
        let model = VoiceSwitchAppModel(
            settingsStore: KeyboardTestSettingsStore(initial: .configured),
            inputSourceProvider: KeyboardTestInputSourceProvider(sources: .configuredSources),
            inputSourceSwitchingService: StubKeyboardInputSourceSwitchingService(currentInputSourceID: "com.apple.keylayout.ABC"),
            inputSourceObservationService: observationService,
            permissionProvider: KeyboardTestPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .authorized)),
            engineBridge: StubKeyboardEngineBridge(result: .idlePrimaryResult),
            keyboardEventService: service
        )

        try model.load()
        model.setEnabled(false)
        let stopCallsAfterDisable = service.stopCallCount
        let automationStateLogsAfterDisable = model.logEntries.filter { $0.contains("trigger=automation_state") }.count

        model.refreshAutomationStateForTesting()
        model.refreshAutomationStateForTesting()

        let finalAutomationStateLogs = model.logEntries.filter { $0.contains("trigger=automation_state") }.count
        #expect(service.stopCallCount == stopCallsAfterDisable)
        #expect(observationService.stopCallCount == 1)
        #expect(finalAutomationStateLogs == automationStateLogsAfterDisable)
    }

    @Test
    func retryKeyboardMonitoringWithoutInputMonitoringPermissionKeepsListenerStopped() throws {
        let service = StubKeyboardEventService()
        let permissions = MutableKeyboardPermissionProvider(
            current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .denied)
        )
        let model = VoiceSwitchAppModel(
            settingsStore: KeyboardTestSettingsStore(initial: .configured),
            inputSourceProvider: KeyboardTestInputSourceProvider(sources: .configuredSources),
            inputSourceSwitchingService: StubKeyboardInputSourceSwitchingService(currentInputSourceID: "com.apple.keylayout.ABC"),
            permissionProvider: permissions,
            engineBridge: StubKeyboardEngineBridge(result: .idlePrimaryResult),
            keyboardEventService: service
        )

        try model.load()
        model.retryKeyboardMonitoring()

        #expect(model.eventTapStatus == .stopped)
        #expect(model.keyboardMonitoringErrorMessage?.contains("输入监听权限") == true)
        #expect(model.logEntries.contains { $0.contains("retryResult=skipped") })
    }

    @Test
    func appActivationAutomaticallyRestartsListenerAfterPermissionRecovery() throws {
        let service = StubKeyboardEventService()
        service.isRunning = false
        let permissions = MutableKeyboardPermissionProvider(
            current: PermissionSnapshot(accessibility: .denied, inputMonitoring: .denied)
        )
        let model = VoiceSwitchAppModel(
            settingsStore: KeyboardTestSettingsStore(initial: .configured),
            inputSourceProvider: KeyboardTestInputSourceProvider(sources: .configuredSources),
            inputSourceSwitchingService: StubKeyboardInputSourceSwitchingService(currentInputSourceID: "com.apple.keylayout.ABC"),
            permissionProvider: permissions,
            engineBridge: StubKeyboardEngineBridge(result: .idlePrimaryResult),
            keyboardEventService: service
        )

        try model.load()
        #expect(model.eventTapStatus == .stopped)

        permissions.current = PermissionSnapshot(accessibility: .authorized, inputMonitoring: .authorized)
        service.isRunning = true
        model.handleApplicationDidBecomeActive()

        #expect(service.startCallCount == 1)
        #expect(model.eventTapStatus == .running)
        #expect(model.keyboardMonitoringErrorMessage == nil)
        #expect(model.logEntries.contains { $0.contains("trigger=app_activation") })
        #expect(model.logEntries.contains { $0.contains("reason=permissions_recovered") })
    }

    @Test
    func appActivationRefreshesDeniedPermissionsWithoutManualRetry() throws {
        let service = StubKeyboardEventService()
        let permissions = MutableKeyboardPermissionProvider(
            current: PermissionSnapshot(accessibility: .denied, inputMonitoring: .denied)
        )
        let model = VoiceSwitchAppModel(
            settingsStore: KeyboardTestSettingsStore(initial: .configured),
            inputSourceProvider: KeyboardTestInputSourceProvider(sources: .configuredSources),
            inputSourceSwitchingService: StubKeyboardInputSourceSwitchingService(currentInputSourceID: "com.apple.keylayout.ABC"),
            permissionProvider: permissions,
            engineBridge: StubKeyboardEngineBridge(result: .idlePrimaryResult),
            keyboardEventService: service
        )

        try model.load()
        model.handleApplicationDidBecomeActive()

        #expect(model.eventTapStatus == .stopped)
        #expect(model.keyboardMonitoringErrorMessage?.contains("权限") == true)
        #expect(model.logEntries.contains { $0.contains("trigger=app_activation") })
        #expect(model.logEntries.contains { $0.contains("reason=permissions_still_blocked") })
    }

    @Test
    func realKeyboardEventClearsStalePermissionError() throws {
        let service = StubKeyboardEventService()
        let model = VoiceSwitchAppModel(
            settingsStore: KeyboardTestSettingsStore(initial: .configured),
            inputSourceProvider: KeyboardTestInputSourceProvider(sources: .configuredSources),
            inputSourceSwitchingService: StubKeyboardInputSourceSwitchingService(currentInputSourceID: "com.apple.keylayout.ABC"),
            permissionProvider: KeyboardTestPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .authorized)),
            engineBridge: StubKeyboardEngineBridge(
                result: EngineTransitionResult(
                    state: .voiceMode,
                    action: .switchToVoice,
                    diagnostic: DiagnosticEntry(
                        trigger: "controlPressed",
                        reason: "pressed_control_switch_to_voice",
                        sourceState: .idlePrimary,
                        targetState: .voiceMode
                    )
                )
            ),
            keyboardEventService: service
        )

        try model.load()
        service.emit(.listenerInactive(reason: "Accessibility permission denied"))
        #expect(model.keyboardMonitoringErrorMessage == "listenerInactive(reason:Accessibility permission denied)")

        service.emit(.controlPressed(keyCode: 58))

        #expect(model.eventTapStatus == .running)
        #expect(model.keyboardMonitoringErrorMessage == nil)
    }
}

private extension VoiceSwitchSettings {
    static let configured = VoiceSwitchSettings(
        primaryInputSourceID: "com.apple.keylayout.ABC",
        voiceInputSourceID: "com.example.voice"
    )
}

private extension [InputSourceDescriptor] {
    static let configuredSources = [
        InputSourceDescriptor(id: "com.apple.keylayout.ABC", displayName: "ABC", isSelected: true),
        InputSourceDescriptor(id: "com.example.voice", displayName: "Voice", isSelected: false),
    ]
}

private final class StubKeyboardEventService: KeyboardEventListening, @unchecked Sendable {
    private var handler: ((KeyboardEventSummary) -> Void)?
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    var isRunning = true

    func start(eventHandler: @escaping @Sendable (KeyboardEventSummary) -> Void) {
        startCallCount += 1
        isRunning = true
        handler = eventHandler
    }

    func stop() {
        stopCallCount += 1
        isRunning = false
    }

    func emit(_ summary: KeyboardEventSummary) {
        switch summary {
        case .listenerInactive, .tapDisabled:
            isRunning = false
        case .tapRecoveryAttempted, .controlPressed, .controlReleased, .typingKey:
            isRunning = true
        }
        handler?(summary)
    }
}

private final class StubKeyboardInputSourceSwitchingService: InputSourceSwitching, @unchecked Sendable {
    let currentInputSourceID: String?

    init(currentInputSourceID: String?) {
        self.currentInputSourceID = currentInputSourceID
    }

    func currentSelectedInputSourceID() throws -> String? {
        currentInputSourceID
    }

    func switchToInputSource(id: String) throws {}
}

private final class StubKeyboardInputObservationService: InputSourceObserving, @unchecked Sendable {
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private var changeHandler: ((InputSourceObservation) -> Void)?

    func start(changeHandler: @escaping @Sendable (InputSourceObservation) -> Void) {
        startCallCount += 1
        self.changeHandler = changeHandler
    }

    func stop() {
        stopCallCount += 1
        changeHandler = nil
    }
}

private struct StubKeyboardEngineBridge: EngineBridging {
    let result: EngineTransitionResult

    func transition(
        from currentState: EngineState,
        event: InputBehavior,
        configuration: EngineConfiguration
    ) throws -> EngineTransitionResult {
        result
    }
}

private struct ToggleKeyboardEngineBridge: EngineBridging {
    func transition(
        from currentState: EngineState,
        event: InputBehavior,
        configuration: EngineConfiguration
    ) throws -> EngineTransitionResult {
        switch (currentState, event) {
        case (.idlePrimary, .controlPressed):
            return EngineTransitionResult(
                state: .voiceMode,
                action: .switchToVoice,
                diagnostic: DiagnosticEntry(
                    trigger: "controlPressed",
                    reason: "pressed_control_switch_to_voice",
                    sourceState: .idlePrimary,
                    targetState: .voiceMode
                )
            )
        case (.voiceMode, .controlPressed):
            return EngineTransitionResult(
                state: .idlePrimary,
                action: .switchToPrimary,
                diagnostic: DiagnosticEntry(
                    trigger: "controlPressed",
                    reason: "pressed_control_switch_to_primary",
                    sourceState: .voiceMode,
                    targetState: .idlePrimary
                )
            )
        case (.voiceMode, .controlReleased):
            return EngineTransitionResult(
                state: .voiceMode,
                action: .noOp,
                diagnostic: DiagnosticEntry(
                    trigger: "controlReleased",
                    reason: "ignored_event_in_current_state",
                    sourceState: .voiceMode,
                    targetState: .voiceMode
                )
            )
        default:
            return .idlePrimaryResult
        }
    }
}

private final class RecordingToggleKeyboardEngineBridge: EngineBridging, @unchecked Sendable {
    private(set) var recordedEvents: [InputBehavior] = []

    func transition(
        from currentState: EngineState,
        event: InputBehavior,
        configuration: EngineConfiguration
    ) throws -> EngineTransitionResult {
        recordedEvents.append(event)

        switch (currentState, event) {
        case (.idlePrimary, .controlPressed):
            return EngineTransitionResult(
                state: .voiceMode,
                action: .switchToVoice,
                diagnostic: DiagnosticEntry(
                    trigger: "controlPressed",
                    reason: "pressed_control_switch_to_voice",
                    sourceState: .idlePrimary,
                    targetState: .voiceMode
                )
            )
        case (.voiceMode, .controlPressed):
            return EngineTransitionResult(
                state: .idlePrimary,
                action: .switchToPrimary,
                diagnostic: DiagnosticEntry(
                    trigger: "controlPressed",
                    reason: "pressed_control_switch_to_primary",
                    sourceState: .voiceMode,
                    targetState: .idlePrimary
                )
            )
        case (.voiceMode, .controlReleased):
            return EngineTransitionResult(
                state: .voiceMode,
                action: .noOp,
                diagnostic: DiagnosticEntry(
                    trigger: "controlReleased",
                    reason: "ignored_event_in_current_state",
                    sourceState: .voiceMode,
                    targetState: .voiceMode
                )
            )
        default:
            return .idlePrimaryResult
        }
    }
}

private final class KeyboardTestSettingsStore: SettingsStoring, @unchecked Sendable {
    private let initial: VoiceSwitchSettings

    init(initial: VoiceSwitchSettings) {
        self.initial = initial
    }

    func load() -> VoiceSwitchSettings {
        initial
    }

    func save(_ settings: VoiceSwitchSettings, availableInputSourceIDs: Set<String>?) throws {}
}

private struct KeyboardTestInputSourceProvider: InputSourceProviding, Sendable {
    let sources: [InputSourceDescriptor]

    func selectableInputSources() throws -> [InputSourceDescriptor] {
        sources
    }
}

private struct KeyboardTestPermissionProvider: PermissionStatusProviding, Sendable {
    let current: PermissionSnapshot

    func snapshot() -> PermissionSnapshot {
        current
    }
}

private final class MutableKeyboardPermissionProvider: PermissionStatusProviding, @unchecked Sendable {
    var current: PermissionSnapshot

    init(current: PermissionSnapshot) {
        self.current = current
    }

    func snapshot() -> PermissionSnapshot {
        current
    }

    func requestAccessibilityAuthorization() -> PermissionSnapshot {
        current
    }

    func requestInputMonitoringAuthorization() -> PermissionSnapshot {
        current
    }
}

private extension EngineTransitionResult {
    static let idlePrimaryResult = EngineTransitionResult(
        state: .idlePrimary,
        action: .noOp,
        diagnostic: DiagnosticEntry(
            trigger: "ignored",
            reason: "no_state_change",
            sourceState: .idlePrimary,
            targetState: .idlePrimary
        )
    )
}

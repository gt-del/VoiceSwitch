import Foundation
import Testing
@testable import VoiceSwitchKit

@MainActor
struct VoiceSwitchAppModelCooldownTests {
    @Test
    func userManualSwitchEntersCooldown() throws {
        let switchingService = CooldownTestInputSourceSwitchingService(currentInputSourceID: "com.apple.keylayout.ABC")
        let observationService = StubInputSourceObservationService()
        let scheduler = StubCooldownScheduler()
        let clock = MutableNowProvider(now: Date(timeIntervalSince1970: 1_000))
        let model = VoiceSwitchAppModel(
            settingsStore: CooldownTestSettingsStore(
                initial: VoiceSwitchSettings(
                    primaryInputSourceID: "com.apple.keylayout.ABC",
                    voiceInputSourceID: "com.example.voice"
                )
            ),
            inputSourceProvider: CooldownTestInputSourceProvider(
                sources: [
                    InputSourceDescriptor(id: "com.apple.keylayout.ABC", displayName: "ABC", isSelected: true),
                    InputSourceDescriptor(id: "com.example.voice", displayName: "Voice", isSelected: false),
                ]
            ),
            inputSourceSwitchingService: switchingService,
            inputSourceObservationService: observationService,
            permissionProvider: CooldownTestPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .unknown)),
            engineBridge: RuleBasedCooldownEngineBridge(),
            cooldownScheduler: scheduler,
            nowProvider: clock.now
        )

        try model.load()
        observationService.emit(.changed(inputSourceID: "com.apple.keylayout.US", rawDescription: "inputSourceChanged(id:com.apple.keylayout.US)"))

        #expect(model.lastInputBehavior == .manualSwitchDetected)
        #expect(model.currentEngineState == .cooldown)
        #expect(model.lastEngineAction == .enterCooldown)
        #expect(model.isCooldownActive)
        #expect(model.cooldownDeadline == Date(timeIntervalSince1970: 1_005))
        #expect(scheduler.scheduleCallCount == 1)
        #expect(model.logEntries.contains { $0.contains("origin=manual") })
        #expect(model.logEntries.contains { $0.contains("reason=cooldown_started") })
    }

    @Test
    func programmaticSwitchIsNotMisclassifiedAsManual() throws {
        let switchingService = CooldownTestInputSourceSwitchingService(currentInputSourceID: "com.apple.keylayout.ABC")
        let observationService = StubInputSourceObservationService()
        let scheduler = StubCooldownScheduler()
        let clock = MutableNowProvider(now: Date(timeIntervalSince1970: 2_000))
        let model = VoiceSwitchAppModel(
            settingsStore: CooldownTestSettingsStore(
                initial: VoiceSwitchSettings(
                    primaryInputSourceID: "com.apple.keylayout.ABC",
                    voiceInputSourceID: "com.example.voice"
                )
            ),
            inputSourceProvider: CooldownTestInputSourceProvider(
                sources: [
                    InputSourceDescriptor(id: "com.apple.keylayout.ABC", displayName: "ABC", isSelected: true),
                    InputSourceDescriptor(id: "com.example.voice", displayName: "Voice", isSelected: false),
                ]
            ),
            inputSourceSwitchingService: switchingService,
            inputSourceObservationService: observationService,
            permissionProvider: CooldownTestPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .unknown)),
            engineBridge: RuleBasedCooldownEngineBridge(),
            cooldownScheduler: scheduler,
            nowProvider: clock.now
        )

        try model.load()
        try model.sendTestEvent(.optionPressed)
        try model.sendTestEvent(.optionWindowExpired)
        observationService.emit(.changed(inputSourceID: "com.example.voice", rawDescription: "inputSourceChanged(id:com.example.voice)"))

        #expect(model.lastInputBehavior == .optionWindowExpired)
        #expect(model.currentEngineState == .voiceActive)
        #expect(!model.isCooldownActive)
        #expect(scheduler.scheduleCallCount == 0)
        #expect(model.logEntries.contains { $0.contains("origin=programmatic") })
    }

    @Test
    func cooldownExpirySendsCooldownExpired() throws {
        let switchingService = CooldownTestInputSourceSwitchingService(currentInputSourceID: "com.apple.keylayout.ABC")
        let observationService = StubInputSourceObservationService()
        let scheduler = StubCooldownScheduler()
        let clock = MutableNowProvider(now: Date(timeIntervalSince1970: 3_000))
        let model = VoiceSwitchAppModel(
            settingsStore: CooldownTestSettingsStore(
                initial: VoiceSwitchSettings(
                    primaryInputSourceID: "com.apple.keylayout.ABC",
                    voiceInputSourceID: "com.example.voice"
                )
            ),
            inputSourceProvider: CooldownTestInputSourceProvider(
                sources: [
                    InputSourceDescriptor(id: "com.apple.keylayout.ABC", displayName: "ABC", isSelected: true),
                    InputSourceDescriptor(id: "com.example.voice", displayName: "Voice", isSelected: false),
                ]
            ),
            inputSourceSwitchingService: switchingService,
            inputSourceObservationService: observationService,
            permissionProvider: CooldownTestPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .unknown)),
            engineBridge: RuleBasedCooldownEngineBridge(),
            cooldownScheduler: scheduler,
            nowProvider: clock.now
        )

        try model.load()
        observationService.emit(.changed(inputSourceID: "com.apple.keylayout.US", rawDescription: "inputSourceChanged(id:com.apple.keylayout.US)"))
        clock.current = Date(timeIntervalSince1970: 3_005)
        scheduler.fire()

        #expect(model.lastInputBehavior == .cooldownExpired)
        #expect(model.currentEngineState == .idlePrimary)
        #expect(!model.isCooldownActive)
        #expect(model.cooldownDeadline == nil)
        #expect(model.logEntries.contains { $0.contains("cooldownExpired") })
    }

    @Test
    func cooldownSuppressesAutomaticSwitches() throws {
        let switchingService = CooldownTestInputSourceSwitchingService(currentInputSourceID: "com.apple.keylayout.ABC")
        let observationService = StubInputSourceObservationService()
        let scheduler = StubCooldownScheduler()
        let clock = MutableNowProvider(now: Date(timeIntervalSince1970: 4_000))
        let model = VoiceSwitchAppModel(
            settingsStore: CooldownTestSettingsStore(
                initial: VoiceSwitchSettings(
                    primaryInputSourceID: "com.apple.keylayout.ABC",
                    voiceInputSourceID: "com.example.voice"
                )
            ),
            inputSourceProvider: CooldownTestInputSourceProvider(
                sources: [
                    InputSourceDescriptor(id: "com.apple.keylayout.ABC", displayName: "ABC", isSelected: true),
                    InputSourceDescriptor(id: "com.example.voice", displayName: "Voice", isSelected: false),
                ]
            ),
            inputSourceSwitchingService: switchingService,
            inputSourceObservationService: observationService,
            permissionProvider: CooldownTestPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .unknown)),
            engineBridge: RuleBasedCooldownEngineBridge(),
            cooldownScheduler: scheduler,
            nowProvider: clock.now
        )

        try model.load()
        observationService.emit(.changed(inputSourceID: "com.apple.keylayout.US", rawDescription: "inputSourceChanged(id:com.apple.keylayout.US)"))
        try model.sendTestEvent(.optionWindowExpired)

        #expect(switchingService.switchCalls.isEmpty)
        #expect(model.currentEngineState == .cooldown)
        #expect(model.logEntries.contains { $0.contains("reason=cooldown_skipped_automatic_switch") })
    }

    @Test
    func consecutiveManualSwitchesResetCooldown() throws {
        let switchingService = CooldownTestInputSourceSwitchingService(currentInputSourceID: "com.apple.keylayout.ABC")
        let observationService = StubInputSourceObservationService()
        let scheduler = StubCooldownScheduler()
        let clock = MutableNowProvider(now: Date(timeIntervalSince1970: 5_000))
        let model = VoiceSwitchAppModel(
            settingsStore: CooldownTestSettingsStore(
                initial: VoiceSwitchSettings(
                    primaryInputSourceID: "com.apple.keylayout.ABC",
                    voiceInputSourceID: "com.example.voice"
                )
            ),
            inputSourceProvider: CooldownTestInputSourceProvider(
                sources: [
                    InputSourceDescriptor(id: "com.apple.keylayout.ABC", displayName: "ABC", isSelected: true),
                    InputSourceDescriptor(id: "com.example.voice", displayName: "Voice", isSelected: false),
                ]
            ),
            inputSourceSwitchingService: switchingService,
            inputSourceObservationService: observationService,
            permissionProvider: CooldownTestPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .unknown)),
            engineBridge: RuleBasedCooldownEngineBridge(),
            cooldownScheduler: scheduler,
            nowProvider: clock.now
        )

        try model.load()
        observationService.emit(.changed(inputSourceID: "com.apple.keylayout.US", rawDescription: "inputSourceChanged(id:com.apple.keylayout.US)"))
        clock.current = Date(timeIntervalSince1970: 5_002)
        observationService.emit(.changed(inputSourceID: "com.apple.keylayout.Japanese", rawDescription: "inputSourceChanged(id:com.apple.keylayout.Japanese)"))

        #expect(model.isCooldownActive)
        #expect(model.cooldownDeadline == Date(timeIntervalSince1970: 5_007))
        #expect(scheduler.scheduleCallCount == 2)
        #expect(model.logEntries.contains { $0.contains("reason=cooldown_reset") })
    }
}

private struct RuleBasedCooldownEngineBridge: EngineBridging {
    func transition(
        from currentState: EngineState,
        event: InputBehavior,
        configuration: EngineConfiguration
    ) throws -> EngineTransitionResult {
        switch (currentState, event) {
        case (.idlePrimary, .optionPressed):
            return EngineTransitionResult(
                state: .optionPending,
                action: .noOp,
                diagnostic: DiagnosticEntry(
                    trigger: "optionPressed",
                    reason: "entered_option_pending",
                    sourceState: .idlePrimary,
                    targetState: .optionPending
                )
            )
        case (.optionPending, .optionWindowExpired):
            return EngineTransitionResult(
                state: .voiceActive,
                action: .switchToVoice,
                diagnostic: DiagnosticEntry(
                    trigger: "optionWindowExpired",
                    reason: "activated_voice_after_option_window",
                    sourceState: .optionPending,
                    targetState: .voiceActive
                )
            )
        case (_, .manualSwitchDetected):
            return EngineTransitionResult(
                state: .cooldown,
                action: .enterCooldown,
                diagnostic: DiagnosticEntry(
                    trigger: "manualSwitchDetected",
                    reason: "entered_cooldown_after_manual_switch",
                    sourceState: currentState,
                    targetState: .cooldown
                ),
                timer: EngineTimer(kind: .cooldown, delaySeconds: configuration.cooldownDuration)
            )
        case (.cooldown, .cooldownExpired):
            return EngineTransitionResult(
                state: .idlePrimary,
                action: .noOp,
                diagnostic: DiagnosticEntry(
                    trigger: "cooldownExpired",
                    reason: "cooldown_expired",
                    sourceState: .cooldown,
                    targetState: .idlePrimary
                )
            )
        case (.cooldown, _):
            return EngineTransitionResult(
                state: .cooldown,
                action: .noOp,
                diagnostic: DiagnosticEntry(
                    trigger: event.rawValue,
                    reason: "ignored_event_in_current_state",
                    sourceState: .cooldown,
                    targetState: .cooldown
                )
            )
        default:
            return EngineTransitionResult(
                state: currentState,
                action: .noOp,
                diagnostic: DiagnosticEntry(
                    trigger: event.rawValue,
                    reason: "no_state_change",
                    sourceState: currentState,
                    targetState: currentState
                )
            )
        }
    }
}

private final class StubInputSourceObservationService: InputSourceObserving, @unchecked Sendable {
    private var handler: ((InputSourceObservation) -> Void)?

    func start(changeHandler: @escaping @Sendable (InputSourceObservation) -> Void) {
        handler = changeHandler
    }

    func stop() {
        handler = nil
    }

    func emit(_ observation: InputSourceObservation) {
        handler?(observation)
    }
}

private final class StubCooldownScheduler: CooldownScheduling, @unchecked Sendable {
    private(set) var scheduleCallCount = 0
    private var handler: (() -> Void)?

    func schedule(deadline: Date, onFire: @escaping @Sendable () -> Void) {
        scheduleCallCount += 1
        handler = onFire
    }

    func cancel() {
        handler = nil
    }

    func fire() {
        handler?()
    }
}

private final class MutableNowProvider: @unchecked Sendable {
    var current: Date

    init(now: Date) {
        self.current = now
    }

    func now() -> Date {
        current
    }
}

private final class CooldownTestInputSourceSwitchingService: InputSourceSwitching, @unchecked Sendable {
    var currentInputSourceID: String?
    var switchCalls: [String] = []

    init(currentInputSourceID: String?) {
        self.currentInputSourceID = currentInputSourceID
    }

    func currentSelectedInputSourceID() throws -> String? {
        currentInputSourceID
    }

    func switchToInputSource(id: String) throws {
        switchCalls.append(id)
        currentInputSourceID = id
    }
}

private final class CooldownTestSettingsStore: SettingsStoring, @unchecked Sendable {
    private let initial: VoiceSwitchSettings

    init(initial: VoiceSwitchSettings) {
        self.initial = initial
    }

    func load() -> VoiceSwitchSettings {
        initial
    }

    func save(_ settings: VoiceSwitchSettings) {}
}

private struct CooldownTestInputSourceProvider: InputSourceProviding, Sendable {
    let sources: [InputSourceDescriptor]

    func selectableInputSources() throws -> [InputSourceDescriptor] {
        sources
    }
}

private struct CooldownTestPermissionProvider: PermissionStatusProviding, Sendable {
    let current: PermissionSnapshot

    func snapshot() -> PermissionSnapshot {
        current
    }
}

import Foundation
import Testing
@testable import VoiceSwitchKit

@MainActor
struct VoiceSwitchAppModelKeyboardEventTests {
    @Test
    func loadStartsKeyboardService() throws {
        let service = StubKeyboardEventService()
        let model = VoiceSwitchAppModel(
            settingsStore: KeyboardTestSettingsStore(initial: VoiceSwitchSettings()),
            inputSourceProvider: KeyboardTestInputSourceProvider(sources: []),
            permissionProvider: KeyboardTestPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .unknown)),
            engineBridge: StubKeyboardEngineBridge(result: .idlePrimaryResult),
            keyboardEventService: service
        )

        try model.load()

        #expect(service.startCallCount == 1)
        #expect(model.eventTapStatus == .running)
    }

    @Test
    func keyboardEventIsMappedIntoEngineTransitionAndLogsFullChain() throws {
        let service = StubKeyboardEventService()
        let model = VoiceSwitchAppModel(
            settingsStore: KeyboardTestSettingsStore(initial: VoiceSwitchSettings()),
            inputSourceProvider: KeyboardTestInputSourceProvider(sources: []),
            permissionProvider: KeyboardTestPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .unknown)),
            engineBridge: StubKeyboardEngineBridge(
                result: EngineTransitionResult(
                    state: .optionPending,
                    action: .noOp,
                    diagnostic: DiagnosticEntry(
                        trigger: "optionPressed",
                        reason: "entered_option_pending",
                        sourceState: .idlePrimary,
                        targetState: .optionPending
                    ),
                    timer: EngineTimer(kind: .optionPendingWindow, delaySeconds: 0.42)
                )
            ),
            keyboardEventService: service
        )

        try model.load()
        service.emit(.optionPressed(keyCode: 58))

        #expect(model.lastInputBehavior == .optionPressed)
        #expect(model.currentEngineState == .optionPending)
        #expect(model.lastEngineAction == .noOp)
        #expect(model.eventTapStatus == .running)
        #expect(model.lastRawKeyboardEventSummary == "optionDown(keyCode:58)")
        #expect(model.logEntries.contains { $0.contains("raw_event=optionDown(keyCode:58)") })
        #expect(model.logEntries.contains { $0.contains("trigger=optionPressed") })
        #expect(model.logEntries.contains { $0.contains("target_state=optionPending") })
        #expect(model.logEntries.contains { $0.contains("reason=entered_option_pending") })
        #expect(model.logEntries.contains { $0.contains("timer_delay_seconds=0.42") })
    }

    @Test
    func permissionDegradePathIsLoggedWithoutEngineTransition() throws {
        let service = StubKeyboardEventService()
        let model = VoiceSwitchAppModel(
            settingsStore: KeyboardTestSettingsStore(initial: VoiceSwitchSettings()),
            inputSourceProvider: KeyboardTestInputSourceProvider(sources: []),
            permissionProvider: KeyboardTestPermissionProvider(current: PermissionSnapshot(accessibility: .denied, inputMonitoring: .unknown)),
            engineBridge: StubKeyboardEngineBridge(result: .idlePrimaryResult),
            keyboardEventService: service
        )

        try model.load()
        service.emit(.listenerInactive(reason: "Accessibility permission denied"))

        #expect(model.eventTapStatus == .stopped)
        #expect(model.lastRawKeyboardEventSummary == "listenerInactive(reason:Accessibility permission denied)")
        #expect(model.lastInputBehavior == nil)
        #expect(model.logEntries.contains { $0.contains("listenerInactive(reason:Accessibility permission denied)") })
        #expect(model.keyboardMonitoringErrorMessage == "listenerInactive(reason:Accessibility permission denied)")
    }

    @Test
    func retryKeyboardMonitoringWithoutPermissionKeepsListenerStopped() throws {
        let service = StubKeyboardEventService()
        let permissions = MutableKeyboardPermissionProvider(
            current: PermissionSnapshot(accessibility: .denied, inputMonitoring: .unknown)
        )
        let model = VoiceSwitchAppModel(
            settingsStore: KeyboardTestSettingsStore(initial: VoiceSwitchSettings()),
            inputSourceProvider: KeyboardTestInputSourceProvider(sources: []),
            permissionProvider: permissions,
            engineBridge: StubKeyboardEngineBridge(result: .idlePrimaryResult),
            keyboardEventService: service
        )

        try model.load()
        model.retryKeyboardMonitoring()

        #expect(model.eventTapStatus == .stopped)
        #expect(model.keyboardMonitoringErrorMessage == "Accessibility permission denied")
        #expect(model.logEntries.contains { $0.contains("retryResult=skipped") })
    }

    @Test
    func retryKeyboardMonitoringRestartsListenerAfterPermissionRecovery() throws {
        let service = StubKeyboardEventService()
        service.isRunning = false
        let permissions = MutableKeyboardPermissionProvider(
            current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .unknown)
        )
        let model = VoiceSwitchAppModel(
            settingsStore: KeyboardTestSettingsStore(initial: VoiceSwitchSettings()),
            inputSourceProvider: KeyboardTestInputSourceProvider(sources: []),
            permissionProvider: permissions,
            engineBridge: StubKeyboardEngineBridge(result: .idlePrimaryResult),
            keyboardEventService: service
        )

        try model.load()
        model.retryKeyboardMonitoring()

        #expect(service.startCallCount == 2)
        #expect(model.eventTapStatus == .running)
        #expect(model.keyboardMonitoringErrorMessage == nil)
        #expect(model.logEntries.contains { $0.contains("retryResult=started") })
    }
}

private final class StubKeyboardEventService: KeyboardEventListening, @unchecked Sendable {
    private var handler: ((KeyboardEventSummary) -> Void)?
    private(set) var startCallCount = 0
    var isRunning = true

    func start(eventHandler: @escaping @Sendable (KeyboardEventSummary) -> Void) {
        startCallCount += 1
        isRunning = true
        handler = eventHandler
    }

    func stop() {
        isRunning = false
    }

    func emit(_ summary: KeyboardEventSummary) {
        switch summary {
        case .listenerInactive, .tapDisabled:
            isRunning = false
        case .tapRecoveryAttempted, .optionPressed, .optionReleased, .typingKey:
            isRunning = true
        }
        handler?(summary)
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

private final class KeyboardTestSettingsStore: SettingsStoring, @unchecked Sendable {
    private let initial: VoiceSwitchSettings

    init(initial: VoiceSwitchSettings) {
        self.initial = initial
    }

    func load() -> VoiceSwitchSettings {
        initial
    }

    func save(_ settings: VoiceSwitchSettings) {}
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

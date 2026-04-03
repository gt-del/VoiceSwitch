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
                    diagnostic: DiagnosticEntry(message: "Entered optionPending")
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
        #expect(model.logEntries.contains { $0.contains("raw=optionDown(keyCode:58)") })
        #expect(model.logEntries.contains { $0.contains("event=optionPressed") })
        #expect(model.logEntries.contains { $0.contains("newState=optionPending") })
        #expect(model.logEntries.contains { $0.contains("diagnostic=Entered optionPending") })
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
    }
}

private final class StubKeyboardEventService: KeyboardEventListening, @unchecked Sendable {
    private var handler: ((KeyboardEventSummary) -> Void)?
    private(set) var startCallCount = 0
    var isRunning = true

    func start(eventHandler: @escaping @Sendable (KeyboardEventSummary) -> Void) {
        startCallCount += 1
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

    func transition(from currentState: EngineState, event: InputBehavior) throws -> EngineTransitionResult {
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

private extension EngineTransitionResult {
    static let idlePrimaryResult = EngineTransitionResult(
        state: .idlePrimary,
        action: .noOp,
        diagnostic: DiagnosticEntry(message: "No state change")
    )
}

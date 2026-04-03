import Foundation
import Testing
@testable import VoiceSwitchKit

@MainActor
struct VoiceSwitchAppModelEngineTests {
    @Test
    func sendingEventUpdatesStateActionAndLogs() throws {
        let model = VoiceSwitchAppModel(
            settingsStore: EngineTestSettingsStore(initial: VoiceSwitchSettings()),
            inputSourceProvider: EngineTestInputSourceProvider(sources: []),
            permissionProvider: EngineTestPermissionProvider(current: PermissionSnapshot(accessibility: .unknown, inputMonitoring: .unknown)),
            engineBridge: StubEngineBridge(
                result: EngineTransitionResult(
                    state: .optionPending,
                    action: .noOp,
                    diagnostic: DiagnosticEntry(message: "Entered optionPending")
                )
            )
        )

        try model.sendTestEvent(.optionPressed)

        #expect(model.currentEngineState == .optionPending)
        #expect(model.lastInputBehavior == .optionPressed)
        #expect(model.lastEngineAction == .noOp)
        #expect(model.logEntries.contains { $0.contains("optionPressed") })
        #expect(model.logEntries.contains { $0.contains("optionPending") })
    }
}

private struct StubEngineBridge: EngineBridging {
    let result: EngineTransitionResult

    func transition(from currentState: EngineState, event: InputBehavior) throws -> EngineTransitionResult {
        result
    }
}

private final class EngineTestSettingsStore: SettingsStoring, @unchecked Sendable {
    private let initial: VoiceSwitchSettings

    init(initial: VoiceSwitchSettings) {
        self.initial = initial
    }

    func load() -> VoiceSwitchSettings {
        initial
    }

    func save(_ settings: VoiceSwitchSettings) {}
}

private struct EngineTestInputSourceProvider: InputSourceProviding, Sendable {
    let sources: [InputSourceDescriptor]

    func selectableInputSources() throws -> [InputSourceDescriptor] {
        sources
    }
}

private struct EngineTestPermissionProvider: PermissionStatusProviding, Sendable {
    let current: PermissionSnapshot

    func snapshot() -> PermissionSnapshot {
        current
    }
}

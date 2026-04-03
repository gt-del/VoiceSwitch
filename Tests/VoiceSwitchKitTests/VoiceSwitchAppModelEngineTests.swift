import Foundation
import Testing
@testable import VoiceSwitchKit

@MainActor
struct VoiceSwitchAppModelEngineTests {
    @Test
    func sendingEventUpdatesStateActionAndLogs() throws {
        let model = VoiceSwitchAppModel(
            settingsStore: InMemorySettingsStore(initial: VoiceSwitchSettings()),
            inputSourceProvider: StubInputSourceProvider(sources: []),
            permissionProvider: StubPermissionProvider(current: PermissionSnapshot(accessibility: .unknown, inputMonitoring: .unknown)),
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

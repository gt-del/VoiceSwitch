import Foundation
import Testing
@testable import VoiceSwitchKit

@MainActor
struct VoiceSwitchAppModelEngineTests {
    @Test
    func sendingEventUpdatesStateActionAndLogs() throws {
        let model = VoiceSwitchAppModel(
            settingsStore: EngineTestSettingsStore(
                initial: VoiceSwitchSettings(
                    primaryInputSourceID: "com.apple.keylayout.ABC",
                    voiceInputSourceID: "com.example.voice"
                )
            ),
            inputSourceProvider: EngineTestInputSourceProvider(
                sources: [
                    InputSourceDescriptor(id: "com.apple.keylayout.ABC", displayName: "ABC", isSelected: true),
                    InputSourceDescriptor(id: "com.example.voice", displayName: "Voice", isSelected: false),
                ]
            ),
            inputSourceSwitchingService: StubEngineInputSourceSwitchingService(currentInputSourceID: "com.apple.keylayout.ABC"),
            permissionProvider: EngineTestPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .authorized)),
            engineBridge: StubEngineBridge(
                result: EngineTransitionResult(
                    state: .voiceHeld,
                    action: .switchToVoice,
                    diagnostic: DiagnosticEntry(
                        trigger: "optionPressed",
                        reason: "pressed_option_switch_to_voice",
                        sourceState: .idlePrimary,
                        targetState: .voiceHeld
                    )
                )
            )
        )

        try model.load()
        try model.sendTestEvent(.optionPressed)

        #expect(model.currentEngineState == .voiceHeld)
        #expect(model.lastInputBehavior == .optionPressed)
        #expect(model.lastEngineAction == .switchToVoice)
        #expect(model.logEntries.contains { $0.contains("optionPressed") })
        #expect(model.logEntries.contains { $0.contains("voiceHeld") })
    }
}

private final class StubEngineInputSourceSwitchingService: InputSourceSwitching, @unchecked Sendable {
    let currentInputSourceID: String?

    init(currentInputSourceID: String?) {
        self.currentInputSourceID = currentInputSourceID
    }

    func currentSelectedInputSourceID() throws -> String? {
        currentInputSourceID
    }

    func switchToInputSource(id: String) throws {}
}

private struct StubEngineBridge: EngineBridging {
    let result: EngineTransitionResult

    func transition(
        from currentState: EngineState,
        event: InputBehavior,
        configuration: EngineConfiguration
    ) throws -> EngineTransitionResult {
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

    func save(_ settings: VoiceSwitchSettings, availableInputSourceIDs: Set<String>?) throws {}
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

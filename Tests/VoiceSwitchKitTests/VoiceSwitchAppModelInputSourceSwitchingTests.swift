import Foundation
import Testing
@testable import VoiceSwitchKit

@MainActor
struct VoiceSwitchAppModelInputSourceSwitchingTests {
    @Test
    func switchToVoiceActionInvokesInputSourceSwitchingService() throws {
        let switchingService = StubInputSourceSwitchingService(currentInputSourceID: "com.apple.keylayout.ABC")
        let model = VoiceSwitchAppModel(
            settingsStore: InputSwitchingTestSettingsStore(
                initial: VoiceSwitchSettings(
                    primaryInputSourceID: "com.apple.keylayout.ABC",
                    voiceInputSourceID: "com.example.voice"
                )
            ),
            inputSourceProvider: InputSwitchingTestInputSourceProvider(
                sources: [
                    InputSourceDescriptor(id: "com.apple.keylayout.ABC", displayName: "ABC", isSelected: true),
                    InputSourceDescriptor(id: "com.example.voice", displayName: "Voice", isSelected: false),
                ]
            ),
            inputSourceSwitchingService: switchingService,
            permissionProvider: InputSwitchingTestPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .unknown)),
            engineBridge: StubActionEngineBridge(
                result: EngineTransitionResult(
                    state: .voiceActive,
                    action: .switchToVoice,
                    diagnostic: DiagnosticEntry(
                        trigger: "optionWindowExpired",
                        reason: "activated_voice_after_option_window",
                        sourceState: .optionPending,
                        targetState: .voiceActive
                    )
                )
            )
        )

        try model.load()
        try model.sendTestEvent(.optionReleased)

        #expect(switchingService.switchCalls == ["com.example.voice"])
        #expect(model.logEntries.contains { $0.contains("current_input_source=com.apple.keylayout.ABC") })
        #expect(model.logEntries.contains { $0.contains("target_input_source=com.example.voice") })
        #expect(model.logEntries.contains { $0.contains("switch_result=success") })
    }

    @Test
    func switchToPrimaryActionInvokesInputSourceSwitchingService() throws {
        let switchingService = StubInputSourceSwitchingService(currentInputSourceID: "com.example.voice")
        let model = VoiceSwitchAppModel(
            settingsStore: InputSwitchingTestSettingsStore(
                initial: VoiceSwitchSettings(
                    primaryInputSourceID: "com.apple.keylayout.ABC",
                    voiceInputSourceID: "com.example.voice"
                )
            ),
            inputSourceProvider: InputSwitchingTestInputSourceProvider(
                sources: [
                    InputSourceDescriptor(id: "com.apple.keylayout.ABC", displayName: "ABC", isSelected: false),
                    InputSourceDescriptor(id: "com.example.voice", displayName: "Voice", isSelected: true),
                ]
            ),
            inputSourceSwitchingService: switchingService,
            permissionProvider: InputSwitchingTestPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .unknown)),
            engineBridge: StubActionEngineBridge(
                result: EngineTransitionResult(
                    state: .idlePrimary,
                    action: .switchToPrimary,
                    diagnostic: DiagnosticEntry(
                        trigger: "typingDetected",
                        reason: "returned_to_idle_primary_after_typing",
                        sourceState: .voiceActive,
                        targetState: .idlePrimary
                    )
                )
            )
        )

        try model.load()
        try model.sendTestEvent(.typingDetected)

        #expect(switchingService.switchCalls == ["com.apple.keylayout.ABC"])
        #expect(model.logEntries.contains { $0.contains("target_input_source=com.apple.keylayout.ABC") })
        #expect(model.logEntries.contains { $0.contains("switch_result=success") })
    }

    @Test
    func missingVoiceConfigurationSkipsSwitchAndLogsReason() throws {
        let switchingService = StubInputSourceSwitchingService(currentInputSourceID: "com.apple.keylayout.ABC")
        let model = VoiceSwitchAppModel(
            settingsStore: InputSwitchingTestSettingsStore(
                initial: VoiceSwitchSettings(
                    primaryInputSourceID: "com.apple.keylayout.ABC",
                    voiceInputSourceID: nil
                )
            ),
            inputSourceProvider: InputSwitchingTestInputSourceProvider(
                sources: [
                    InputSourceDescriptor(id: "com.apple.keylayout.ABC", displayName: "ABC", isSelected: true),
                ]
            ),
            inputSourceSwitchingService: switchingService,
            permissionProvider: InputSwitchingTestPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .unknown)),
            engineBridge: StubActionEngineBridge(
                result: EngineTransitionResult(
                    state: .voiceActive,
                    action: .switchToVoice,
                    diagnostic: DiagnosticEntry(
                        trigger: "optionWindowExpired",
                        reason: "activated_voice_after_option_window",
                        sourceState: .optionPending,
                        targetState: .voiceActive
                    )
                )
            )
        )

        try model.load()
        try model.sendTestEvent(.optionReleased)

        #expect(switchingService.switchCalls.isEmpty)
        #expect(model.logEntries.contains { $0.contains("switch_result=skipped") })
        #expect(model.logEntries.contains { $0.contains("reason=voice_input_source_not_configured") })
    }

    @Test
    func alreadyOnTargetInputSourceSkipsDuplicateSwitch() throws {
        let switchingService = StubInputSourceSwitchingService(currentInputSourceID: "com.example.voice")
        let model = VoiceSwitchAppModel(
            settingsStore: InputSwitchingTestSettingsStore(
                initial: VoiceSwitchSettings(
                    primaryInputSourceID: "com.apple.keylayout.ABC",
                    voiceInputSourceID: "com.example.voice"
                )
            ),
            inputSourceProvider: InputSwitchingTestInputSourceProvider(
                sources: [
                    InputSourceDescriptor(id: "com.apple.keylayout.ABC", displayName: "ABC", isSelected: false),
                    InputSourceDescriptor(id: "com.example.voice", displayName: "Voice", isSelected: true),
                ]
            ),
            inputSourceSwitchingService: switchingService,
            permissionProvider: InputSwitchingTestPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .unknown)),
            engineBridge: StubActionEngineBridge(
                result: EngineTransitionResult(
                    state: .voiceActive,
                    action: .switchToVoice,
                    diagnostic: DiagnosticEntry(
                        trigger: "optionWindowExpired",
                        reason: "activated_voice_after_option_window",
                        sourceState: .optionPending,
                        targetState: .voiceActive
                    )
                )
            )
        )

        try model.load()
        try model.sendTestEvent(.optionReleased)

        #expect(switchingService.switchCalls.isEmpty)
        #expect(model.logEntries.contains { $0.contains("switch_result=skipped") })
        #expect(model.logEntries.contains { $0.contains("reason=target_already_selected") })
    }

    @Test
    func switchFailureLogsClearReason() throws {
        let switchingService = StubInputSourceSwitchingService(currentInputSourceID: "com.apple.keylayout.ABC")
        switchingService.error = InputSourceSwitchingError.selectFailed("com.example.voice", -50)
        let model = VoiceSwitchAppModel(
            settingsStore: InputSwitchingTestSettingsStore(
                initial: VoiceSwitchSettings(
                    primaryInputSourceID: "com.apple.keylayout.ABC",
                    voiceInputSourceID: "com.example.voice"
                )
            ),
            inputSourceProvider: InputSwitchingTestInputSourceProvider(
                sources: [
                    InputSourceDescriptor(id: "com.apple.keylayout.ABC", displayName: "ABC", isSelected: true),
                    InputSourceDescriptor(id: "com.example.voice", displayName: "Voice", isSelected: false),
                ]
            ),
            inputSourceSwitchingService: switchingService,
            permissionProvider: InputSwitchingTestPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .unknown)),
            engineBridge: StubActionEngineBridge(
                result: EngineTransitionResult(
                    state: .voiceActive,
                    action: .switchToVoice,
                    diagnostic: DiagnosticEntry(
                        trigger: "optionWindowExpired",
                        reason: "activated_voice_after_option_window",
                        sourceState: .optionPending,
                        targetState: .voiceActive
                    )
                )
            )
        )

        try model.load()
        try model.sendTestEvent(.optionReleased)

        #expect(model.logEntries.contains { $0.contains("switch_result=failed") })
        #expect(model.logEntries.contains { $0.contains("Failed to select input source com.example.voice. OSStatus=-50") })
    }
}

private struct StubActionEngineBridge: EngineBridging {
    let result: EngineTransitionResult

    func transition(
        from currentState: EngineState,
        event: InputBehavior,
        configuration: EngineConfiguration
    ) throws -> EngineTransitionResult {
        result
    }
}

private final class StubInputSourceSwitchingService: InputSourceSwitching, @unchecked Sendable {
    var currentInputSourceID: String?
    var switchCalls: [String] = []
    var error: Error?

    init(currentInputSourceID: String?) {
        self.currentInputSourceID = currentInputSourceID
    }

    func currentSelectedInputSourceID() throws -> String? {
        currentInputSourceID
    }

    func switchToInputSource(id: String) throws {
        if let error {
            throw error
        }

        switchCalls.append(id)
        currentInputSourceID = id
    }
}

private final class InputSwitchingTestSettingsStore: SettingsStoring, @unchecked Sendable {
    private let initial: VoiceSwitchSettings

    init(initial: VoiceSwitchSettings) {
        self.initial = initial
    }

    func load() -> VoiceSwitchSettings {
        initial
    }

    func save(_ settings: VoiceSwitchSettings) {}
}

private struct InputSwitchingTestInputSourceProvider: InputSourceProviding, Sendable {
    let sources: [InputSourceDescriptor]

    func selectableInputSources() throws -> [InputSourceDescriptor] {
        sources
    }
}

private struct InputSwitchingTestPermissionProvider: PermissionStatusProviding, Sendable {
    let current: PermissionSnapshot

    func snapshot() -> PermissionSnapshot {
        current
    }
}

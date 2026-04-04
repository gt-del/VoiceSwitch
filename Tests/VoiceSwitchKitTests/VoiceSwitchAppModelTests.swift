import Foundation
import Testing
@testable import VoiceSwitchKit

@MainActor
struct VoiceSwitchAppModelTests {
    @Test
    func loadReadsSavedSelectionsSourcesAndPermissions() throws {
        let store = InMemorySettingsStore(
            initial: VoiceSwitchSettings(
                primaryInputSourceID: "primary.id",
                voiceInputSourceID: "voice.id",
                launchAtLoginEnabled: true,
                optionPendingWindow: 0.25,
                cooldownDuration: 7,
                voiceExitDelay: 1.2
            )
        )
        let provider = StubInputSourceProvider(
            sources: [
                InputSourceDescriptor(id: "primary.id", displayName: "ABC", isSelected: true),
                InputSourceDescriptor(id: "voice.id", displayName: "Voice", isSelected: false),
            ]
        )
        let permissions = StubPermissionProvider(
            current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .unknown)
        )
        let launchAtLoginController = StubLaunchAtLoginController(isEnabled: true)
        let model = VoiceSwitchAppModel(
            settingsStore: store,
            inputSourceProvider: provider,
            permissionProvider: permissions,
            launchAtLoginController: launchAtLoginController
        )

        try model.load()

        #expect(model.selectedPrimaryInputSourceID == "primary.id")
        #expect(model.selectedVoiceInputSourceID == "voice.id")
        #expect(model.launchAtLoginEnabled)
        #expect(model.optionPendingWindow == 0.25)
        #expect(model.cooldownDuration == 7)
        #expect(model.voiceExitDelay == 1.2)
        #expect(model.availableInputSources.count == 2)
        #expect(model.permissionSnapshot == permissions.snapshot())
    }

    @Test
    func saveSelectionsPersistsCurrentValues() {
        let store = InMemorySettingsStore(initial: VoiceSwitchSettings())
        let launchAtLoginController = StubLaunchAtLoginController(isEnabled: false)
        let model = VoiceSwitchAppModel(
            settingsStore: store,
            inputSourceProvider: StubInputSourceProvider(sources: []),
            permissionProvider: StubPermissionProvider(current: PermissionSnapshot(accessibility: .unknown, inputMonitoring: .unknown)),
            launchAtLoginController: launchAtLoginController
        )

        model.selectedPrimaryInputSourceID = "com.apple.keylayout.ABC"
        model.selectedVoiceInputSourceID = "com.example.voice"
        model.launchAtLoginEnabled = true
        model.optionPendingWindow = 0.25
        model.cooldownDuration = 7
        model.voiceExitDelay = 1.2

        model.saveSelections()

        #expect(store.saved == VoiceSwitchSettings(
            primaryInputSourceID: "com.apple.keylayout.ABC",
            voiceInputSourceID: "com.example.voice",
            launchAtLoginEnabled: true,
            optionPendingWindow: 0.25,
            cooldownDuration: 7,
            voiceExitDelay: 1.2
        ))
        #expect(launchAtLoginController.lastEnabled == true)
    }

    @Test
    func saveSelectionsLogsLaunchAtLoginFailure() {
        let store = InMemorySettingsStore(initial: VoiceSwitchSettings())
        let launchAtLoginController = StubLaunchAtLoginController(
            isEnabled: false,
            error: LaunchAtLoginError.requiresApproval
        )
        let model = VoiceSwitchAppModel(
            settingsStore: store,
            inputSourceProvider: StubInputSourceProvider(sources: []),
            permissionProvider: StubPermissionProvider(current: PermissionSnapshot(accessibility: .unknown, inputMonitoring: .unknown)),
            launchAtLoginController: launchAtLoginController
        )

        model.launchAtLoginEnabled = true
        model.saveSelections()

        #expect(model.launchAtLoginErrorMessage?.contains("requires user approval") == true)
        #expect(model.logEntries.contains { $0.contains("trigger=launch_at_login") })
        #expect(model.logEntries.contains { $0.contains("result=failed") })
    }

    @Test
    func loadFlagsUnavailableInputSourcesWithoutCrashing() throws {
        let store = InMemorySettingsStore(
            initial: VoiceSwitchSettings(
                primaryInputSourceID: "missing.primary",
                voiceInputSourceID: "voice.id"
            )
        )
        let provider = StubInputSourceProvider(
            sources: [
                InputSourceDescriptor(id: "voice.id", displayName: "Voice", isSelected: false),
            ]
        )
        let model = VoiceSwitchAppModel(
            settingsStore: store,
            inputSourceProvider: provider,
            permissionProvider: StubPermissionProvider(current: PermissionSnapshot(accessibility: .unknown, inputMonitoring: .unknown))
        )

        try model.load()

        #expect(model.selectedPrimaryInputSourceID == nil)
        #expect(model.selectedVoiceInputSourceID == "voice.id")
        #expect(model.configurationIssues.count == 1)
        #expect(model.configurationIssues.first?.contains("Primary IME") == true)
    }

    @Test
    func loadLogsLaunchAtLoginStatusMismatch() throws {
        let store = InMemorySettingsStore(
            initial: VoiceSwitchSettings(
                launchAtLoginEnabled: true
            )
        )
        let launchAtLoginController = StubLaunchAtLoginController(isEnabled: false)
        let model = VoiceSwitchAppModel(
            settingsStore: store,
            inputSourceProvider: StubInputSourceProvider(sources: []),
            permissionProvider: StubPermissionProvider(current: PermissionSnapshot(accessibility: .unknown, inputMonitoring: .unknown)),
            launchAtLoginController: launchAtLoginController
        )

        try model.load()

        #expect(model.launchAtLoginEnabled == false)
        #expect(model.logEntries.contains { $0.contains("trigger=launch_at_login") })
        #expect(model.logEntries.contains { $0.contains("reason=status_mismatch") })
        #expect(model.logEntries.contains { $0.contains("requested=true") })
        #expect(model.logEntries.contains { $0.contains("actual=false") })
    }
}

private final class InMemorySettingsStore: SettingsStoring, @unchecked Sendable {
    private let initial: VoiceSwitchSettings
    var saved: VoiceSwitchSettings?

    init(initial: VoiceSwitchSettings) {
        self.initial = initial
    }

    func load() -> VoiceSwitchSettings {
        saved ?? initial
    }

    func save(_ settings: VoiceSwitchSettings) {
        saved = settings
    }
}

private struct StubInputSourceProvider: InputSourceProviding, Sendable {
    let sources: [InputSourceDescriptor]

    func selectableInputSources() throws -> [InputSourceDescriptor] {
        sources
    }
}

private struct StubPermissionProvider: PermissionStatusProviding, Sendable {
    let current: PermissionSnapshot

    func snapshot() -> PermissionSnapshot {
        current
    }
}

private final class StubLaunchAtLoginController: LaunchAtLoginControlling, @unchecked Sendable {
    let isEnabledValue: Bool
    let error: Error?
    private(set) var lastEnabled: Bool?

    init(isEnabled: Bool, error: Error? = nil) {
        self.isEnabledValue = isEnabled
        self.error = error
    }

    func isEnabled() -> Bool {
        isEnabledValue
    }

    func setEnabled(_ enabled: Bool) throws {
        lastEnabled = enabled
        if let error {
            throw error
        }
    }
}

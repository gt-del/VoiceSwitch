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
                isEnabled: false,
                launchAtLoginEnabled: true,
                voiceActivationDelay: 0.25,
                releaseReturnDelay: 0.1,
                cooldownDuration: 7,
            )
        )
        let provider = StubInputSourceProvider(
            sources: [
                InputSourceDescriptor(id: "primary.id", displayName: "ABC", isSelected: true),
                InputSourceDescriptor(id: "voice.id", displayName: "Voice", isSelected: false),
            ]
        )
        let permissions = StubPermissionProvider(
            current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .authorized)
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
        #expect(!model.isEnabled)
        #expect(model.launchAtLoginEnabled)
        #expect(model.voiceActivationDelay == 0.25)
        #expect(model.releaseReturnDelay == 0.1)
        #expect(model.cooldownDuration == 7)
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
        model.isEnabled = false
        model.launchAtLoginEnabled = true
        model.voiceActivationDelay = 0.25
        model.releaseReturnDelay = 0.1
        model.cooldownDuration = 7

        model.saveSelections()

        #expect(store.saved == VoiceSwitchSettings(
            primaryInputSourceID: "com.apple.keylayout.ABC",
            voiceInputSourceID: "com.example.voice",
            isEnabled: false,
            launchAtLoginEnabled: true,
            voiceActivationDelay: 0.25,
            releaseReturnDelay: 0.1,
            cooldownDuration: 7,
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
        #expect(model.configurationIssues.contains { $0.contains("默认输入法已失效") })
        #expect(!model.canRun)
        #expect(model.statusSummary == "不可用")
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

    @Test
    func missingInputSourceConfigurationBlocksAutomation() throws {
        let model = VoiceSwitchAppModel(
            settingsStore: InMemorySettingsStore(
                initial: VoiceSwitchSettings(
                    primaryInputSourceID: nil,
                    voiceInputSourceID: nil
                )
            ),
            inputSourceProvider: StubInputSourceProvider(sources: []),
            permissionProvider: StubPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .authorized))
        )

        try model.load()

        #expect(!model.canRun)
        #expect(model.blockingIssue == "未配置默认输入法。")
        #expect(model.statusSummary == "不可用")
    }

    @Test
    func identicalInputSourcesBlockAutomation() throws {
        let model = VoiceSwitchAppModel(
            settingsStore: InMemorySettingsStore(
                initial: VoiceSwitchSettings(
                    primaryInputSourceID: "same.id",
                    voiceInputSourceID: "same.id"
                )
            ),
            inputSourceProvider: StubInputSourceProvider(
                sources: [
                    InputSourceDescriptor(id: "same.id", displayName: "Same", isSelected: true),
                ]
            ),
            permissionProvider: StubPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .authorized))
        )

        try model.load()

        #expect(!model.canRun)
        #expect(model.configurationIssues.contains("默认输入法和语音输入法不能相同。"))
        #expect(model.blockingIssue == "默认输入法和语音输入法不能相同。")
    }

    @Test
    func deniedAccessibilityMakesStatusUnavailable() throws {
        let model = VoiceSwitchAppModel(
            settingsStore: InMemorySettingsStore(initial: VoiceSwitchSettings()),
            inputSourceProvider: StubInputSourceProvider(sources: []),
            permissionProvider: StubPermissionProvider(current: PermissionSnapshot(accessibility: .denied, inputMonitoring: .authorized))
        )

        try model.load()

        #expect(!model.canRun)
        #expect(model.statusSummary == "不可用")
        #expect(model.blockingIssue?.contains("辅助功能权限") == true)
    }

    @Test
    func deniedInputMonitoringMakesStatusUnavailable() throws {
        let model = VoiceSwitchAppModel(
            settingsStore: InMemorySettingsStore(
                initial: VoiceSwitchSettings(
                    primaryInputSourceID: "primary.id",
                    voiceInputSourceID: "voice.id"
                )
            ),
            inputSourceProvider: StubInputSourceProvider(
                sources: [
                    InputSourceDescriptor(id: "primary.id", displayName: "Primary", isSelected: true),
                    InputSourceDescriptor(id: "voice.id", displayName: "Voice", isSelected: false),
                ]
            ),
            permissionProvider: StubPermissionProvider(
                current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .denied)
            )
        )

        try model.load()

        #expect(!model.canRun)
        #expect(model.statusSummary == "不可用")
        #expect(model.blockingIssue?.contains("输入监听权限") == true)
    }

    @Test
    func accessibilityMismatchUsesDifferentBlockingMessage() throws {
        let model = VoiceSwitchAppModel(
            settingsStore: InMemorySettingsStore(
                initial: VoiceSwitchSettings(
                    primaryInputSourceID: "primary.id",
                    voiceInputSourceID: "voice.id"
                )
            ),
            inputSourceProvider: StubInputSourceProvider(
                sources: [
                    InputSourceDescriptor(id: "primary.id", displayName: "Primary", isSelected: true),
                    InputSourceDescriptor(id: "voice.id", displayName: "Voice", isSelected: false),
                ]
            ),
            permissionProvider: StubPermissionProvider(
                current: PermissionSnapshot(
                    accessibility: .denied,
                    inputMonitoring: .authorized,
                    accessibilityTrusted: false,
                    inputMonitoringTrusted: true,
                    executablePath: "/Users/didi/Code/github/VoiceSwitch/.build/debug/VoiceSwitchApp",
                    bundleIdentifier: nil,
                    bundlePath: nil
                )
            )
        )

        try model.load()

        #expect(model.blockingIssue?.contains("未命中已授权条目") == true)
    }

    @Test
    func loadExposesRuntimeDetectionValues() throws {
        let snapshot = PermissionSnapshot(
            accessibility: .authorized,
            inputMonitoring: .authorized,
            accessibilityTrusted: true,
            inputMonitoringTrusted: true,
            executablePath: "/Applications/VoiceSwitch.app/Contents/MacOS/VoiceSwitchApp",
            bundleIdentifier: "com.gtdel.VoiceSwitch.dev",
            bundlePath: "/Applications/VoiceSwitch.app"
        )
        let model = VoiceSwitchAppModel(
            settingsStore: InMemorySettingsStore(initial: VoiceSwitchSettings()),
            inputSourceProvider: StubInputSourceProvider(sources: []),
            permissionProvider: StubPermissionProvider(current: snapshot)
        )

        try model.load()

        #expect(model.accessibilityTrustedValueLabel == "true")
        #expect(model.inputMonitoringTrustedValueLabel == "true")
        #expect(model.runtimeExecutablePath == "/Applications/VoiceSwitch.app/Contents/MacOS/VoiceSwitchApp")
        #expect(model.runtimeBundleIdentifier == "com.gtdel.VoiceSwitch.dev")
        #expect(model.runtimeBundlePath == "/Applications/VoiceSwitch.app")
    }

    @Test
    func reenabledValidConfigurationRestoresRunnableState() throws {
        let model = VoiceSwitchAppModel(
            settingsStore: InMemorySettingsStore(
                initial: VoiceSwitchSettings(
                    primaryInputSourceID: "primary.id",
                    voiceInputSourceID: "voice.id",
                    isEnabled: false
                )
            ),
            inputSourceProvider: StubInputSourceProvider(
                sources: [
                    InputSourceDescriptor(id: "primary.id", displayName: "Primary", isSelected: true),
                    InputSourceDescriptor(id: "voice.id", displayName: "Voice", isSelected: false),
                ]
            ),
            permissionProvider: StubPermissionProvider(current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .authorized))
        )

        try model.load()
        #expect(model.statusSummary == "已停用")

        model.isEnabled = true

        #expect(model.canRun)
        #expect(model.blockingIssue == nil)
        #expect(model.statusSummary == "默认输入")
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

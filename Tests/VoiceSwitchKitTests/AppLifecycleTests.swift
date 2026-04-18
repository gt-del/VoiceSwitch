import AppKit
import Foundation
import Testing
import VoiceSwitchKit
@testable import VoiceSwitchApp

struct AppLifecycleTests {
    @Test
    func menuBarInfoPlistEnablesLsuiElement() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let infoPlistURL = packageRoot.appending(path: "Info.plist")
        let plistData = try Data(contentsOf: infoPlistURL)
        guard let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            throw NSError(domain: "AppLifecycleTests", code: 1)
        }

        #expect(plist["LSUIElement"] as? Bool == true)
    }

    @Test
    func activationCoordinatorLaunchesAsRegular() {
        let coordinator = AppActivationPolicyCoordinator()

        #expect(coordinator.launchPolicy() == .regular)
    }

    @Test
    func activationCoordinatorUsesRegularForOpeningMainWindow() {
        let coordinator = AppActivationPolicyCoordinator()

        #expect(coordinator.policyForOpeningMainWindow() == .regular)
    }

    @Test
    func initialMainWindowPresentationCoordinatorConsumesOnlyFirstLaunchRequest() {
        let coordinator = InitialMainWindowPresentationCoordinator()

        #expect(coordinator.consumeLaunchRequest() == true)
        #expect(coordinator.consumeLaunchRequest() == false)
    }

    @Test
    func mainWindowLaunchPolicyPresentsWindowOnManualLaunch() {
        #expect(mainWindowLaunchPolicy() == .presentedOnLaunch)
    }

    @Test
    func mainWindowSceneKindUsesAppDelegateManagedWindow() {
        #expect(mainWindowSceneKind() == .appDelegateManagedWindow)
    }

    @Test
    func activationCoordinatorReturnsAccessoryWhenNoVisibleManagedWindowRemains() {
        let coordinator = AppActivationPolicyCoordinator()
        let windows = [
            ManagedAppWindow(title: VoiceSwitchWindowID.title, isVisible: false),
        ]

        #expect(coordinator.policyAfterManagedWindowChange(windows: windows) == .accessory)
    }

    @Test
    func activationCoordinatorKeepsCurrentPolicyWhileManagedWindowIsVisible() {
        let coordinator = AppActivationPolicyCoordinator()
        let windows = [
            ManagedAppWindow(title: VoiceSwitchWindowID.title, isVisible: true),
        ]

        #expect(coordinator.policyAfterManagedWindowChange(windows: windows) == nil)
    }

    @Test
    @MainActor
    func appDelegateDoesNotTerminateAfterLastWindowCloses() {
        let delegate = AppDelegate()

        #expect(delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared) == false)
    }

    @Test
    @MainActor
    func appModelFactoryLoadsStateWithoutWaitingForMainWindow() {
        let keyboardEventService = BootstrapStubKeyboardEventService()
        let model = makeVoiceSwitchAppModel(
            settingsStore: BootstrapSettingsStore(
                initial: VoiceSwitchSettings(
                    primaryInputSourceID: "com.apple.keylayout.ABC",
                    voiceInputSourceID: "com.example.voice"
                )
            ),
            inputSourceProvider: BootstrapInputSourceProvider(
                sources: [
                    InputSourceDescriptor(id: "com.apple.keylayout.ABC", displayName: "ABC", isSelected: true),
                    InputSourceDescriptor(id: "com.example.voice", displayName: "Voice", isSelected: false),
                ]
            ),
            inputSourceSwitchingService: BootstrapInputSourceSwitchingService(
                currentInputSourceID: "com.apple.keylayout.ABC"
            ),
            permissionProvider: BootstrapPermissionProvider(
                current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .authorized)
            ),
            keyboardEventService: keyboardEventService
        )

        #expect(model.selectedPrimaryInputSourceID == "com.apple.keylayout.ABC")
        #expect(model.selectedVoiceInputSourceID == "com.example.voice")
        #expect(model.eventTapStatus == .running)
        #expect(keyboardEventService.startCallCount == 1)
    }
}

private final class BootstrapSettingsStore: SettingsStoring, @unchecked Sendable {
    private let initial: VoiceSwitchSettings

    init(initial: VoiceSwitchSettings) {
        self.initial = initial
    }

    func load() -> VoiceSwitchSettings {
        initial
    }

    func save(_ settings: VoiceSwitchSettings, availableInputSourceIDs: Set<String>?) throws {}
}

private struct BootstrapInputSourceProvider: InputSourceProviding, Sendable {
    let sources: [InputSourceDescriptor]

    func selectableInputSources() throws -> [InputSourceDescriptor] {
        sources
    }
}

private final class BootstrapInputSourceSwitchingService: InputSourceSwitching, @unchecked Sendable {
    private var currentInputSourceID: String?

    init(currentInputSourceID: String?) {
        self.currentInputSourceID = currentInputSourceID
    }

    func currentSelectedInputSourceID() throws -> String? {
        currentInputSourceID
    }

    func switchToInputSource(id: String) throws {
        currentInputSourceID = id
    }
}

private struct BootstrapPermissionProvider: PermissionStatusProviding, Sendable {
    let current: PermissionSnapshot

    func snapshot() -> PermissionSnapshot {
        current
    }
}

private final class BootstrapStubKeyboardEventService: KeyboardEventListening, @unchecked Sendable {
    private(set) var startCallCount = 0
    var isRunning = true

    func start(eventHandler: @escaping @Sendable (KeyboardEventSummary) -> Void) {
        startCallCount += 1
        isRunning = true
    }

    func stop() {
        isRunning = false
    }
}

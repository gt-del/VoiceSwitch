import AppKit
import Foundation
import Testing
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
    func activationCoordinatorLaunchesAsAccessory() {
        let coordinator = AppActivationPolicyCoordinator()

        #expect(coordinator.launchPolicy() == .accessory)
    }

    @Test
    func activationCoordinatorUsesRegularForOpeningMainWindow() {
        let coordinator = AppActivationPolicyCoordinator()

        #expect(coordinator.policyForOpeningMainWindow() == .regular)
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
}

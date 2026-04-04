import AppKit
import Foundation
import Testing
@testable import VoiceSwitchApp

@MainActor
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
    func appDelegateUsesAccessoryActivationPolicy() {
        let application = NSApplication.shared
        let previousPolicy = application.activationPolicy()
        let delegate = AppDelegate()

        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        #expect(application.activationPolicy() == .accessory)

        _ = application.setActivationPolicy(previousPolicy)
    }

    @Test
    func appDelegateDoesNotTerminateAfterLastWindowCloses() {
        let delegate = AppDelegate()

        #expect(delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared) == false)
    }
}

import AppKit
import SwiftUI
import VoiceSwitchKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var sharedModel: VoiceSwitchAppModel?

    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        DispatchQueue.main.async {
            self.showSettingsWindow(nil)
        }
    }

    @objc
    func showSettingsWindow(_ sender: Any?) {
        guard let model = Self.sharedModel else {
            return
        }

        if settingsWindow == nil {
            let hostingController = NSHostingController(rootView: SettingsView(model: model))
            let window = NSWindow(contentViewController: hostingController)
            window.title = "VoiceSwitch Settings"
            window.setContentSize(NSSize(width: 560, height: 420))
            window.styleMask.insert(.titled)
            window.styleMask.insert(.closable)
            window.styleMask.insert(.miniaturizable)
            window.styleMask.insert(.resizable)
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

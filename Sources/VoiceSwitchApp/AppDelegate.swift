import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        sender.activate(ignoringOtherApps: true)

        if !flag {
            for window in sender.windows where !window.isVisible {
                window.makeKeyAndOrderFront(nil)
            }
            sender.windows.first?.makeKeyAndOrderFront(nil)
        }

        return true
    }
}

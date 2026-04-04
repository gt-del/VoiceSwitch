import AppKit

struct ManagedAppWindow: Equatable {
    let title: String
    let isVisible: Bool
}

struct AppActivationPolicyCoordinator {
    func launchPolicy() -> NSApplication.ActivationPolicy {
        .accessory
    }

    func policyForOpeningMainWindow() -> NSApplication.ActivationPolicy {
        .regular
    }

    func policyAfterManagedWindowChange(windows: [ManagedAppWindow]) -> NSApplication.ActivationPolicy? {
        visibleManagedMainWindows(in: windows).isEmpty ? .accessory : nil
    }

    func isManagedMainWindow(_ window: ManagedAppWindow) -> Bool {
        window.title == VoiceSwitchWindowID.title
    }

    private func visibleManagedMainWindows(in windows: [ManagedAppWindow]) -> [ManagedAppWindow] {
        windows.filter { isManagedMainWindow($0) && $0.isVisible }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?
    private let activationCoordinator = AppActivationPolicyCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleManagedWindowBecameMain(_:)),
            name: NSWindow.didBecomeMainNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleManagedWindowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )
        NSApp.setActivationPolicy(activationCoordinator.launchPolicy())
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            prepareForMainWindowPresentation()

            if let mainWindow = mainWindow() {
                mainWindow.makeKeyAndOrderFront(nil)
            }
        }

        sender.activate(ignoringOtherApps: true)
        return true
    }

    func prepareForMainWindowPresentation() {
        NSApp.setActivationPolicy(activationCoordinator.policyForOpeningMainWindow())
    }

    func restoreAccessoryModeIfNeeded() {
        guard let policy = activationCoordinator.policyAfterManagedWindowChange(windows: managedWindowSnapshots()) else {
            return
        }

        NSApp.setActivationPolicy(policy)
    }

    func mainWindow() -> NSWindow? {
        visibleMainWindows().first ?? managedMainWindows().first
    }

    @objc
    private func handleManagedWindowBecameMain(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, isManagedMainWindow(window) else {
            return
        }

        prepareForMainWindowPresentation()
    }

    @objc
    private func handleManagedWindowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, isManagedMainWindow(window) else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.restoreAccessoryModeIfNeeded()
        }
    }

    private func managedMainWindows() -> [NSWindow] {
        NSApp.windows.filter(isManagedMainWindow)
    }

    private func visibleMainWindows() -> [NSWindow] {
        managedMainWindows().filter { $0.isVisible }
    }

    private func managedWindowSnapshots() -> [ManagedAppWindow] {
        NSApp.windows.map { ManagedAppWindow(title: $0.title, isVisible: $0.isVisible) }
    }

    private func isManagedMainWindow(_ window: NSWindow) -> Bool {
        activationCoordinator.isManagedMainWindow(
            ManagedAppWindow(title: window.title, isVisible: window.isVisible)
        )
    }
}

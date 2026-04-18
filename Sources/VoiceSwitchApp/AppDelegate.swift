import AppKit
import SwiftUI
import VoiceSwitchKit

@MainActor
enum MainWindowBootstrapStore {
    static var model: VoiceSwitchAppModel?
}

struct ManagedAppWindow: Equatable {
    let title: String
    let isVisible: Bool
}

final class InitialMainWindowPresentationCoordinator {
    private var hasConsumedLaunchRequest = false

    func consumeLaunchRequest() -> Bool {
        guard !hasConsumedLaunchRequest else {
            return false
        }

        hasConsumedLaunchRequest = true
        return true
    }
}

struct AppActivationPolicyCoordinator {
    func launchPolicy() -> NSApplication.ActivationPolicy {
        .regular
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
    private let initialMainWindowPresentationCoordinator = InitialMainWindowPresentationCoordinator()
    private weak var managedMainWindow: NSWindow?
    private var didFinishLaunching = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        didFinishLaunching = true
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
        presentInitialMainWindowIfNeeded()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }

        sender.activate(ignoringOtherApps: true)
        return true
    }

    func refreshManagedMainWindowContentIfNeeded() {
        guard
            let model = MainWindowBootstrapStore.model,
            let hostingController = managedMainWindow?.contentViewController as? NSHostingController<AnyView>
        else {
            return
        }

        hostingController.rootView = makeMainWindowRootView(model: model)
    }

    func presentInitialMainWindowIfNeeded() {
        guard didFinishLaunching else {
            return
        }
        guard MainWindowBootstrapStore.model != nil else {
            return
        }

        guard initialMainWindowPresentationCoordinator.consumeLaunchRequest() else {
            return
        }

        showMainWindow()
    }

    func prepareForMainWindowPresentation() {
        NSApp.setActivationPolicy(activationCoordinator.policyForOpeningMainWindow())
    }

    func showMainWindow() {
        prepareForMainWindowPresentation()
        let window = makeOrReuseMainWindow()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func restoreAccessoryModeIfNeeded() {
        guard let policy = activationCoordinator.policyAfterManagedWindowChange(windows: managedWindowSnapshots()) else {
            return
        }

        NSApp.setActivationPolicy(policy)
    }

    func mainWindow() -> NSWindow? {
        managedMainWindow ?? visibleMainWindows().first ?? managedMainWindows().first
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

    private func makeOrReuseMainWindow() -> NSWindow {
        if let managedMainWindow {
            return managedMainWindow
        }
        if let existingWindow = managedMainWindows().first {
            managedMainWindow = existingWindow
            return existingWindow
        }

        guard let model = MainWindowBootstrapStore.model else {
            preconditionFailure("Main window model must be installed before presentation")
        }

        let hostingController = NSHostingController(rootView: makeMainWindowRootView(model: model))
        let window = NSWindow(contentViewController: hostingController)
        window.title = VoiceSwitchWindowID.title
        window.setContentSize(NSSize(width: 860, height: 620))
        window.styleMask = NSWindow.StyleMask([.titled, .closable, .miniaturizable, .resizable])
        window.isReleasedWhenClosed = false
        window.identifier = NSUserInterfaceItemIdentifier(VoiceSwitchWindowID.main)
        window.center()
        managedMainWindow = window
        return window
    }

    private func makeMainWindowRootView(model: VoiceSwitchAppModel) -> AnyView {
        AnyView(
            MainWindowView(model: model)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    model.handleApplicationDidBecomeActive()
                }
        )
    }
}

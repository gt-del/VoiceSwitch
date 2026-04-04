import Foundation

public protocol SettingsStoring: Sendable {
    func load() -> VoiceSwitchSettings
    func save(_ settings: VoiceSwitchSettings, availableInputSourceIDs: Set<String>?) throws
}

public extension SettingsStoring {
    func save(_ settings: VoiceSwitchSettings) throws {
        try save(settings, availableInputSourceIDs: nil)
    }
}

public protocol InputSourceProviding: Sendable {
    func selectableInputSources() throws -> [InputSourceDescriptor]
}

public protocol InputSourceSwitching: Sendable {
    func currentSelectedInputSourceID() throws -> String?
    func switchToInputSource(id: String) throws
}

public protocol PermissionStatusProviding: Sendable {
    func snapshot() -> PermissionSnapshot
    func requestAccessibilityAuthorization() -> PermissionSnapshot
    func requestInputMonitoringAuthorization() -> PermissionSnapshot
}

public extension PermissionStatusProviding {
    func requestAccessibilityAuthorization() -> PermissionSnapshot {
        snapshot()
    }

    func requestInputMonitoringAuthorization() -> PermissionSnapshot {
        snapshot()
    }
}

public protocol LaunchAtLoginControlling: Sendable {
    func isEnabled() -> Bool
    func setEnabled(_ enabled: Bool) throws
}

public protocol KeyboardEventListening: AnyObject {
    var isRunning: Bool { get }
    func start(eventHandler: @escaping @Sendable (KeyboardEventSummary) -> Void)
    func stop()
}

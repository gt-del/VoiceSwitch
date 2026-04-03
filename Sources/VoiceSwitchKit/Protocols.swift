import Foundation

public protocol SettingsStoring: Sendable {
    func load() -> VoiceSwitchSettings
    func save(_ settings: VoiceSwitchSettings)
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
}

public protocol KeyboardEventListening: AnyObject {
    var isRunning: Bool { get }
    func start(eventHandler: @escaping @Sendable (KeyboardEventSummary) -> Void)
    func stop()
}

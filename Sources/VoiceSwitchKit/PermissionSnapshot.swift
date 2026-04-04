import Foundation

public enum PermissionState: String, Equatable, Sendable {
    case authorized
    case denied
    case unknown
}

public struct PermissionSnapshot: Equatable, Sendable {
    public var accessibility: PermissionState
    public var inputMonitoring: PermissionState
    public var accessibilityTrusted: Bool
    public var inputMonitoringTrusted: Bool
    public var executablePath: String
    public var bundleIdentifier: String?
    public var bundlePath: String?

    public init(
        accessibility: PermissionState,
        inputMonitoring: PermissionState,
        accessibilityTrusted: Bool? = nil,
        inputMonitoringTrusted: Bool? = nil,
        executablePath: String = CommandLine.arguments.first ?? "",
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        bundlePath: String? = Bundle.main.bundleURL.path
    ) {
        self.accessibility = accessibility
        self.inputMonitoring = inputMonitoring
        self.accessibilityTrusted = accessibilityTrusted ?? (accessibility == .authorized)
        self.inputMonitoringTrusted = inputMonitoringTrusted ?? (inputMonitoring == .authorized)
        self.executablePath = executablePath
        self.bundleIdentifier = bundleIdentifier
        self.bundlePath = bundlePath
    }
}

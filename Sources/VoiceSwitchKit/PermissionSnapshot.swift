import Foundation

public enum PermissionState: String, Equatable, Sendable {
    case authorized
    case denied
    case unknown
}

public struct PermissionSnapshot: Equatable, Sendable {
    public var accessibility: PermissionState
    public var inputMonitoring: PermissionState

    public init(accessibility: PermissionState, inputMonitoring: PermissionState) {
        self.accessibility = accessibility
        self.inputMonitoring = inputMonitoring
    }
}

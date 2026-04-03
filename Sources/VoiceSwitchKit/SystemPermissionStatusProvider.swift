import ApplicationServices
import Foundation

public struct SystemPermissionStatusProvider: PermissionStatusProviding, Sendable {
    public init() {}

    public func snapshot() -> PermissionSnapshot {
        PermissionSnapshot(
            accessibility: AXIsProcessTrusted() ? .authorized : .denied,
            inputMonitoring: .unknown
        )
    }
}

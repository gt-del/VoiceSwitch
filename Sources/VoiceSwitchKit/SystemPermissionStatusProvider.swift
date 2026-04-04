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

    public func requestAccessibilityAuthorization() -> PermissionSnapshot {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let isAuthorized = AXIsProcessTrustedWithOptions(options)
        return PermissionSnapshot(
            accessibility: isAuthorized ? .authorized : .denied,
            inputMonitoring: .unknown
        )
    }
}

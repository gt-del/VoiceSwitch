import ApplicationServices
import Foundation

public struct SystemPermissionStatusProvider: PermissionStatusProviding, Sendable {
    public init() {}

    public func snapshot() -> PermissionSnapshot {
        makeSnapshot(
            accessibilityTrusted: AXIsProcessTrusted(),
            inputMonitoringTrusted: CGPreflightListenEventAccess()
        )
    }

    public func requestAccessibilityAuthorization() -> PermissionSnapshot {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let accessibilityTrusted = AXIsProcessTrustedWithOptions(options)
        return makeSnapshot(
            accessibilityTrusted: accessibilityTrusted,
            inputMonitoringTrusted: CGPreflightListenEventAccess()
        )
    }

    public func requestInputMonitoringAuthorization() -> PermissionSnapshot {
        let inputMonitoringTrusted = CGRequestListenEventAccess()
        return makeSnapshot(
            accessibilityTrusted: AXIsProcessTrusted(),
            inputMonitoringTrusted: inputMonitoringTrusted
        )
    }

    private func makeSnapshot(
        accessibilityTrusted: Bool,
        inputMonitoringTrusted: Bool
    ) -> PermissionSnapshot {
        PermissionSnapshot(
            accessibility: accessibilityTrusted ? .authorized : .denied,
            inputMonitoring: inputMonitoringTrusted ? .authorized : .denied,
            accessibilityTrusted: accessibilityTrusted,
            inputMonitoringTrusted: inputMonitoringTrusted
        )
    }
}

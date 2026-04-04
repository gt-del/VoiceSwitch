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
        let executablePath = CommandLine.arguments.first ?? ""
        let bundleIdentifier = Bundle.main.bundleIdentifier
        let bundlePath = Bundle.main.bundleURL.path
        let runtimeIdentityLikelyMismatch =
            (!accessibilityTrusted || !inputMonitoringTrusted) &&
            (
                bundleIdentifier == nil ||
                executablePath.contains("/.build/") ||
                executablePath.contains("/.dev-app/") ||
                bundlePath.contains("/.dev-app/")
            )

        return PermissionSnapshot(
            accessibility: accessibilityTrusted ? .authorized : .denied,
            inputMonitoring: inputMonitoringTrusted ? .authorized : .denied,
            accessibilityTrusted: accessibilityTrusted,
            inputMonitoringTrusted: inputMonitoringTrusted,
            runtimeIdentityLikelyMismatch: runtimeIdentityLikelyMismatch,
            executablePath: executablePath,
            bundleIdentifier: bundleIdentifier,
            bundlePath: bundlePath
        )
    }
}

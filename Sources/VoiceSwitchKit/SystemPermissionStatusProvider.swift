import ApplicationServices
import Foundation
import Security

enum CodeSignatureStyle: Equatable, Sendable {
    case signed
    case adHoc
    case unknown
}

func runtimeIdentityLikelyMismatch(
    accessibilityTrusted: Bool,
    inputMonitoringTrusted: Bool,
    executablePath: String,
    bundleIdentifier: String?,
    bundlePath: String?,
    codeSignatureStyle: CodeSignatureStyle
) -> Bool {
    let permissionsMissing = !accessibilityTrusted || !inputMonitoringTrusted
    guard permissionsMissing else {
        return false
    }

    guard let bundleIdentifier, !bundleIdentifier.isEmpty else {
        return true
    }

    let normalizedBundlePath = bundlePath ?? ""
    if
        executablePath.contains("/.build/") ||
        executablePath.contains("/.dev-app/") ||
        executablePath.contains("/dist/") ||
        normalizedBundlePath.contains("/.dev-app/") ||
        normalizedBundlePath.contains("/dist/")
    {
        return true
    }

    return codeSignatureStyle == .adHoc
}

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
        let codeSignatureStyle = currentCodeSignatureStyle()
        let runtimeIdentityLikelyMismatch = runtimeIdentityLikelyMismatch(
            accessibilityTrusted: accessibilityTrusted,
            inputMonitoringTrusted: inputMonitoringTrusted,
            executablePath: executablePath,
            bundleIdentifier: bundleIdentifier,
            bundlePath: bundlePath,
            codeSignatureStyle: codeSignatureStyle
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

    private func currentCodeSignatureStyle() -> CodeSignatureStyle {
        var staticCode: SecStaticCode?
        let status = SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, SecCSFlags(), &staticCode)
        guard status == errSecSuccess, let staticCode else {
            return .unknown
        }

        var signingInformation: CFDictionary?
        let signingStatus = SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &signingInformation
        )
        guard signingStatus == errSecSuccess, let signingInformation else {
            return .unknown
        }

        let info = signingInformation as NSDictionary
        if let certificates = info[kSecCodeInfoCertificates as String] as? [Any], certificates.isEmpty {
            return .adHoc
        }
        if
            let source = info[kSecCodeInfoSource as String] as? String,
            source.localizedCaseInsensitiveContains("adhoc") ||
            source.localizedCaseInsensitiveContains("ad hoc")
        {
            return .adHoc
        }

        return .signed
    }
}

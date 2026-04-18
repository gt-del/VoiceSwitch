import Testing
@testable import VoiceSwitchKit

struct SystemPermissionStatusProviderTests {
    @Test
    func adHocSignedInstalledBundleWithMissingPermissionIsTreatedAsRuntimeMismatch() {
        let mismatch = runtimeIdentityLikelyMismatch(
            accessibilityTrusted: false,
            inputMonitoringTrusted: true,
            executablePath: "/Applications/VoiceSwitch.app/Contents/MacOS/VoiceSwitchApp",
            bundleIdentifier: "com.gtdel.VoiceSwitch.dev",
            bundlePath: "/Applications/VoiceSwitch.app",
            codeSignatureStyle: .adHoc
        )

        #expect(mismatch == true)
    }

    @Test
    func signedInstalledBundleWithMissingPermissionDoesNotForceRuntimeMismatch() {
        let mismatch = runtimeIdentityLikelyMismatch(
            accessibilityTrusted: false,
            inputMonitoringTrusted: true,
            executablePath: "/Applications/VoiceSwitch.app/Contents/MacOS/VoiceSwitchApp",
            bundleIdentifier: "com.gtdel.VoiceSwitch.dev",
            bundlePath: "/Applications/VoiceSwitch.app",
            codeSignatureStyle: .signed
        )

        #expect(mismatch == false)
    }

    @Test
    func developmentBuildStillCountsAsRuntimeMismatchWithoutBundleIdentity() {
        let mismatch = runtimeIdentityLikelyMismatch(
            accessibilityTrusted: false,
            inputMonitoringTrusted: true,
            executablePath: "/Users/didi/Code/github/per/VoiceSwitch/.build/debug/VoiceSwitchApp",
            bundleIdentifier: nil,
            bundlePath: nil,
            codeSignatureStyle: .unknown
        )

        #expect(mismatch == true)
    }
}

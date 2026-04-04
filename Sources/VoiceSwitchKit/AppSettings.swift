import Foundation

public struct VoiceSwitchSettings: Equatable, Sendable {
    public var primaryInputSourceID: String?
    public var voiceInputSourceID: String?
    public var launchAtLoginEnabled: Bool
    public var voiceActivationDelay: TimeInterval
    public var releaseReturnDelay: TimeInterval
    public var cooldownDuration: TimeInterval

    public init(
        primaryInputSourceID: String? = nil,
        voiceInputSourceID: String? = nil,
        launchAtLoginEnabled: Bool = false,
        voiceActivationDelay: TimeInterval = 0,
        releaseReturnDelay: TimeInterval = 0,
        cooldownDuration: TimeInterval = 5
    ) {
        self.primaryInputSourceID = primaryInputSourceID
        self.voiceInputSourceID = voiceInputSourceID
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.voiceActivationDelay = voiceActivationDelay
        self.releaseReturnDelay = releaseReturnDelay
        self.cooldownDuration = cooldownDuration
    }
}

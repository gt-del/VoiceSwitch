import Foundation

public struct VoiceSwitchSettings: Equatable, Sendable {
    public var primaryInputSourceID: String?
    public var voiceInputSourceID: String?
    public var isEnabled: Bool
    public var launchAtLoginEnabled: Bool
    public var voiceActivationDelay: TimeInterval
    public var primaryReturnDelay: TimeInterval
    public var cooldownDuration: TimeInterval

    public init(
        primaryInputSourceID: String? = nil,
        voiceInputSourceID: String? = nil,
        isEnabled: Bool = true,
        launchAtLoginEnabled: Bool = false,
        voiceActivationDelay: TimeInterval = 0,
        primaryReturnDelay: TimeInterval = 0,
        cooldownDuration: TimeInterval = 5
    ) {
        self.primaryInputSourceID = primaryInputSourceID
        self.voiceInputSourceID = voiceInputSourceID
        self.isEnabled = isEnabled
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.voiceActivationDelay = voiceActivationDelay
        self.primaryReturnDelay = primaryReturnDelay
        self.cooldownDuration = cooldownDuration
    }
}

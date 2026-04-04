import Foundation

public struct VoiceSwitchSettings: Equatable, Sendable {
    public var primaryInputSourceID: String?
    public var voiceInputSourceID: String?
    public var launchAtLoginEnabled: Bool
    public var optionPendingWindow: TimeInterval
    public var cooldownDuration: TimeInterval
    public var voiceExitDelay: TimeInterval

    public init(
        primaryInputSourceID: String? = nil,
        voiceInputSourceID: String? = nil,
        launchAtLoginEnabled: Bool = false,
        optionPendingWindow: TimeInterval = 0.18,
        cooldownDuration: TimeInterval = 5,
        voiceExitDelay: TimeInterval = 10
    ) {
        self.primaryInputSourceID = primaryInputSourceID
        self.voiceInputSourceID = voiceInputSourceID
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.optionPendingWindow = optionPendingWindow
        self.cooldownDuration = cooldownDuration
        self.voiceExitDelay = voiceExitDelay
    }
}

import Foundation

public struct VoiceSwitchSettings: Equatable, Sendable {
    public var primaryInputSourceID: String?
    public var voiceInputSourceID: String?
    public var isEnabled: Bool
    public var launchAtLoginEnabled: Bool
    public var switchToVoiceDelay: TimeInterval
    public var switchToPrimaryDelay: TimeInterval
    public var cooldownDuration: TimeInterval

    public init(
        primaryInputSourceID: String? = nil,
        voiceInputSourceID: String? = nil,
        isEnabled: Bool = true,
        launchAtLoginEnabled: Bool = false,
        switchToVoiceDelay: TimeInterval = 0,
        switchToPrimaryDelay: TimeInterval = 0,
        cooldownDuration: TimeInterval = 5
    ) {
        self.primaryInputSourceID = primaryInputSourceID
        self.voiceInputSourceID = voiceInputSourceID
        self.isEnabled = isEnabled
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.switchToVoiceDelay = switchToVoiceDelay
        self.switchToPrimaryDelay = switchToPrimaryDelay
        self.cooldownDuration = cooldownDuration
    }
}

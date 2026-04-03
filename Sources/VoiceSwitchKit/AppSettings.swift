import Foundation

public struct VoiceSwitchSettings: Equatable, Sendable {
    public var primaryInputSourceID: String?
    public var voiceInputSourceID: String?
    public var launchAtLoginEnabled: Bool

    public init(
        primaryInputSourceID: String? = nil,
        voiceInputSourceID: String? = nil,
        launchAtLoginEnabled: Bool = false
    ) {
        self.primaryInputSourceID = primaryInputSourceID
        self.voiceInputSourceID = voiceInputSourceID
        self.launchAtLoginEnabled = launchAtLoginEnabled
    }
}

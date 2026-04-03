import Foundation

public final class UserDefaultsSettingsStore: SettingsStoring, @unchecked Sendable {
    private enum Keys {
        static let primaryInputSourceID = "voiceSwitch.primaryInputSourceID"
        static let voiceInputSourceID = "voiceSwitch.voiceInputSourceID"
        static let launchAtLoginEnabled = "voiceSwitch.launchAtLoginEnabled"
    }

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func load() -> VoiceSwitchSettings {
        VoiceSwitchSettings(
            primaryInputSourceID: userDefaults.string(forKey: Keys.primaryInputSourceID),
            voiceInputSourceID: userDefaults.string(forKey: Keys.voiceInputSourceID),
            launchAtLoginEnabled: userDefaults.bool(forKey: Keys.launchAtLoginEnabled)
        )
    }

    public func save(_ settings: VoiceSwitchSettings) {
        userDefaults.set(settings.primaryInputSourceID, forKey: Keys.primaryInputSourceID)
        userDefaults.set(settings.voiceInputSourceID, forKey: Keys.voiceInputSourceID)
        userDefaults.set(settings.launchAtLoginEnabled, forKey: Keys.launchAtLoginEnabled)
    }
}

import Foundation

public final class UserDefaultsSettingsStore: SettingsStoring, @unchecked Sendable {
    private static let legacyVoiceExitDelayDefault = 0.8

    private enum Keys {
        static let primaryInputSourceID = "voiceSwitch.primaryInputSourceID"
        static let voiceInputSourceID = "voiceSwitch.voiceInputSourceID"
        static let launchAtLoginEnabled = "voiceSwitch.launchAtLoginEnabled"
        static let optionPendingWindow = "voiceSwitch.optionPendingWindow"
        static let cooldownDuration = "voiceSwitch.cooldownDuration"
        static let voiceExitDelay = "voiceSwitch.voiceExitDelay"
    }

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func load() -> VoiceSwitchSettings {
        let defaults = VoiceSwitchSettings()
        let storedVoiceExitDelay = userDefaults.object(forKey: Keys.voiceExitDelay) == nil
            ? nil
            : userDefaults.double(forKey: Keys.voiceExitDelay)
        let resolvedVoiceExitDelay: TimeInterval
        if let storedVoiceExitDelay {
            resolvedVoiceExitDelay = storedVoiceExitDelay == Self.legacyVoiceExitDelayDefault
                ? defaults.voiceExitDelay
                : storedVoiceExitDelay
        } else {
            resolvedVoiceExitDelay = defaults.voiceExitDelay
        }

        return VoiceSwitchSettings(
            primaryInputSourceID: userDefaults.string(forKey: Keys.primaryInputSourceID),
            voiceInputSourceID: userDefaults.string(forKey: Keys.voiceInputSourceID),
            launchAtLoginEnabled: userDefaults.bool(forKey: Keys.launchAtLoginEnabled),
            optionPendingWindow: userDefaults.object(forKey: Keys.optionPendingWindow) == nil
                ? defaults.optionPendingWindow
                : userDefaults.double(forKey: Keys.optionPendingWindow),
            cooldownDuration: userDefaults.object(forKey: Keys.cooldownDuration) == nil
                ? defaults.cooldownDuration
                : userDefaults.double(forKey: Keys.cooldownDuration),
            voiceExitDelay: resolvedVoiceExitDelay
        )
    }

    public func save(_ settings: VoiceSwitchSettings) {
        userDefaults.set(settings.primaryInputSourceID, forKey: Keys.primaryInputSourceID)
        userDefaults.set(settings.voiceInputSourceID, forKey: Keys.voiceInputSourceID)
        userDefaults.set(settings.launchAtLoginEnabled, forKey: Keys.launchAtLoginEnabled)
        userDefaults.set(settings.optionPendingWindow, forKey: Keys.optionPendingWindow)
        userDefaults.set(settings.cooldownDuration, forKey: Keys.cooldownDuration)
        userDefaults.set(settings.voiceExitDelay, forKey: Keys.voiceExitDelay)
    }
}

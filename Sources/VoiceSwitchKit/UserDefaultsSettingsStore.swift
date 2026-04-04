import Foundation

public final class UserDefaultsSettingsStore: SettingsStoring, @unchecked Sendable {
    private enum Keys {
        static let primaryInputSourceID = "voiceSwitch.primaryInputSourceID"
        static let voiceInputSourceID = "voiceSwitch.voiceInputSourceID"
        static let isEnabled = "voiceSwitch.isEnabled"
        static let launchAtLoginEnabled = "voiceSwitch.launchAtLoginEnabled"
        static let voiceActivationDelay = "voiceSwitch.voiceActivationDelay"
        static let releaseReturnDelay = "voiceSwitch.releaseReturnDelay"
        static let cooldownDuration = "voiceSwitch.cooldownDuration"
        static let legacyOptionPendingWindow = "voiceSwitch.optionPendingWindow"
        static let legacyVoiceExitDelay = "voiceSwitch.voiceExitDelay"
    }

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func load() -> VoiceSwitchSettings {
        let defaults = VoiceSwitchSettings()

        return VoiceSwitchSettings(
            primaryInputSourceID: userDefaults.string(forKey: Keys.primaryInputSourceID),
            voiceInputSourceID: userDefaults.string(forKey: Keys.voiceInputSourceID),
            isEnabled: userDefaults.object(forKey: Keys.isEnabled) == nil
                ? defaults.isEnabled
                : userDefaults.bool(forKey: Keys.isEnabled),
            launchAtLoginEnabled: userDefaults.bool(forKey: Keys.launchAtLoginEnabled),
            voiceActivationDelay: loadDelay(
                primaryKey: Keys.voiceActivationDelay,
                legacyKey: Keys.legacyOptionPendingWindow,
                defaultValue: defaults.voiceActivationDelay
            ),
            releaseReturnDelay: loadDelay(
                primaryKey: Keys.releaseReturnDelay,
                legacyKey: Keys.legacyVoiceExitDelay,
                defaultValue: defaults.releaseReturnDelay
            ),
            cooldownDuration: userDefaults.object(forKey: Keys.cooldownDuration) == nil
                ? defaults.cooldownDuration
                : userDefaults.double(forKey: Keys.cooldownDuration)
        )
    }

    public func save(_ settings: VoiceSwitchSettings) {
        userDefaults.set(settings.primaryInputSourceID, forKey: Keys.primaryInputSourceID)
        userDefaults.set(settings.voiceInputSourceID, forKey: Keys.voiceInputSourceID)
        userDefaults.set(settings.isEnabled, forKey: Keys.isEnabled)
        userDefaults.set(settings.launchAtLoginEnabled, forKey: Keys.launchAtLoginEnabled)
        userDefaults.set(settings.voiceActivationDelay, forKey: Keys.voiceActivationDelay)
        userDefaults.set(settings.releaseReturnDelay, forKey: Keys.releaseReturnDelay)
        userDefaults.set(settings.cooldownDuration, forKey: Keys.cooldownDuration)
    }

    private func loadDelay(primaryKey: String, legacyKey: String, defaultValue: TimeInterval) -> TimeInterval {
        if userDefaults.object(forKey: primaryKey) != nil {
            return sanitizedDelay(userDefaults.double(forKey: primaryKey), defaultValue: defaultValue)
        }
        if userDefaults.object(forKey: legacyKey) != nil {
            return sanitizedDelay(userDefaults.double(forKey: legacyKey), defaultValue: defaultValue)
        }
        return defaultValue
    }

    private func sanitizedDelay(_ value: TimeInterval, defaultValue: TimeInterval) -> TimeInterval {
        guard value.isFinite, (0.0...0.3).contains(value) else {
            return defaultValue
        }
        return value
    }
}

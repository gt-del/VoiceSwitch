import Foundation

public enum VoiceSwitchSettingsValidationError: LocalizedError, Equatable, Sendable {
    case primaryInputSourceMissing
    case voiceInputSourceMissing
    case duplicateInputSources
    case primaryInputSourceUnavailable(String)
    case voiceInputSourceUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .primaryInputSourceMissing:
            return "默认输入法不能为空。"
        case .voiceInputSourceMissing:
            return "语音输入法不能为空。"
        case .duplicateInputSources:
            return "默认输入法和语音输入法不能相同。"
        case let .primaryInputSourceUnavailable(inputSourceID):
            return "默认输入法不在当前可选列表中：\(inputSourceID)"
        case let .voiceInputSourceUnavailable(inputSourceID):
            return "语音输入法不在当前可选列表中：\(inputSourceID)"
        }
    }
}

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
    private let legacyDomainNames: [String]

    public init(
        userDefaults: UserDefaults = .standard,
        legacyDomainNames: [String] = ["VoiceSwitchApp"]
    ) {
        self.userDefaults = userDefaults
        self.legacyDomainNames = legacyDomainNames
    }

    public func load() -> VoiceSwitchSettings {
        let defaults = VoiceSwitchSettings()
        migrateLegacyPreferencesIfNeeded(defaults: defaults)

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

    public func save(_ settings: VoiceSwitchSettings, availableInputSourceIDs: Set<String>? = nil) throws {
        try validate(settings: settings, availableInputSourceIDs: availableInputSourceIDs)
        persistValidatedSettings(settings)
    }

    private func persistValidatedSettings(_ settings: VoiceSwitchSettings) {
        userDefaults.set(settings.primaryInputSourceID, forKey: Keys.primaryInputSourceID)
        userDefaults.set(settings.voiceInputSourceID, forKey: Keys.voiceInputSourceID)
        userDefaults.set(settings.isEnabled, forKey: Keys.isEnabled)
        userDefaults.set(settings.launchAtLoginEnabled, forKey: Keys.launchAtLoginEnabled)
        userDefaults.set(settings.voiceActivationDelay, forKey: Keys.voiceActivationDelay)
        userDefaults.set(settings.releaseReturnDelay, forKey: Keys.releaseReturnDelay)
        userDefaults.set(settings.cooldownDuration, forKey: Keys.cooldownDuration)
        purgeLegacyKeys()
    }

    public func validate(
        settings: VoiceSwitchSettings,
        availableInputSourceIDs: Set<String>? = nil
    ) throws {
        guard let primaryInputSourceID = settings.primaryInputSourceID, !primaryInputSourceID.isEmpty else {
            throw VoiceSwitchSettingsValidationError.primaryInputSourceMissing
        }
        guard let voiceInputSourceID = settings.voiceInputSourceID, !voiceInputSourceID.isEmpty else {
            throw VoiceSwitchSettingsValidationError.voiceInputSourceMissing
        }
        guard primaryInputSourceID != voiceInputSourceID else {
            throw VoiceSwitchSettingsValidationError.duplicateInputSources
        }
        if let availableInputSourceIDs {
            guard availableInputSourceIDs.contains(primaryInputSourceID) else {
                throw VoiceSwitchSettingsValidationError.primaryInputSourceUnavailable(primaryInputSourceID)
            }
            guard availableInputSourceIDs.contains(voiceInputSourceID) else {
                throw VoiceSwitchSettingsValidationError.voiceInputSourceUnavailable(voiceInputSourceID)
            }
        }
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

    private func migrateLegacyPreferencesIfNeeded(defaults: VoiceSwitchSettings) {
        let migratedSettings = VoiceSwitchSettings(
            primaryInputSourceID: firstNonEmptyString(
                currentKey: Keys.primaryInputSourceID,
                legacyKey: Keys.primaryInputSourceID
            ),
            voiceInputSourceID: firstNonEmptyString(
                currentKey: Keys.voiceInputSourceID,
                legacyKey: Keys.voiceInputSourceID
            ),
            isEnabled: firstBool(
                currentKey: Keys.isEnabled,
                legacyKey: Keys.isEnabled,
                defaultValue: defaults.isEnabled
            ),
            launchAtLoginEnabled: firstBool(
                currentKey: Keys.launchAtLoginEnabled,
                legacyKey: Keys.launchAtLoginEnabled,
                defaultValue: defaults.launchAtLoginEnabled
            ),
            voiceActivationDelay: firstDelay(
                currentKey: Keys.voiceActivationDelay,
                currentLegacyKey: Keys.legacyOptionPendingWindow,
                legacyKey: Keys.voiceActivationDelay,
                legacyFallbackKey: Keys.legacyOptionPendingWindow,
                defaultValue: defaults.voiceActivationDelay
            ),
            releaseReturnDelay: firstDelay(
                currentKey: Keys.releaseReturnDelay,
                currentLegacyKey: Keys.legacyVoiceExitDelay,
                legacyKey: Keys.releaseReturnDelay,
                legacyFallbackKey: Keys.legacyVoiceExitDelay,
                defaultValue: defaults.releaseReturnDelay
            ),
            cooldownDuration: firstDouble(
                currentKey: Keys.cooldownDuration,
                legacyKey: Keys.cooldownDuration,
                defaultValue: defaults.cooldownDuration
            )
        )

        do {
            try validate(settings: migratedSettings)
            persistValidatedSettings(migratedSettings)
        } catch {
            // Skip persisting invalid legacy configurations, but still clear the old domain.
        }
        removeLegacyDomains()
    }

    private func firstNonEmptyString(currentKey: String, legacyKey: String) -> String? {
        if let current = userDefaults.string(forKey: currentKey) {
            return current
        }

        for domain in legacyDomainNames {
            if let value = userDefaults.persistentDomain(forName: domain)?[legacyKey] as? String {
                return value
            }
        }

        return nil
    }

    private func firstBool(currentKey: String, legacyKey: String, defaultValue: Bool) -> Bool {
        if userDefaults.object(forKey: currentKey) != nil {
            return userDefaults.bool(forKey: currentKey)
        }

        for domain in legacyDomainNames {
            if let value = userDefaults.persistentDomain(forName: domain)?[legacyKey] as? Bool {
                return value
            }
        }

        return defaultValue
    }

    private func firstDouble(currentKey: String, legacyKey: String, defaultValue: Double) -> Double {
        if userDefaults.object(forKey: currentKey) != nil {
            return userDefaults.double(forKey: currentKey)
        }

        for domain in legacyDomainNames {
            if let value = userDefaults.persistentDomain(forName: domain)?[legacyKey] as? Double {
                return value
            }
            if let value = userDefaults.persistentDomain(forName: domain)?[legacyKey] as? NSNumber {
                return value.doubleValue
            }
        }

        return defaultValue
    }

    private func firstDelay(
        currentKey: String,
        currentLegacyKey: String,
        legacyKey: String,
        legacyFallbackKey: String,
        defaultValue: TimeInterval
    ) -> TimeInterval {
        if userDefaults.object(forKey: currentKey) != nil {
            return sanitizedDelay(userDefaults.double(forKey: currentKey), defaultValue: defaultValue)
        }
        if userDefaults.object(forKey: currentLegacyKey) != nil {
            return sanitizedDelay(userDefaults.double(forKey: currentLegacyKey), defaultValue: defaultValue)
        }

        for domain in legacyDomainNames {
            if let value = domainDouble(forName: domain, key: legacyKey) {
                return sanitizedDelay(value, defaultValue: defaultValue)
            }
            if let value = domainDouble(forName: domain, key: legacyFallbackKey) {
                return sanitizedDelay(value, defaultValue: defaultValue)
            }
        }

        return defaultValue
    }

    private func domainDouble(forName domain: String, key: String) -> Double? {
        guard let domainValues = userDefaults.persistentDomain(forName: domain) else {
            return nil
        }
        if let value = domainValues[key] as? Double {
            return value
        }
        if let value = domainValues[key] as? NSNumber {
            return value.doubleValue
        }
        return nil
    }

    private func purgeLegacyKeys() {
        userDefaults.removeObject(forKey: Keys.legacyOptionPendingWindow)
        userDefaults.removeObject(forKey: Keys.legacyVoiceExitDelay)
    }

    private func removeLegacyDomains() {
        for domain in legacyDomainNames {
            userDefaults.removePersistentDomain(forName: domain)
        }
    }
}

import Foundation
import Testing
@testable import VoiceSwitchKit

struct UserDefaultsSettingsStoreTests {
    @Test
    func saveAndLoadRoundTrip() throws {
        let defaults = UserDefaults(suiteName: #function)!
        let legacyDomain = "\(#function).legacy"
        defaults.removePersistentDomain(forName: #function)
        defaults.removePersistentDomain(forName: legacyDomain)

        let store = UserDefaultsSettingsStore(userDefaults: defaults, legacyDomainNames: [])
        let expected = VoiceSwitchSettings(
            primaryInputSourceID: "com.apple.keylayout.ABC",
            voiceInputSourceID: "com.example.voice",
            isEnabled: false,
            launchAtLoginEnabled: true,
            voiceActivationDelay: 0.25,
            primaryReturnDelay: 0.1,
            cooldownDuration: 7,
        )

        try store.save(expected)

        let actual = store.load()

        #expect(actual == expected)
    }

    @Test
    func loadUsesNewDelayDefaults() {
        let defaults = UserDefaults(suiteName: #function)!
        let legacyDomain = "\(#function).legacy"
        defaults.removePersistentDomain(forName: #function)
        defaults.removePersistentDomain(forName: legacyDomain)

        let store = UserDefaultsSettingsStore(userDefaults: defaults, legacyDomainNames: [])
        let actual = store.load()

        #expect(actual.isEnabled)
        #expect(actual.voiceActivationDelay == 0)
        #expect(actual.primaryReturnDelay == 0)
    }

    @Test
    func loadMigratesLegacyDelayKeys() {
        let defaults = UserDefaults(suiteName: #function)!
        let legacyDomain = "\(#function).legacy"
        defaults.removePersistentDomain(forName: #function)
        defaults.removePersistentDomain(forName: legacyDomain)
        defaults.set(0.18, forKey: "voiceSwitch.voiceActivationDelay")
        defaults.set(0.1, forKey: "voiceSwitch.primaryReturnDelay")

        let store = UserDefaultsSettingsStore(userDefaults: defaults, legacyDomainNames: [])
        let actual = store.load()

        #expect(actual.voiceActivationDelay == 0.18)
        #expect(actual.primaryReturnDelay == 0.1)
    }

    @Test
    func loadResetsOutOfRangeDelayValuesToDefaults() {
        let defaults = UserDefaults(suiteName: #function)!
        let legacyDomain = "\(#function).legacy"
        defaults.removePersistentDomain(forName: #function)
        defaults.removePersistentDomain(forName: legacyDomain)
        defaults.set(0.8, forKey: "voiceSwitch.primaryReturnDelay")
        defaults.set(0.6, forKey: "voiceSwitch.voiceActivationDelay")

        let store = UserDefaultsSettingsStore(userDefaults: defaults, legacyDomainNames: [])
        let actual = store.load()

        #expect(actual.voiceActivationDelay == 0)
        #expect(actual.primaryReturnDelay == 0)
    }

    @Test
    func loadMigratesLegacyVoiceSwitchAppDomainAndDeletesIt() {
        let defaults = UserDefaults(suiteName: #function)!
        let legacyDomain = "\(#function).legacy"
        defaults.removePersistentDomain(forName: #function)
        defaults.removePersistentDomain(forName: legacyDomain)
        defaults.setPersistentDomain(
            [
                "voiceSwitch.primaryInputSourceID": "im.rime.inputmethod.Squirrel.Hans",
                "voiceSwitch.voiceInputSourceID": "com.bytedance.inputmethod.doubaoime.pinyin",
                "voiceSwitch.voiceActivationDelay": 0.18,
                "voiceSwitch.primaryReturnDelay": 0.8,
            ],
            forName: legacyDomain
        )

        let store = UserDefaultsSettingsStore(
            userDefaults: defaults,
            legacyDomainNames: [legacyDomain]
        )
        let actual = store.load()

        #expect(actual.primaryInputSourceID == "im.rime.inputmethod.Squirrel.Hans")
        #expect(actual.voiceInputSourceID == "com.bytedance.inputmethod.doubaoime.pinyin")
        #expect(actual.voiceActivationDelay == 0.18)
        #expect(actual.primaryReturnDelay == 0)
        #expect(defaults.persistentDomain(forName: legacyDomain) == nil)
    }

    @Test
    func savePurgesLegacyDelayKeysFromCurrentDomain() throws {
        let defaults = UserDefaults(suiteName: #function)!
        let legacyDomain = "\(#function).legacy"
        defaults.removePersistentDomain(forName: #function)
        defaults.removePersistentDomain(forName: legacyDomain)
        defaults.set(0.8, forKey: "voiceSwitch.primaryReturnDelay")

        let store = UserDefaultsSettingsStore(userDefaults: defaults, legacyDomainNames: [])
        try store.save(
            VoiceSwitchSettings(
                primaryInputSourceID: "im.rime.inputmethod.Squirrel.Hans",
                voiceInputSourceID: "com.bytedance.inputmethod.doubaoime.pinyin",
                voiceActivationDelay: 0,
                primaryReturnDelay: 0,
                cooldownDuration: 5
            )
        )

        #expect(defaults.object(forKey: "voiceSwitch.primaryReturnDelay") != nil)
    }

    @Test
    func saveRejectsInvalidConfiguration() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = UserDefaultsSettingsStore(userDefaults: defaults, legacyDomainNames: [])

        #expect(throws: VoiceSwitchSettingsValidationError.duplicateInputSources) {
            try store.save(
                VoiceSwitchSettings(
                    primaryInputSourceID: "same.id",
                    voiceInputSourceID: "same.id"
                ),
                availableInputSourceIDs: ["same.id"]
            )
        }
    }

    @Test
    func saveRejectsInputSourcesOutsideProvidedContext() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = UserDefaultsSettingsStore(userDefaults: defaults, legacyDomainNames: [])

        #expect(throws: VoiceSwitchSettingsValidationError.primaryInputSourceUnavailable("missing.primary")) {
            try store.save(
                VoiceSwitchSettings(
                    primaryInputSourceID: "missing.primary",
                    voiceInputSourceID: "voice.id"
                ),
                availableInputSourceIDs: ["voice.id"]
            )
        }
    }
}

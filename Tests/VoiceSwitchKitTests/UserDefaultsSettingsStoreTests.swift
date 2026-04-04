import Foundation
import Testing
@testable import VoiceSwitchKit

struct UserDefaultsSettingsStoreTests {
    @Test
    func saveAndLoadRoundTrip() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.removePersistentDomain(forName: "VoiceSwitchApp")

        let store = UserDefaultsSettingsStore(userDefaults: defaults, legacyDomainNames: [])
        let expected = VoiceSwitchSettings(
            primaryInputSourceID: "com.apple.keylayout.ABC",
            voiceInputSourceID: "com.example.voice",
            isEnabled: false,
            launchAtLoginEnabled: true,
            voiceActivationDelay: 0.25,
            releaseReturnDelay: 0.1,
            cooldownDuration: 7,
        )

        store.save(expected)

        let actual = store.load()

        #expect(actual == expected)
    }

    @Test
    func loadUsesNewDelayDefaults() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.removePersistentDomain(forName: "VoiceSwitchApp")

        let store = UserDefaultsSettingsStore(userDefaults: defaults, legacyDomainNames: [])
        let actual = store.load()

        #expect(actual.isEnabled)
        #expect(actual.voiceActivationDelay == 0)
        #expect(actual.releaseReturnDelay == 0)
    }

    @Test
    func loadMigratesLegacyDelayKeys() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.removePersistentDomain(forName: "VoiceSwitchApp")
        defaults.set(0.18, forKey: "voiceSwitch.optionPendingWindow")
        defaults.set(0.1, forKey: "voiceSwitch.voiceExitDelay")

        let store = UserDefaultsSettingsStore(userDefaults: defaults, legacyDomainNames: [])
        let actual = store.load()

        #expect(actual.voiceActivationDelay == 0.18)
        #expect(actual.releaseReturnDelay == 0.1)
    }

    @Test
    func loadResetsOutOfRangeDelayValuesToDefaults() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.removePersistentDomain(forName: "VoiceSwitchApp")
        defaults.set(0.8, forKey: "voiceSwitch.releaseReturnDelay")
        defaults.set(0.6, forKey: "voiceSwitch.optionPendingWindow")

        let store = UserDefaultsSettingsStore(userDefaults: defaults, legacyDomainNames: [])
        let actual = store.load()

        #expect(actual.voiceActivationDelay == 0)
        #expect(actual.releaseReturnDelay == 0)
    }

    @Test
    func loadMigratesLegacyVoiceSwitchAppDomainAndDeletesIt() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.removePersistentDomain(forName: "VoiceSwitchApp")
        defaults.setPersistentDomain(
            [
                "voiceSwitch.primaryInputSourceID": "im.rime.inputmethod.Squirrel.Hans",
                "voiceSwitch.voiceInputSourceID": "com.bytedance.inputmethod.doubaoime.pinyin",
                "voiceSwitch.optionPendingWindow": 0.18,
                "voiceSwitch.voiceExitDelay": 0.8,
            ],
            forName: "VoiceSwitchApp"
        )

        let store = UserDefaultsSettingsStore(
            userDefaults: defaults,
            legacyDomainNames: ["VoiceSwitchApp"]
        )
        let actual = store.load()

        #expect(actual.primaryInputSourceID == "im.rime.inputmethod.Squirrel.Hans")
        #expect(actual.voiceInputSourceID == "com.bytedance.inputmethod.doubaoime.pinyin")
        #expect(actual.voiceActivationDelay == 0.18)
        #expect(actual.releaseReturnDelay == 0)
        #expect(defaults.persistentDomain(forName: "VoiceSwitchApp") == nil)
    }

    @Test
    func savePurgesLegacyDelayKeysFromCurrentDomain() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.removePersistentDomain(forName: "VoiceSwitchApp")
        defaults.set(0.18, forKey: "voiceSwitch.optionPendingWindow")
        defaults.set(0.8, forKey: "voiceSwitch.voiceExitDelay")

        let store = UserDefaultsSettingsStore(userDefaults: defaults, legacyDomainNames: [])
        store.save(
            VoiceSwitchSettings(
                primaryInputSourceID: "im.rime.inputmethod.Squirrel.Hans",
                voiceInputSourceID: "com.bytedance.inputmethod.doubaoime.pinyin",
                voiceActivationDelay: 0,
                releaseReturnDelay: 0,
                cooldownDuration: 5
            )
        )

        #expect(defaults.object(forKey: "voiceSwitch.optionPendingWindow") == nil)
        #expect(defaults.object(forKey: "voiceSwitch.voiceExitDelay") == nil)
    }
}

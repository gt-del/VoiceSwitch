import Foundation
import Testing
@testable import VoiceSwitchKit

struct UserDefaultsSettingsStoreTests {
    @Test
    func saveAndLoadRoundTrip() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let store = UserDefaultsSettingsStore(userDefaults: defaults)
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

        let store = UserDefaultsSettingsStore(userDefaults: defaults)
        let actual = store.load()

        #expect(actual.isEnabled)
        #expect(actual.voiceActivationDelay == 0)
        #expect(actual.releaseReturnDelay == 0)
    }

    @Test
    func loadMigratesLegacyDelayKeys() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(0.18, forKey: "voiceSwitch.optionPendingWindow")
        defaults.set(0.1, forKey: "voiceSwitch.voiceExitDelay")

        let store = UserDefaultsSettingsStore(userDefaults: defaults)
        let actual = store.load()

        #expect(actual.voiceActivationDelay == 0.18)
        #expect(actual.releaseReturnDelay == 0.1)
    }

    @Test
    func loadResetsOutOfRangeDelayValuesToDefaults() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(0.8, forKey: "voiceSwitch.releaseReturnDelay")
        defaults.set(0.6, forKey: "voiceSwitch.optionPendingWindow")

        let store = UserDefaultsSettingsStore(userDefaults: defaults)
        let actual = store.load()

        #expect(actual.voiceActivationDelay == 0)
        #expect(actual.releaseReturnDelay == 0)
    }
}

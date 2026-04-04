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
            launchAtLoginEnabled: true,
            optionPendingWindow: 0.25,
            cooldownDuration: 7,
            voiceExitDelay: 1.2
        )

        store.save(expected)

        let actual = store.load()

        #expect(actual == expected)
    }

    @Test
    func loadUsesExpandedVoiceExitDelayDefault() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let store = UserDefaultsSettingsStore(userDefaults: defaults)
        let actual = store.load()

        #expect(actual.voiceExitDelay == 10)
    }

    @Test
    func loadMigratesLegacyVoiceExitDelayDefault() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(0.8, forKey: "voiceSwitch.voiceExitDelay")

        let store = UserDefaultsSettingsStore(userDefaults: defaults)
        let actual = store.load()

        #expect(actual.voiceExitDelay == 10)
    }
}

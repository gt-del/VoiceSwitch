import Foundation
import Testing
@testable import VoiceSwitchKit

@MainActor
struct VoiceSwitchAppModelTests {
    @Test
    func loadReadsSavedSelectionsSourcesAndPermissions() throws {
        let store = InMemorySettingsStore(
            initial: VoiceSwitchSettings(
                primaryInputSourceID: "primary.id",
                voiceInputSourceID: "voice.id"
            )
        )
        let provider = StubInputSourceProvider(
            sources: [
                InputSourceDescriptor(id: "primary.id", displayName: "ABC", isSelected: true),
                InputSourceDescriptor(id: "voice.id", displayName: "Voice", isSelected: false),
            ]
        )
        let permissions = StubPermissionProvider(
            current: PermissionSnapshot(accessibility: .authorized, inputMonitoring: .unknown)
        )
        let model = VoiceSwitchAppModel(
            settingsStore: store,
            inputSourceProvider: provider,
            permissionProvider: permissions
        )

        try model.load()

        #expect(model.selectedPrimaryInputSourceID == "primary.id")
        #expect(model.selectedVoiceInputSourceID == "voice.id")
        #expect(model.availableInputSources.count == 2)
        #expect(model.permissionSnapshot == permissions.snapshot())
    }

    @Test
    func saveSelectionsPersistsCurrentValues() {
        let store = InMemorySettingsStore(initial: VoiceSwitchSettings())
        let model = VoiceSwitchAppModel(
            settingsStore: store,
            inputSourceProvider: StubInputSourceProvider(sources: []),
            permissionProvider: StubPermissionProvider(current: PermissionSnapshot(accessibility: .unknown, inputMonitoring: .unknown))
        )

        model.selectedPrimaryInputSourceID = "com.apple.keylayout.ABC"
        model.selectedVoiceInputSourceID = "com.example.voice"

        model.saveSelections()

        #expect(store.saved == VoiceSwitchSettings(primaryInputSourceID: "com.apple.keylayout.ABC", voiceInputSourceID: "com.example.voice"))
    }
}

private final class InMemorySettingsStore: SettingsStoring, @unchecked Sendable {
    private let initial: VoiceSwitchSettings
    var saved: VoiceSwitchSettings?

    init(initial: VoiceSwitchSettings) {
        self.initial = initial
    }

    func load() -> VoiceSwitchSettings {
        saved ?? initial
    }

    func save(_ settings: VoiceSwitchSettings) {
        saved = settings
    }
}

private struct StubInputSourceProvider: InputSourceProviding, Sendable {
    let sources: [InputSourceDescriptor]

    func selectableInputSources() throws -> [InputSourceDescriptor] {
        sources
    }
}

private struct StubPermissionProvider: PermissionStatusProviding, Sendable {
    let current: PermissionSnapshot

    func snapshot() -> PermissionSnapshot {
        current
    }
}

import Foundation
import Observation

@MainActor
@Observable
public final class VoiceSwitchAppModel {
    public private(set) var availableInputSources: [InputSourceDescriptor]
    public private(set) var permissionSnapshot: PermissionSnapshot
    public private(set) var configurationIssues: [String]
    public var selectedPrimaryInputSourceID: String?
    public var selectedVoiceInputSourceID: String?
    public var launchAtLoginEnabled: Bool
    public var logEntries: [String]

    private let settingsStore: SettingsStoring
    private let inputSourceProvider: InputSourceProviding
    private let permissionProvider: PermissionStatusProviding

    public init(
        settingsStore: SettingsStoring,
        inputSourceProvider: InputSourceProviding,
        permissionProvider: PermissionStatusProviding
    ) {
        self.settingsStore = settingsStore
        self.inputSourceProvider = inputSourceProvider
        self.permissionProvider = permissionProvider
        self.availableInputSources = []
        self.permissionSnapshot = PermissionSnapshot(accessibility: .unknown, inputMonitoring: .unknown)
        self.configurationIssues = []
        self.selectedPrimaryInputSourceID = nil
        self.selectedVoiceInputSourceID = nil
        self.launchAtLoginEnabled = false
        self.logEntries = []
    }

    public func load() throws {
        let settings = settingsStore.load()
        availableInputSources = try inputSourceProvider.selectableInputSources()
        permissionSnapshot = permissionProvider.snapshot()
        configurationIssues = []
        let availableIDs = Set(availableInputSources.map(\.id))

        if let primaryID = settings.primaryInputSourceID, !availableIDs.contains(primaryID) {
            selectedPrimaryInputSourceID = nil
            configurationIssues.append("Primary IME is no longer available. Please choose another input source.")
            logEntries.append("Primary IME configuration became unavailable: \(primaryID)")
        } else {
            selectedPrimaryInputSourceID = settings.primaryInputSourceID
        }

        if let voiceID = settings.voiceInputSourceID, !availableIDs.contains(voiceID) {
            selectedVoiceInputSourceID = nil
            configurationIssues.append("Voice IME is no longer available. Please choose another input source.")
            logEntries.append("Voice IME configuration became unavailable: \(voiceID)")
        } else {
            selectedVoiceInputSourceID = settings.voiceInputSourceID
        }

        launchAtLoginEnabled = settings.launchAtLoginEnabled
    }

    public func saveSelections() {
        let settings = VoiceSwitchSettings(
            primaryInputSourceID: selectedPrimaryInputSourceID,
            voiceInputSourceID: selectedVoiceInputSourceID,
            launchAtLoginEnabled: launchAtLoginEnabled
        )
        settingsStore.save(settings)
        logEntries.append("Saved settings at \(Date.now.formatted(date: .omitted, time: .standard))")
    }
}

import Foundation
import Observation

@MainActor
@Observable
public final class VoiceSwitchAppModel {
    public private(set) var availableInputSources: [InputSourceDescriptor]
    public private(set) var permissionSnapshot: PermissionSnapshot
    public private(set) var configurationIssues: [String]
    public private(set) var currentEngineState: EngineState
    public private(set) var lastInputBehavior: InputBehavior?
    public private(set) var lastEngineAction: EngineAction?
    public var selectedPrimaryInputSourceID: String?
    public var selectedVoiceInputSourceID: String?
    public var launchAtLoginEnabled: Bool
    public var logEntries: [String]

    private let settingsStore: SettingsStoring
    private let inputSourceProvider: InputSourceProviding
    private let permissionProvider: PermissionStatusProviding
    private let engineBridge: any EngineBridging

    public init(
        settingsStore: SettingsStoring,
        inputSourceProvider: InputSourceProviding,
        permissionProvider: PermissionStatusProviding,
        engineBridge: any EngineBridging = RustEngineBridge()
    ) {
        self.settingsStore = settingsStore
        self.inputSourceProvider = inputSourceProvider
        self.permissionProvider = permissionProvider
        self.engineBridge = engineBridge
        self.availableInputSources = []
        self.permissionSnapshot = PermissionSnapshot(accessibility: .unknown, inputMonitoring: .unknown)
        self.configurationIssues = []
        self.currentEngineState = .idlePrimary
        self.lastInputBehavior = nil
        self.lastEngineAction = nil
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

    public func sendTestEvent(_ event: InputBehavior) throws {
        let previousState = currentEngineState
        let result = try engineBridge.transition(from: previousState, event: event)

        lastInputBehavior = event
        currentEngineState = result.state
        lastEngineAction = result.action

        logEntries.append(
            "Engine event=\(event.rawValue) previousState=\(previousState.rawValue) newState=\(result.state.rawValue) action=\(result.action.rawValue) diagnostic=\(result.diagnostic.message)"
        )
    }

    public func dispatchTestEvent(_ event: InputBehavior) {
        do {
            try sendTestEvent(event)
        } catch {
            logEntries.append("Engine event=\(event.rawValue) failed error=\(String(describing: error))")
        }
    }
}

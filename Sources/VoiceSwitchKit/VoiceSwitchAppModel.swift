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
    public private(set) var eventTapStatus: KeyboardListenerState
    public private(set) var lastRawKeyboardEventSummary: String?
    public private(set) var lastProgrammaticSwitchTargetInputSourceID: String?
    public private(set) var lastProgrammaticSwitchAt: Date?
    public private(set) var isCooldownActive: Bool
    public private(set) var cooldownDeadline: Date?
    public var selectedPrimaryInputSourceID: String?
    public var selectedVoiceInputSourceID: String?
    public var launchAtLoginEnabled: Bool
    public var logEntries: [String]

    private let settingsStore: SettingsStoring
    private let inputSourceProvider: InputSourceProviding
    private let inputSourceSwitchingService: InputSourceSwitching
    private let inputSourceObservationService: InputSourceObserving?
    private let permissionProvider: PermissionStatusProviding
    private let engineBridge: any EngineBridging
    private let keyboardEventService: KeyboardEventListening?
    private let cooldownScheduler: CooldownScheduling
    private let nowProvider: @Sendable () -> Date
    private let cooldownDuration: TimeInterval

    public init(
        settingsStore: SettingsStoring,
        inputSourceProvider: InputSourceProviding,
        inputSourceSwitchingService: InputSourceSwitching = InputSourceSwitchingService(),
        inputSourceObservationService: InputSourceObserving? = nil,
        permissionProvider: PermissionStatusProviding,
        engineBridge: any EngineBridging = RustEngineBridge(),
        keyboardEventService: KeyboardEventListening? = nil,
        cooldownScheduler: CooldownScheduling = CooldownScheduler(),
        nowProvider: @escaping @Sendable () -> Date = Date.init,
        cooldownDuration: TimeInterval = 5
    ) {
        self.settingsStore = settingsStore
        self.inputSourceProvider = inputSourceProvider
        self.inputSourceSwitchingService = inputSourceSwitchingService
        self.inputSourceObservationService = inputSourceObservationService
        self.permissionProvider = permissionProvider
        self.engineBridge = engineBridge
        self.keyboardEventService = keyboardEventService
        self.cooldownScheduler = cooldownScheduler
        self.nowProvider = nowProvider
        self.cooldownDuration = cooldownDuration
        self.availableInputSources = []
        self.permissionSnapshot = PermissionSnapshot(accessibility: .unknown, inputMonitoring: .unknown)
        self.configurationIssues = []
        self.currentEngineState = .idlePrimary
        self.lastInputBehavior = nil
        self.lastEngineAction = nil
        self.eventTapStatus = .stopped
        self.lastRawKeyboardEventSummary = nil
        self.lastProgrammaticSwitchTargetInputSourceID = nil
        self.lastProgrammaticSwitchAt = nil
        self.isCooldownActive = false
        self.cooldownDeadline = nil
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
        keyboardEventService?.start { [weak self] summary in
            if Thread.isMainThread {
                MainActor.assumeIsolated { [weak self] in
                    self?.handleKeyboardEvent(summary)
                }
            } else {
                Task { @MainActor [weak self] in
                    self?.handleKeyboardEvent(summary)
                }
            }
        }
        inputSourceObservationService?.start { [weak self] observation in
            if Thread.isMainThread {
                MainActor.assumeIsolated { [weak self] in
                    self?.handleInputSourceObservation(observation)
                }
            } else {
                Task { @MainActor [weak self] in
                    self?.handleInputSourceObservation(observation)
                }
            }
        }
        eventTapStatus = keyboardEventService?.isRunning == true ? .running : .stopped
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
        try advanceEngine(for: event, rawDescription: nil)
    }

    public func dispatchTestEvent(_ event: InputBehavior) {
        do {
            try sendTestEvent(event)
        } catch {
            logEntries.append("Engine event=\(event.rawValue) failed error=\(String(describing: error))")
        }
    }

    public func handleKeyboardEvent(_ summary: KeyboardEventSummary) {
        lastRawKeyboardEventSummary = summary.rawDescription
        switch summary {
        case .listenerInactive, .tapDisabled:
            eventTapStatus = .stopped
        case .tapRecoveryAttempted, .optionPressed, .optionReleased, .typingKey:
            eventTapStatus = .running
        }

        logEntries.append("Keyboard raw=\(summary.rawDescription)")

        guard let mappedBehavior = summary.mappedBehavior else {
            return
        }

        do {
            try advanceEngine(for: mappedBehavior, rawDescription: summary.rawDescription)
        } catch {
            logEntries.append(
                "Keyboard raw=\(summary.rawDescription) event=\(mappedBehavior.rawValue) failed error=\(String(describing: error))"
            )
        }
    }

    public func handleInputSourceObservation(_ observation: InputSourceObservation) {
        let now = nowProvider()
        switch observation {
        case let .changed(inputSourceID, rawDescription):
            let origin = classifyInputSourceChange(
                observedInputSourceID: inputSourceID,
                at: now
            )

            logEntries.append(
                "Input source observed raw=\(rawDescription) currentInputSource=\(inputSourceID ?? "none") origin=\(origin)"
            )

            guard origin == "manual" else {
                return
            }

            do {
                try advanceEngine(for: .manualSwitchDetected, rawDescription: rawDescription)
            } catch {
                logEntries.append(
                    "Input source observed raw=\(rawDescription) event=manualSwitchDetected failed error=\(String(describing: error))"
                )
            }
        }
    }

    private func advanceEngine(for event: InputBehavior, rawDescription: String?) throws {
        let previousState = currentEngineState
        let result = try engineBridge.transition(from: previousState, event: event)

        lastInputBehavior = event
        currentEngineState = result.state
        lastEngineAction = result.action

        var message = "Engine event=\(event.rawValue) previousState=\(previousState.rawValue) newState=\(result.state.rawValue) action=\(result.action.rawValue) diagnostic=\(result.diagnostic.message)"
        if let rawDescription {
            message = "Keyboard raw=\(rawDescription) " + message
        }
        logEntries.append(message)

        if previousState == .cooldown, event != .cooldownExpired, result.action == .noOp {
            logEntries.append("Cooldown state=active cooldownSkipped event=\(event.rawValue)")
        }

        if event == .cooldownExpired {
            isCooldownActive = false
            cooldownDeadline = nil
            logEntries.append("Cooldown event=cooldownExpired state=ended")
        }

        executeEngineAction(result.action)
    }

    private func executeEngineAction(_ action: EngineAction) {
        switch action {
        case .switchToPrimary:
            executeInputSourceSwitch(
                action: action,
                targetInputSourceID: selectedPrimaryInputSourceID,
                configurationLabel: "primary"
            )
        case .switchToVoice:
            executeInputSourceSwitch(
                action: action,
                targetInputSourceID: selectedVoiceInputSourceID,
                configurationLabel: "voice"
            )
        case .enterCooldown:
            scheduleCooldown()
        case .noOp:
            break
        }
    }

    private func executeInputSourceSwitch(
        action: EngineAction,
        targetInputSourceID: String?,
        configurationLabel: String
    ) {
        guard let targetInputSourceID else {
            logEntries.append(
                "Input source action=\(action.rawValue) switchResult=skipped reason=\(configurationLabel) input source is not configured"
            )
            return
        }

        guard availableInputSources.contains(where: { $0.id == targetInputSourceID }) else {
            logEntries.append(
                "Input source action=\(action.rawValue) targetInputSource=\(targetInputSourceID) switchResult=skipped reason=target input source is unavailable"
            )
            return
        }

        let currentInputSourceID: String?
        do {
            currentInputSourceID = try inputSourceSwitchingService.currentSelectedInputSourceID()
        } catch {
            logEntries.append(
                "Input source action=\(action.rawValue) targetInputSource=\(targetInputSourceID) switchResult=failed reason=\(String(describing: error))"
            )
            return
        }

        if currentInputSourceID == targetInputSourceID {
            logEntries.append(
                "Input source action=\(action.rawValue) currentInputSource=\(currentInputSourceID ?? "none") targetInputSource=\(targetInputSourceID) switchResult=skipped reason=target already selected"
            )
            return
        }

        do {
            try inputSourceSwitchingService.switchToInputSource(id: targetInputSourceID)
            lastProgrammaticSwitchTargetInputSourceID = targetInputSourceID
            lastProgrammaticSwitchAt = nowProvider()
            logEntries.append(
                "Input source action=\(action.rawValue) currentInputSource=\(currentInputSourceID ?? "none") targetInputSource=\(targetInputSourceID) switchResult=success"
            )
        } catch {
            logEntries.append(
                "Input source action=\(action.rawValue) currentInputSource=\(currentInputSourceID ?? "none") targetInputSource=\(targetInputSourceID) switchResult=failed reason=\(error.localizedDescription)"
            )
        }
    }

    private func classifyInputSourceChange(observedInputSourceID: String?, at now: Date) -> String {
        guard
            let targetID = lastProgrammaticSwitchTargetInputSourceID,
            let switchedAt = lastProgrammaticSwitchAt,
            observedInputSourceID == targetID,
            now.timeIntervalSince(switchedAt) <= 1
        else {
            return "manual"
        }

        lastProgrammaticSwitchTargetInputSourceID = nil
        lastProgrammaticSwitchAt = nil
        return "programmatic"
    }

    private func scheduleCooldown() {
        let deadline = nowProvider().addingTimeInterval(cooldownDuration)
        let wasActive = isCooldownActive

        isCooldownActive = true
        cooldownDeadline = deadline
        cooldownScheduler.schedule(deadline: deadline) { [weak self] in
            guard let self else {
                return
            }

            if Thread.isMainThread {
                MainActor.assumeIsolated { [weak self] in
                    self?.handleCooldownTimerFired()
                }
            } else {
                Task { @MainActor [weak self] in
                    self?.handleCooldownTimerFired()
                }
            }
        }

        if wasActive {
            logEntries.append("Cooldown event=cooldownReset deadline=\(deadline.timeIntervalSince1970)")
        } else {
            logEntries.append("Cooldown event=cooldownStarted deadline=\(deadline.timeIntervalSince1970)")
        }
    }

    private func handleCooldownTimerFired() {
        do {
            try advanceEngine(for: .cooldownExpired, rawDescription: nil)
        } catch {
            logEntries.append("Cooldown event=cooldownExpired failed error=\(String(describing: error))")
        }
    }
}

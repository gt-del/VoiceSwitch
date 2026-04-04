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
    public private(set) var keyboardMonitoringErrorMessage: String?
    public private(set) var launchAtLoginErrorMessage: String?
    public var selectedPrimaryInputSourceID: String?
    public var selectedVoiceInputSourceID: String?
    public var launchAtLoginEnabled: Bool
    public var optionPendingWindow: TimeInterval
    public var cooldownDuration: TimeInterval
    public var voiceExitDelay: TimeInterval
    public var logEntries: [String]

    private let settingsStore: SettingsStoring
    private let inputSourceProvider: InputSourceProviding
    private let inputSourceSwitchingService: InputSourceSwitching
    private let inputSourceObservationService: InputSourceObserving?
    private let permissionProvider: PermissionStatusProviding
    private let launchAtLoginController: LaunchAtLoginControlling
    private let engineBridge: any EngineBridging
    private let keyboardEventService: KeyboardEventListening?
    private let optionPendingScheduler: CooldownScheduling
    private let voiceExitScheduler: CooldownScheduling
    private let cooldownScheduler: CooldownScheduling
    private let nowProvider: @Sendable () -> Date

    public init(
        settingsStore: SettingsStoring,
        inputSourceProvider: InputSourceProviding,
        inputSourceSwitchingService: InputSourceSwitching = InputSourceSwitchingService(),
        inputSourceObservationService: InputSourceObserving? = nil,
        permissionProvider: PermissionStatusProviding,
        launchAtLoginController: LaunchAtLoginControlling = NoopLaunchAtLoginController(),
        engineBridge: any EngineBridging = RustEngineBridge(),
        keyboardEventService: KeyboardEventListening? = nil,
        optionPendingScheduler: CooldownScheduling = CooldownScheduler(),
        voiceExitScheduler: CooldownScheduling = CooldownScheduler(),
        cooldownScheduler: CooldownScheduling = CooldownScheduler(),
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.settingsStore = settingsStore
        self.inputSourceProvider = inputSourceProvider
        self.inputSourceSwitchingService = inputSourceSwitchingService
        self.inputSourceObservationService = inputSourceObservationService
        self.permissionProvider = permissionProvider
        self.launchAtLoginController = launchAtLoginController
        self.engineBridge = engineBridge
        self.keyboardEventService = keyboardEventService
        self.optionPendingScheduler = optionPendingScheduler
        self.voiceExitScheduler = voiceExitScheduler
        self.cooldownScheduler = cooldownScheduler
        self.nowProvider = nowProvider
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
        self.keyboardMonitoringErrorMessage = nil
        self.launchAtLoginErrorMessage = nil
        self.selectedPrimaryInputSourceID = nil
        self.selectedVoiceInputSourceID = nil
        self.launchAtLoginEnabled = false
        self.optionPendingWindow = EngineConfiguration().optionPendingWindow
        self.cooldownDuration = EngineConfiguration().cooldownDuration
        self.voiceExitDelay = EngineConfiguration().voiceExitDelay
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

        let launchAtLoginStatus = launchAtLoginController.isEnabled()
        launchAtLoginEnabled = launchAtLoginStatus
        if settings.launchAtLoginEnabled != launchAtLoginStatus {
            logEntries.append(
                "trigger=launch_at_login reason=status_mismatch source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=noOp current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=none cooldown_status=\(cooldownStatusLabel) requested=\(settings.launchAtLoginEnabled) actual=\(launchAtLoginStatus)"
            )
        }
        optionPendingWindow = settings.optionPendingWindow
        cooldownDuration = settings.cooldownDuration
        voiceExitDelay = settings.voiceExitDelay
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
            launchAtLoginEnabled: launchAtLoginEnabled,
            optionPendingWindow: optionPendingWindow,
            cooldownDuration: cooldownDuration,
            voiceExitDelay: voiceExitDelay
        )
        settingsStore.save(settings)
        do {
            try launchAtLoginController.setEnabled(launchAtLoginEnabled)
            launchAtLoginErrorMessage = nil
            logEntries.append(
                "trigger=launch_at_login reason=updated source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=noOp current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=none cooldown_status=\(cooldownStatusLabel) enabled=\(launchAtLoginEnabled) result=success"
            )
        } catch {
            launchAtLoginErrorMessage = error.localizedDescription
            logEntries.append(
                "trigger=launch_at_login reason=\(error.localizedDescription) source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=noOp current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=none cooldown_status=\(cooldownStatusLabel) enabled=\(launchAtLoginEnabled) result=failed"
            )
        }
        logEntries.append("Saved settings at \(Date.now.formatted(date: .omitted, time: .standard))")
    }

    public func retryKeyboardMonitoring() {
        permissionSnapshot = permissionProvider.snapshot()
        guard permissionSnapshot.accessibility == .authorized else {
            keyboardMonitoringErrorMessage = "Accessibility permission denied"
            logEntries.append("listener=keyboard_monitoring retryResult=skipped reason=accessibility_denied")
            eventTapStatus = .stopped
            return
        }

        keyboardEventService?.stop()
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
        keyboardMonitoringErrorMessage = nil
        eventTapStatus = keyboardEventService?.isRunning == true ? .running : .stopped
        logEntries.append("listener=keyboard_monitoring retryResult=started state=\(eventTapStatus.rawValue)")
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
            keyboardMonitoringErrorMessage = summary.rawDescription
        case .tapRecoveryAttempted, .optionPressed, .optionReleased, .typingKey:
            eventTapStatus = .running
            if case .tapRecoveryAttempted = summary {
                keyboardMonitoringErrorMessage = nil
            }
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
        let result = try engineBridge.transition(
            from: previousState,
            event: event,
            configuration: engineConfiguration
        )

        lastInputBehavior = event
        currentEngineState = result.state
        lastEngineAction = result.action

        updateTimerScheduling(previousState: previousState, event: event, result: result)
        appendTransitionLog(
            diagnostic: result.diagnostic,
            action: result.action,
            timer: result.timer,
            rawDescription: rawDescription
        )

        if previousState == .cooldown, event != .cooldownExpired, result.action == .noOp {
            logEntries.append(
                "trigger=\(event.rawValue) reason=cooldown_skipped_automatic_switch source_state=\(previousState.rawValue) target_state=\(result.state.rawValue) action=\(result.action.rawValue) current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=\(targetInputSourceID(for: result.action) ?? "none") cooldown_status=\(cooldownStatusLabel)"
            )
        }

        if event == .cooldownExpired {
            isCooldownActive = false
            cooldownDeadline = nil
            logEntries.append(
                "trigger=cooldownExpired reason=cooldown_ended source_state=cooldown target_state=\(result.state.rawValue) action=noOp current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=none cooldown_status=\(cooldownStatusLabel)"
            )
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
            break
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
                "trigger=input_source_switch reason=\(configurationLabel)_input_source_not_configured source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=\(action.rawValue) current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=none cooldown_status=\(cooldownStatusLabel) switch_result=skipped"
            )
            return
        }

        guard availableInputSources.contains(where: { $0.id == targetInputSourceID }) else {
            logEntries.append(
                "trigger=input_source_switch reason=target_input_source_unavailable source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=\(action.rawValue) current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=\(targetInputSourceID) cooldown_status=\(cooldownStatusLabel) switch_result=skipped"
            )
            return
        }

        let currentInputSourceID: String?
        do {
            currentInputSourceID = try inputSourceSwitchingService.currentSelectedInputSourceID()
        } catch {
            logEntries.append(
                "trigger=input_source_switch reason=\(String(describing: error)) source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=\(action.rawValue) current_input_source=unknown target_input_source=\(targetInputSourceID) cooldown_status=\(cooldownStatusLabel) switch_result=failed"
            )
            return
        }

        if currentInputSourceID == targetInputSourceID {
            logEntries.append(
                "trigger=input_source_switch reason=target_already_selected source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=\(action.rawValue) current_input_source=\(currentInputSourceID ?? "none") target_input_source=\(targetInputSourceID) cooldown_status=\(cooldownStatusLabel) switch_result=skipped"
            )
            return
        }

        do {
            try inputSourceSwitchingService.switchToInputSource(id: targetInputSourceID)
            lastProgrammaticSwitchTargetInputSourceID = targetInputSourceID
            lastProgrammaticSwitchAt = nowProvider()
            logEntries.append(
                "trigger=input_source_switch reason=executed source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=\(action.rawValue) current_input_source=\(currentInputSourceID ?? "none") target_input_source=\(targetInputSourceID) cooldown_status=\(cooldownStatusLabel) switch_result=success"
            )
        } catch {
            logEntries.append(
                "trigger=input_source_switch reason=\(error.localizedDescription) source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=\(action.rawValue) current_input_source=\(currentInputSourceID ?? "none") target_input_source=\(targetInputSourceID) cooldown_status=\(cooldownStatusLabel) switch_result=failed"
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

    private func scheduleCooldown(delay: TimeInterval) {
        let deadline = nowProvider().addingTimeInterval(delay)
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
            logEntries.append("trigger=manualSwitchDetected reason=cooldown_reset source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=enterCooldown current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=none cooldown_status=\(cooldownStatusLabel) deadline=\(deadline.timeIntervalSince1970)")
        } else {
            logEntries.append("trigger=manualSwitchDetected reason=cooldown_started source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=enterCooldown current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=none cooldown_status=\(cooldownStatusLabel) deadline=\(deadline.timeIntervalSince1970)")
        }
    }

    private func handleCooldownTimerFired() {
        do {
            try advanceEngine(for: .cooldownExpired, rawDescription: nil)
        } catch {
            logEntries.append("trigger=cooldownExpired reason=timer_delivery_failed source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=noOp current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=none cooldown_status=\(cooldownStatusLabel) error=\(String(describing: error))")
        }
    }

    private var engineConfiguration: EngineConfiguration {
        EngineConfiguration(
            optionPendingWindow: optionPendingWindow,
            cooldownDuration: cooldownDuration,
            voiceExitDelay: voiceExitDelay
        )
    }

    private var cooldownStatusLabel: String {
        isCooldownActive ? "active" : "inactive"
    }

    private func updateTimerScheduling(
        previousState: EngineState,
        event: InputBehavior,
        result: EngineTransitionResult
    ) {
        if result.timer?.kind != .optionPendingWindow {
            optionPendingScheduler.cancel()
        }
        if result.timer?.kind != .voiceExitDelay {
            voiceExitScheduler.cancel()
        }
        if result.timer?.kind != .cooldown {
            cooldownScheduler.cancel()
        }

        guard let timer = result.timer else {
            return
        }

        switch timer.kind {
        case .optionPendingWindow:
            scheduleOptionPendingWindow(delay: timer.delaySeconds)
        case .voiceExitDelay:
            scheduleVoiceExitDelay(delay: timer.delaySeconds)
        case .cooldown:
            scheduleCooldown(delay: timer.delaySeconds)
        }
    }

    private func scheduleOptionPendingWindow(delay: TimeInterval) {
        let deadline = nowProvider().addingTimeInterval(delay)
        optionPendingScheduler.schedule(deadline: deadline) { [weak self] in
            guard let self else {
                return
            }

            if Thread.isMainThread {
                MainActor.assumeIsolated { [weak self] in
                    self?.handleOptionPendingWindowExpired()
                }
            } else {
                Task { @MainActor [weak self] in
                    self?.handleOptionPendingWindowExpired()
                }
            }
        }

        logEntries.append("trigger=optionPressed reason=option_window_started source_state=idlePrimary target_state=optionPending action=noOp current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=\(selectedVoiceInputSourceID ?? "none") cooldown_status=\(cooldownStatusLabel) timer_delay_seconds=\(delay) deadline=\(deadline.timeIntervalSince1970)")
    }

    private func scheduleVoiceExitDelay(delay: TimeInterval) {
        let deadline = nowProvider().addingTimeInterval(delay)
        voiceExitScheduler.schedule(deadline: deadline) { [weak self] in
            guard let self else {
                return
            }

            if Thread.isMainThread {
                MainActor.assumeIsolated { [weak self] in
                    self?.handleVoiceExitDelayElapsed()
                }
            } else {
                Task { @MainActor [weak self] in
                    self?.handleVoiceExitDelayElapsed()
                }
            }
        }

        logEntries.append("trigger=optionReleased reason=voice_exit_delay_started source_state=voiceActive target_state=voiceActive action=noOp current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=\(selectedPrimaryInputSourceID ?? "none") cooldown_status=\(cooldownStatusLabel) timer_delay_seconds=\(delay) deadline=\(deadline.timeIntervalSince1970)")
    }

    private func handleOptionPendingWindowExpired() {
        do {
            try advanceEngine(for: .optionWindowExpired, rawDescription: nil)
        } catch {
            logEntries.append("trigger=optionWindowExpired reason=timer_delivery_failed source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=noOp current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=\(selectedVoiceInputSourceID ?? "none") cooldown_status=\(cooldownStatusLabel) error=\(String(describing: error))")
        }
    }

    private func handleVoiceExitDelayElapsed() {
        do {
            try advanceEngine(for: .voiceExitDelayElapsed, rawDescription: nil)
        } catch {
            logEntries.append("trigger=voiceExitDelayElapsed reason=timer_delivery_failed source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=noOp current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=\(selectedPrimaryInputSourceID ?? "none") cooldown_status=\(cooldownStatusLabel) error=\(String(describing: error))")
        }
    }

    private func appendTransitionLog(
        diagnostic: DiagnosticEntry,
        action: EngineAction,
        timer: EngineTimer?,
        rawDescription: String?
    ) {
        var entry = "trigger=\(diagnostic.trigger) reason=\(diagnostic.reason) source_state=\(diagnostic.sourceState.rawValue) target_state=\(diagnostic.targetState.rawValue) action=\(action.rawValue) current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=\(targetInputSourceID(for: action) ?? "none") cooldown_status=\(cooldownStatusLabel)"
        if let timer {
            entry += " timer_kind=\(timer.kind.rawValue) timer_delay_seconds=\(timer.delaySeconds)"
        }
        if let rawDescription {
            entry += " raw_event=\(rawDescription)"
        }
        logEntries.append(entry)
    }

    private func targetInputSourceID(for action: EngineAction) -> String? {
        switch action {
        case .switchToPrimary:
            return selectedPrimaryInputSourceID
        case .switchToVoice:
            return selectedVoiceInputSourceID
        case .enterCooldown, .noOp:
            return nil
        }
    }

    private func currentInputSourceIDForLog() -> String? {
        try? inputSourceSwitchingService.currentSelectedInputSourceID()
    }
}

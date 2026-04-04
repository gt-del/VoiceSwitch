import Foundation
import Observation

@MainActor
@Observable
public final class VoiceSwitchAppModel {
    public private(set) var availableInputSources: [InputSourceDescriptor]
    public private(set) var permissionSnapshot: PermissionSnapshot
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
    public var isEnabled: Bool
    public var launchAtLoginEnabled: Bool
    public var voiceActivationDelay: TimeInterval
    public var releaseReturnDelay: TimeInterval
    public var cooldownDuration: TimeInterval
    public var logEntries: [String]

    public var configurationIssues: [String] {
        var issues: [String] = []

        if let unavailablePrimaryIssue {
            issues.append(unavailablePrimaryIssue)
        }
        if let unavailableVoiceIssue {
            issues.append(unavailableVoiceIssue)
        }
        if selectedPrimaryInputSourceID == nil {
            issues.append("Primary IME is not configured.")
        }
        if selectedVoiceInputSourceID == nil {
            issues.append("Voice IME is not configured.")
        }
        if
            let primaryID = selectedPrimaryInputSourceID,
            let voiceID = selectedVoiceInputSourceID,
            primaryID == voiceID
        {
            issues.append("Primary IME and Voice IME must be different.")
        }

        return issues
    }

    public var canRun: Bool {
        blockingIssue == nil
    }

    public var blockingIssue: String? {
        if permissionSnapshot.accessibility != .authorized {
            return "未授予辅助功能权限，VoiceSwitch 当前无法监听 Option 键。"
        }
        if selectedPrimaryInputSourceID == nil {
            return "Primary IME is not configured."
        }
        if selectedVoiceInputSourceID == nil {
            return "Voice IME is not configured."
        }
        if
            let primaryID = selectedPrimaryInputSourceID,
            let voiceID = selectedVoiceInputSourceID,
            primaryID == voiceID
        {
            return "Primary IME and Voice IME must be different."
        }
        if let unavailablePrimaryIssue {
            return unavailablePrimaryIssue
        }
        if let unavailableVoiceIssue {
            return unavailableVoiceIssue
        }
        if keyboardEventService != nil && isEnabled && eventTapStatus != .running {
            return "Keyboard monitoring is not running. Retry Monitoring to resume automation."
        }

        return nil
    }

    public var statusSummary: String {
        if !isEnabled {
            return "Disabled"
        }
        if !canRun {
            return "Unavailable"
        }

        switch currentEngineState {
        case .idlePrimary:
            return "Typing"
        case .voiceHeld:
            return "Voice Held"
        case .cooldown:
            return "Cooldown"
        }
    }

    public var configurationSummary: String {
        "Primary: \(displayName(forInputSourceID: selectedPrimaryInputSourceID)) | Voice: \(displayName(forInputSourceID: selectedVoiceInputSourceID))"
    }

    public var selectedPrimaryInputSourceName: String {
        displayName(forInputSourceID: selectedPrimaryInputSourceID)
    }

    public var selectedVoiceInputSourceName: String {
        displayName(forInputSourceID: selectedVoiceInputSourceID)
    }

    private let settingsStore: SettingsStoring
    private let inputSourceProvider: InputSourceProviding
    private let inputSourceSwitchingService: InputSourceSwitching
    private let inputSourceObservationService: InputSourceObserving?
    private let permissionProvider: PermissionStatusProviding
    private let launchAtLoginController: LaunchAtLoginControlling
    private let engineBridge: any EngineBridging
    private let keyboardEventService: KeyboardEventListening?
    private let voiceActivationScheduler: CooldownScheduling
    private let releaseReturnScheduler: CooldownScheduling
    private let cooldownScheduler: CooldownScheduling
    private let nowProvider: @Sendable () -> Date
    private var unavailablePrimaryIssue: String?
    private var unavailableVoiceIssue: String?

    public init(
        settingsStore: SettingsStoring,
        inputSourceProvider: InputSourceProviding,
        inputSourceSwitchingService: InputSourceSwitching = InputSourceSwitchingService(),
        inputSourceObservationService: InputSourceObserving? = nil,
        permissionProvider: PermissionStatusProviding,
        launchAtLoginController: LaunchAtLoginControlling = NoopLaunchAtLoginController(),
        engineBridge: any EngineBridging = RustEngineBridge(),
        keyboardEventService: KeyboardEventListening? = nil,
        voiceActivationScheduler: CooldownScheduling = CooldownScheduler(),
        releaseReturnScheduler: CooldownScheduling = CooldownScheduler(),
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
        self.voiceActivationScheduler = voiceActivationScheduler
        self.releaseReturnScheduler = releaseReturnScheduler
        self.cooldownScheduler = cooldownScheduler
        self.nowProvider = nowProvider
        self.availableInputSources = []
        self.permissionSnapshot = PermissionSnapshot(accessibility: .unknown, inputMonitoring: .unknown)
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
        self.isEnabled = true
        self.launchAtLoginEnabled = false
        self.voiceActivationDelay = EngineConfiguration().voiceActivationDelay
        self.releaseReturnDelay = EngineConfiguration().releaseReturnDelay
        self.cooldownDuration = EngineConfiguration().cooldownDuration
        self.logEntries = []
        self.unavailablePrimaryIssue = nil
        self.unavailableVoiceIssue = nil
    }

    public func load() throws {
        let settings = settingsStore.load()
        availableInputSources = try inputSourceProvider.selectableInputSources()
        permissionSnapshot = permissionProvider.snapshot()

        if settings.isEnabled && permissionSnapshot.accessibility != .authorized {
            permissionSnapshot = permissionProvider.requestAccessibilityAuthorization()
            if permissionSnapshot.accessibility != .authorized {
                keyboardMonitoringErrorMessage = "Accessibility permission denied. Approve VoiceSwitch in Privacy & Security > Accessibility, then retry."
                logEntries.append("listener=keyboard_monitoring authorization=requested result=denied")
            }
        } else {
            keyboardMonitoringErrorMessage = nil
        }

        let availableIDs = Set(availableInputSources.map(\.id))
        unavailablePrimaryIssue = nil
        unavailableVoiceIssue = nil

        if let primaryID = settings.primaryInputSourceID, !availableIDs.contains(primaryID) {
            selectedPrimaryInputSourceID = nil
            unavailablePrimaryIssue = "Primary IME is no longer available. Please choose another input source."
            logEntries.append("Primary IME configuration became unavailable: \(primaryID)")
        } else {
            selectedPrimaryInputSourceID = settings.primaryInputSourceID
        }

        if let voiceID = settings.voiceInputSourceID, !availableIDs.contains(voiceID) {
            selectedVoiceInputSourceID = nil
            unavailableVoiceIssue = "Voice IME is no longer available. Please choose another input source."
            logEntries.append("Voice IME configuration became unavailable: \(voiceID)")
        } else {
            selectedVoiceInputSourceID = settings.voiceInputSourceID
        }

        isEnabled = settings.isEnabled
        let launchAtLoginStatus = launchAtLoginController.isEnabled()
        launchAtLoginEnabled = launchAtLoginStatus
        if settings.launchAtLoginEnabled != launchAtLoginStatus {
            logEntries.append(
                "trigger=launch_at_login reason=status_mismatch source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=noOp current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=none cooldown_status=\(cooldownStatusLabel) requested=\(settings.launchAtLoginEnabled) actual=\(launchAtLoginStatus)"
            )
        }
        voiceActivationDelay = settings.voiceActivationDelay
        releaseReturnDelay = settings.releaseReturnDelay
        cooldownDuration = settings.cooldownDuration

        updateAutomationState()
    }

    public func saveSelections() {
        settingsStore.save(makeSettings())
        updateAutomationState()

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

    public func updatePrimaryInputSourceID(_ inputSourceID: String?) {
        selectedPrimaryInputSourceID = inputSourceID
        if inputSourceID != nil {
            unavailablePrimaryIssue = nil
        }
    }

    public func updateVoiceInputSourceID(_ inputSourceID: String?) {
        selectedVoiceInputSourceID = inputSourceID
        if inputSourceID != nil {
            unavailableVoiceIssue = nil
        }
    }

    public func setEnabled(_ enabled: Bool) {
        guard isEnabled != enabled else {
            return
        }

        isEnabled = enabled
        if !enabled {
            currentEngineState = .idlePrimary
            lastEngineAction = .noOp
            isCooldownActive = false
            cooldownDeadline = nil
            keyboardMonitoringErrorMessage = nil
            lastRawKeyboardEventSummary = nil
            voiceActivationScheduler.cancel()
            releaseReturnScheduler.cancel()
            cooldownScheduler.cancel()
        }

        settingsStore.save(makeSettings())
        updateAutomationState()
    }

    public func retryKeyboardMonitoring() {
        permissionSnapshot = permissionProvider.requestAccessibilityAuthorization()
        guard permissionSnapshot.accessibility == .authorized else {
            keyboardMonitoringErrorMessage = "Accessibility permission denied. Approve VoiceSwitch in Privacy & Security > Accessibility, then retry."
            logEntries.append("listener=keyboard_monitoring retryResult=skipped reason=accessibility_denied")
            eventTapStatus = .stopped
            return
        }

        updateAutomationState(forceRestart: true)
        if eventTapStatus == .running {
            keyboardMonitoringErrorMessage = nil
            logEntries.append("listener=keyboard_monitoring retryResult=started state=\(eventTapStatus.rawValue)")
        }
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
            keyboardMonitoringErrorMessage = nil
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
        guard isEnabled else {
            lastInputBehavior = event
            lastEngineAction = .noOp
            logEntries.append("trigger=\(event.rawValue) reason=automation_disabled source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=noOp current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=none cooldown_status=\(cooldownStatusLabel)")
            return
        }

        guard canRun else {
            lastInputBehavior = event
            lastEngineAction = .noOp
            logEntries.append("trigger=\(event.rawValue) reason=automation_unavailable source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=noOp current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=none cooldown_status=\(cooldownStatusLabel)")
            return
        }

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

        executeEngineAction(result.action, delayedBy: result.timer)
    }

    private func executeEngineAction(_ action: EngineAction, delayedBy timer: EngineTimer?) {
        if let timer, timer.kind != .cooldown, action != .enterCooldown, action != .noOp {
            scheduleDelayedEngineAction(action, timer: timer)
            return
        }

        performEngineAction(action)
    }

    private func performEngineAction(_ action: EngineAction) {
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
        case .enterCooldown, .noOp:
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
            voiceActivationDelay: voiceActivationDelay,
            releaseReturnDelay: releaseReturnDelay,
            cooldownDuration: cooldownDuration,
            typingKeyWhitelist: EngineConfiguration().typingKeyWhitelist
        )
    }

    private var cooldownStatusLabel: String {
        isCooldownActive ? "active" : "inactive"
    }

    private var shouldRunAutomation: Bool {
        isEnabled && permissionSnapshot.accessibility == .authorized && configurationIssues.isEmpty
    }

    private func updateAutomationState(forceRestart: Bool = false) {
        if forceRestart {
            keyboardEventService?.stop()
            inputSourceObservationService?.stop()
        }

        guard shouldRunAutomation else {
            keyboardEventService?.stop()
            inputSourceObservationService?.stop()
            eventTapStatus = .stopped
            if !isEnabled {
                keyboardMonitoringErrorMessage = nil
                logAutomationStatusChange(reason: "disabled")
            } else {
                logAutomationStatusChange(reason: "stopped_due_to_blocking_issue")
            }
            return
        }

        startKeyboardMonitoring()
        startInputObservation()
        logAutomationStatusChange(reason: forceRestart ? "restarted" : "running")
    }

    private func startKeyboardMonitoring() {
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
        eventTapStatus = keyboardEventService?.isRunning == true ? .running : .stopped
    }

    private func startInputObservation() {
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
    }

    private func updateTimerScheduling(
        previousState: EngineState,
        event: InputBehavior,
        result: EngineTransitionResult
    ) {
        if result.timer?.kind != .voiceActivationDelay {
            voiceActivationScheduler.cancel()
        }
        if result.timer?.kind != .releaseReturnDelay {
            releaseReturnScheduler.cancel()
        }
        if result.timer?.kind != .cooldown && result.state != .cooldown {
            cooldownScheduler.cancel()
        }

        guard let timer = result.timer else {
            return
        }

        switch timer.kind {
        case .voiceActivationDelay:
            break
        case .releaseReturnDelay:
            break
        case .cooldown:
            scheduleCooldown(delay: timer.delaySeconds)
        }
    }

    private func scheduleDelayedEngineAction(_ action: EngineAction, timer: EngineTimer) {
        let deadline = nowProvider().addingTimeInterval(timer.delaySeconds)
        let scheduler = scheduler(for: timer.kind)

        scheduler.schedule(deadline: deadline) { [weak self] in
            guard let self else {
                return
            }

            if Thread.isMainThread {
                MainActor.assumeIsolated { [weak self] in
                    self?.performEngineAction(action)
                }
            } else {
                Task { @MainActor [weak self] in
                    self?.performEngineAction(action)
                }
            }
        }

        logEntries.append(
            "trigger=\(timerTrigger(for: timer.kind)) reason=\(timerReason(for: timer.kind)) source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=\(action.rawValue) current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=\(targetInputSourceID(for: action) ?? "none") cooldown_status=\(cooldownStatusLabel) timer_delay_seconds=\(timer.delaySeconds) deadline=\(deadline.timeIntervalSince1970)"
        )
    }

    private func scheduler(for timerKind: EngineTimerKind) -> CooldownScheduling {
        switch timerKind {
        case .voiceActivationDelay:
            return voiceActivationScheduler
        case .releaseReturnDelay:
            return releaseReturnScheduler
        case .cooldown:
            return cooldownScheduler
        }
    }

    private func timerTrigger(for timerKind: EngineTimerKind) -> String {
        switch timerKind {
        case .voiceActivationDelay:
            return "optionPressed"
        case .releaseReturnDelay:
            return "optionReleased"
        case .cooldown:
            return "manualSwitchDetected"
        }
    }

    private func timerReason(for timerKind: EngineTimerKind) -> String {
        switch timerKind {
        case .voiceActivationDelay:
            return "voice_activation_delay_started"
        case .releaseReturnDelay:
            return "release_return_delay_started"
        case .cooldown:
            return "cooldown_started"
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

    private func makeSettings() -> VoiceSwitchSettings {
        VoiceSwitchSettings(
            primaryInputSourceID: selectedPrimaryInputSourceID,
            voiceInputSourceID: selectedVoiceInputSourceID,
            isEnabled: isEnabled,
            launchAtLoginEnabled: launchAtLoginEnabled,
            voiceActivationDelay: voiceActivationDelay,
            releaseReturnDelay: releaseReturnDelay,
            cooldownDuration: cooldownDuration
        )
    }

    private func displayName(forInputSourceID inputSourceID: String?) -> String {
        guard let inputSourceID else {
            return "Not Set"
        }
        return availableInputSources.first(where: { $0.id == inputSourceID })?.displayName ?? inputSourceID
    }

    private func logAutomationStatusChange(reason: String) {
        logEntries.append(
            "trigger=automation_state reason=\(reason) source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=noOp current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=none cooldown_status=\(cooldownStatusLabel) enabled=\(isEnabled) can_run=\(canRun) event_tap=\(eventTapStatus.rawValue)"
        )
    }
}

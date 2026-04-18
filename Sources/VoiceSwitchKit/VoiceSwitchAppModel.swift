import Foundation
import Observation

@MainActor
@Observable
public final class VoiceSwitchAppModel {
    private enum RealInputSourceState {
        case idlePrimary
        case voiceMode

        var engineState: EngineState {
            switch self {
            case .idlePrimary:
                return .idlePrimary
            case .voiceMode:
                return .voiceMode
            }
        }

        var toggleAction: EngineAction {
            switch self {
            case .idlePrimary:
                return .switchToVoice
            case .voiceMode:
                return .switchToPrimary
            }
        }
    }

    private struct PendingProgrammaticInputSourceSwitch: Equatable {
        let action: EngineAction
        let targetInputSourceID: String
        let requestedAt: Date
    }

    private static let inputSourceConfirmationTimeout: TimeInterval = 0.2
    private static let voiceInputSourceSettleDelay: TimeInterval = 0.15

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
    public private(set) var settingsSaveStatusMessage: String?
    public private(set) var allLogEntries: [AppLogEntry]
    public var selectedPrimaryInputSourceID: String?
    public var selectedVoiceInputSourceID: String?
    public var isEnabled: Bool
    public var launchAtLoginEnabled: Bool
    public var switchToVoiceDelay: TimeInterval
    public var switchToPrimaryDelay: TimeInterval
    public var cooldownDuration: TimeInterval
    public var logEntries: [String] {
        allLogEntries.map(\.message)
    }
    public var blockingReason: AppBlockingReason? {
        if let permissionBlockingReason {
            return permissionBlockingReason
        }
        if let configurationBlockingReason {
            return configurationBlockingReason
        }
        if keyboardEventService != nil && isEnabled && eventTapStatus != .running {
            return AppBlockingReason(
                kind: .keyboardMonitoringStopped,
                title: "监听未运行",
                message: "权限和输入法配置都正常，但键盘监听当前没有运行。",
                nextStep: "请返回应用窗口等待自动恢复；若仍未恢复，再点击“重试监听”。"
            )
        }

        return nil
    }
    public var runtimeIdentityStatus: RuntimeIdentityStatus {
        if permissionSnapshot.accessibility == .authorized && permissionSnapshot.inputMonitoring == .authorized {
            return .matched
        }
        if permissionSnapshot.runtimeIdentityLikelyMismatch {
            return .mismatched
        }
        return .unknown
    }
    public var runtimeIdentityStatusLabel: String {
        switch runtimeIdentityStatus {
        case .matched:
            return "匹配"
        case .mismatched:
            return "疑似不匹配"
        case .unknown:
            return "未知"
        }
    }
    public var primaryInputSourceIssue: String? {
        if let unavailablePrimaryIssue {
            return unavailablePrimaryIssue
        }
        guard selectedPrimaryInputSourceID != nil else {
            return "请选择普通输入法。"
        }
        if
            let primaryID = selectedPrimaryInputSourceID,
            let voiceID = selectedVoiceInputSourceID,
            primaryID == voiceID
        {
            return "普通输入法和语音输入法不能相同。"
        }
        return nil
    }
    public var voiceInputSourceIssue: String? {
        if let unavailableVoiceIssue {
            return unavailableVoiceIssue
        }
        guard selectedVoiceInputSourceID != nil else {
            return "请选择语音输入法。"
        }
        if
            let primaryID = selectedPrimaryInputSourceID,
            let voiceID = selectedVoiceInputSourceID,
            primaryID == voiceID
        {
            return "普通输入法和语音输入法不能相同。"
        }
        return nil
    }
    public var configurationIssues: [String] {
        [primaryInputSourceIssue, voiceInputSourceIssue]
            .compactMap { $0 }
            .removingDuplicates()
    }

    public var canRun: Bool {
        blockingReason == nil
    }
    public var shouldHighlightRetryMonitoring: Bool {
        isEnabled && blockingReason != nil
    }
    public var menuBlockingLabel: String? {
        guard isEnabled, let blockingReason else {
            return nil
        }

        switch blockingReason.kind {
        case .accessibilityDenied, .runtimeIdentityMismatch:
            return "权限缺失"
        case .inputMonitoringDenied:
            return "输入监听缺失"
        case .keyboardMonitoringStopped:
            return "监听未运行"
        case .primaryInputSourceMissing, .voiceInputSourceMissing:
            return "输入法未配置"
        case .primaryInputSourceUnavailable, .voiceInputSourceUnavailable:
            return "输入法失效"
        case .duplicateInputSources:
            return "输入法冲突"
        }
    }

    public var statusSummary: String {
        if !isEnabled {
            return "已停用"
        }
        if !canRun {
            return "不可用"
        }

        switch currentEngineState {
        case .idlePrimary:
            return "普通输入法"
        case .voiceMode:
            return "语音输入法"
        case .cooldown:
            return "冷却中"
        }
    }

    public var selectedPrimaryInputSourceName: String {
        displayName(forInputSourceID: selectedPrimaryInputSourceID)
    }

    public var selectedVoiceInputSourceName: String {
        displayName(forInputSourceID: selectedVoiceInputSourceID)
    }

    public var accessibilityStatusLabel: String {
        displayLabel(for: permissionSnapshot.accessibility)
    }

    public var accessibilityTrustedValueLabel: String {
        permissionSnapshot.accessibilityTrusted ? "true" : "false"
    }

    public var inputMonitoringStatusLabel: String {
        displayLabel(for: permissionSnapshot.inputMonitoring)
    }

    public var inputMonitoringTrustedValueLabel: String {
        permissionSnapshot.inputMonitoringTrusted ? "true" : "false"
    }

    public var keyboardListenerStatusLabel: String {
        switch eventTapStatus {
        case .running:
            return "运行中"
        case .stopped:
            return "未运行"
        }
    }
    public var runtimeExecutablePath: String {
        permissionSnapshot.executablePath
    }
    public var maskedRuntimeExecutablePath: String {
        maskPath(permissionSnapshot.executablePath)
    }

    public var runtimeBundleIdentifier: String {
        permissionSnapshot.bundleIdentifier ?? "无"
    }

    public var runtimeBundlePath: String {
        permissionSnapshot.bundlePath ?? "无"
    }
    public var maskedRuntimeBundlePath: String {
        maskPath(permissionSnapshot.bundlePath)
    }
    public func filteredLogEntries(_ filter: AppLogFilter) -> [AppLogEntry] {
        switch filter {
        case .all:
            return allLogEntries
        case .user:
            return allLogEntries.filter { $0.level == .user }
        case .diagnostic:
            return allLogEntries.filter { $0.level == .diagnostic }
        }
    }
    public func exportLogs(to url: URL) throws {
        try makeLogExportReport().write(to: url, atomically: true, encoding: .utf8)
    }

    func refreshAutomationStateForTesting(forceRestart: Bool = false) {
        updateAutomationState(forceRestart: forceRestart)
    }

    func appendLogForTesting(level: AppLogLevel, message: String) {
        appendLog(level, message)
    }

    private let settingsStore: SettingsStoring
    private let inputSourceProvider: InputSourceProviding
    private let inputSourceSwitchingService: InputSourceSwitching
    private let inputSourceObservationService: InputSourceObserving?
    private let permissionProvider: PermissionStatusProviding
    private let launchAtLoginController: LaunchAtLoginControlling
    private let engineBridge: any EngineBridging
    private let keyboardEventService: KeyboardEventListening?
    private let switchToVoiceScheduler: CooldownScheduling
    private let switchToPrimaryScheduler: CooldownScheduling
    private let cooldownScheduler: CooldownScheduling
    private let inputSourceConfirmationScheduler: CooldownScheduling
    private let voiceInputSourceSettleScheduler: CooldownScheduling
    private let nowProvider: @Sendable () -> Date
    private var pendingSettingsSaveTask: Task<Void, Never>?
    private var lastLoggedAutomationState: String?
    private var isInputObservationActive: Bool
    private var unavailablePrimaryIssue: String?
    private var unavailableVoiceIssue: String?
    private var pendingProgrammaticInputSourceSwitch: PendingProgrammaticInputSourceSwitch?
    private var pendingVoiceInputSourceSettleTargetInputSourceID: String?

    public init(
        settingsStore: SettingsStoring,
        inputSourceProvider: InputSourceProviding,
        inputSourceSwitchingService: InputSourceSwitching = InputSourceSwitchingService(),
        inputSourceObservationService: InputSourceObserving? = nil,
        permissionProvider: PermissionStatusProviding,
        launchAtLoginController: LaunchAtLoginControlling = NoopLaunchAtLoginController(),
        engineBridge: any EngineBridging = RustEngineBridge(),
        keyboardEventService: KeyboardEventListening? = nil,
        switchToVoiceScheduler: CooldownScheduling = CooldownScheduler(),
        switchToPrimaryScheduler: CooldownScheduling = CooldownScheduler(),
        cooldownScheduler: CooldownScheduling = CooldownScheduler(),
        inputSourceConfirmationScheduler: CooldownScheduling = CooldownScheduler(),
        voiceInputSourceSettleScheduler: CooldownScheduling = CooldownScheduler(),
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
        self.switchToVoiceScheduler = switchToVoiceScheduler
        self.switchToPrimaryScheduler = switchToPrimaryScheduler
        self.cooldownScheduler = cooldownScheduler
        self.inputSourceConfirmationScheduler = inputSourceConfirmationScheduler
        self.voiceInputSourceSettleScheduler = voiceInputSourceSettleScheduler
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
        self.allLogEntries = []
        self.selectedPrimaryInputSourceID = nil
        self.selectedVoiceInputSourceID = nil
        self.isEnabled = true
        self.launchAtLoginEnabled = false
        self.switchToVoiceDelay = EngineConfiguration().switchToVoiceDelay
        self.switchToPrimaryDelay = EngineConfiguration().switchToPrimaryDelay
        self.cooldownDuration = EngineConfiguration().cooldownDuration
        self.isInputObservationActive = false
        self.unavailablePrimaryIssue = nil
        self.unavailableVoiceIssue = nil
        self.pendingProgrammaticInputSourceSwitch = nil
        self.pendingVoiceInputSourceSettleTargetInputSourceID = nil
    }

    public func load() throws {
        let settings = settingsStore.load()
        availableInputSources = try inputSourceProvider.selectableInputSources()
        permissionSnapshot = permissionProvider.snapshot()

        if settings.isEnabled && permissionSnapshot.accessibility != .authorized {
            permissionSnapshot = permissionProvider.requestAccessibilityAuthorization()
            if permissionSnapshot.accessibility != .authorized {
                keyboardMonitoringErrorMessage = permissionBlockingReason?.message
                appendLog(.user, "辅助功能权限未就绪，VoiceSwitch 当前无法监听 Fn 双击。")
                appendLog(.diagnostic, "listener=keyboard_monitoring authorization=requested result=denied")
            }
        } else {
            keyboardMonitoringErrorMessage = nil
        }

        let availableIDs = Set(availableInputSources.map(\.id))
        unavailablePrimaryIssue = nil
        unavailableVoiceIssue = nil

        if let primaryID = settings.primaryInputSourceID, !availableIDs.contains(primaryID) {
            selectedPrimaryInputSourceID = nil
            unavailablePrimaryIssue = "普通输入法已失效，请重新选择可用输入法。"
            appendLog(.user, "普通输入法已失效，请重新选择。")
            appendLog(.diagnostic, "普通输入法配置已失效: \(primaryID)")
        } else {
            selectedPrimaryInputSourceID = settings.primaryInputSourceID
        }

        if let voiceID = settings.voiceInputSourceID, !availableIDs.contains(voiceID) {
            selectedVoiceInputSourceID = nil
            unavailableVoiceIssue = "语音输入法已失效，请重新选择可用输入法。"
            appendLog(.user, "语音输入法已失效，请重新选择。")
            appendLog(.diagnostic, "语音输入法配置已失效: \(voiceID)")
        } else {
            selectedVoiceInputSourceID = settings.voiceInputSourceID
        }

        isEnabled = settings.isEnabled
        let launchAtLoginStatus = launchAtLoginController.isEnabled()
        launchAtLoginEnabled = launchAtLoginStatus
        if settings.launchAtLoginEnabled != launchAtLoginStatus {
            appendLog(.diagnostic,
                "trigger=launch_at_login reason=status_mismatch source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=noOp current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=none cooldown_status=\(cooldownStatusLabel) requested=\(settings.launchAtLoginEnabled) actual=\(launchAtLoginStatus)"
            )
        }
        switchToVoiceDelay = settings.switchToVoiceDelay
        switchToPrimaryDelay = settings.switchToPrimaryDelay
        cooldownDuration = settings.cooldownDuration
        settingsSaveStatusMessage = nil

        updateAutomationState()
    }

    public func saveSelections() {
        persistSettings(immediate: true)
    }

    public func updatePrimaryInputSourceID(_ inputSourceID: String?) {
        selectedPrimaryInputSourceID = inputSourceID
        settingsSaveStatusMessage = nil
        if inputSourceID != nil {
            unavailablePrimaryIssue = nil
        }
        updateAutomationState()
        scheduleAutoSave()
    }

    public func updateVoiceInputSourceID(_ inputSourceID: String?) {
        selectedVoiceInputSourceID = inputSourceID
        settingsSaveStatusMessage = nil
        if inputSourceID != nil {
            unavailableVoiceIssue = nil
        }
        updateAutomationState()
        scheduleAutoSave()
    }

    public func setEnabled(_ enabled: Bool) {
        guard isEnabled != enabled else {
            return
        }

        isEnabled = enabled
        settingsSaveStatusMessage = nil
        if !enabled {
            currentEngineState = .idlePrimary
            lastEngineAction = .noOp
            isCooldownActive = false
            cooldownDeadline = nil
            keyboardMonitoringErrorMessage = nil
            lastRawKeyboardEventSummary = nil
            switchToVoiceScheduler.cancel()
            switchToPrimaryScheduler.cancel()
            cooldownScheduler.cancel()
            inputSourceConfirmationScheduler.cancel()
            voiceInputSourceSettleScheduler.cancel()
            pendingProgrammaticInputSourceSwitch = nil
            pendingVoiceInputSourceSettleTargetInputSourceID = nil
        }
        updateAutomationState()
        scheduleAutoSave()
        appendLog(.user, enabled ? "VoiceSwitch 已启用。" : "VoiceSwitch 已停用。")
    }

    public func markSettingsEdited() {
        settingsSaveStatusMessage = nil
    }

    public func updateLaunchAtLoginEnabled(_ enabled: Bool) {
        guard launchAtLoginEnabled != enabled else {
            return
        }
        launchAtLoginEnabled = enabled
        settingsSaveStatusMessage = nil
        scheduleAutoSave()
    }

    public func updateSwitchToVoiceDelay(_ delay: TimeInterval) {
        guard switchToVoiceDelay != delay else {
            return
        }
        switchToVoiceDelay = delay
        settingsSaveStatusMessage = nil
        scheduleAutoSave()
    }

    public func updateSwitchToPrimaryDelay(_ delay: TimeInterval) {
        guard switchToPrimaryDelay != delay else {
            return
        }
        switchToPrimaryDelay = delay
        settingsSaveStatusMessage = nil
        scheduleAutoSave()
    }

    public func updateCooldownDuration(_ duration: TimeInterval) {
        guard cooldownDuration != duration else {
            return
        }
        cooldownDuration = duration
        settingsSaveStatusMessage = nil
        scheduleAutoSave()
    }

    public func retryKeyboardMonitoring() {
        if shouldRunAutomation, eventTapStatus == .running {
            appendLog(.diagnostic, "listener=keyboard_monitoring retryResult=skipped reason=already_running")
            return
        }

        permissionSnapshot = permissionProvider.requestAccessibilityAuthorization()
        guard permissionSnapshot.accessibility == .authorized else {
            keyboardMonitoringErrorMessage = permissionBlockingReason?.message
            appendLog(.user, "辅助功能权限仍未恢复。")
            appendLog(.diagnostic, "listener=keyboard_monitoring retryResult=skipped reason=accessibility_denied")
            eventTapStatus = .stopped
            return
        }

        permissionSnapshot = permissionProvider.requestInputMonitoringAuthorization()
        guard permissionSnapshot.inputMonitoring == .authorized else {
            keyboardMonitoringErrorMessage = permissionBlockingReason?.message
            appendLog(.user, "输入监听权限仍未恢复。")
            appendLog(.diagnostic, "listener=keyboard_monitoring retryResult=skipped reason=input_monitoring_denied")
            eventTapStatus = .stopped
            return
        }

        updateAutomationState(forceRestart: true)
        if eventTapStatus == .running {
            keyboardMonitoringErrorMessage = nil
            appendLog(.diagnostic, "listener=keyboard_monitoring retryResult=started state=\(eventTapStatus.rawValue)")
        }
    }

    public func handleApplicationDidBecomeActive() {
        let previousShouldRun = shouldRunAutomation
        let previousEventTapStatus = eventTapStatus

        permissionSnapshot = permissionProvider.snapshot()

        if shouldRunAutomation {
            if !previousShouldRun || previousEventTapStatus != .running {
                updateAutomationState(forceRestart: true)
                keyboardMonitoringErrorMessage = nil
                appendLog(.user, "权限已恢复，VoiceSwitch 已自动恢复监听。")
                appendLog(.diagnostic, "trigger=app_activation reason=permissions_recovered source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=noOp current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=none cooldown_status=\(cooldownStatusLabel) event_tap=\(eventTapStatus.rawValue)")
            }
            return
        }

        updateAutomationState()
        if let blockingReason {
            keyboardMonitoringErrorMessage = blockingReason.message
        }
        appendLog(.diagnostic, "trigger=app_activation reason=permissions_still_blocked source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=noOp current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=none cooldown_status=\(cooldownStatusLabel) event_tap=\(eventTapStatus.rawValue)")
    }

    public func sendTestEvent(_ event: InputBehavior) throws {
        try advanceEngine(for: event, rawDescription: nil)
    }

    public func handleKeyboardEvent(_ summary: KeyboardEventSummary) {
        lastRawKeyboardEventSummary = summary.rawDescription
        switch summary {
        case .listenerInactive, .tapDisabled:
            eventTapStatus = .stopped
            keyboardMonitoringErrorMessage = summary.rawDescription
        case .tapRecoveryAttempted, .controlPressed, .controlReleased, .controlTapCompleted, .typingKey:
            eventTapStatus = .running
            keyboardMonitoringErrorMessage = nil
        }

        appendLog(.diagnostic, "Keyboard raw=\(summary.rawDescription)")

        guard let keyboardBehavior = keyboardBehaviorToAdvance(for: summary) else {
            return
        }

        do {
            try advanceEngine(for: keyboardBehavior, rawDescription: summary.rawDescription)
        } catch {
            appendLog(.diagnostic,
                "Keyboard raw=\(summary.rawDescription) event=\(keyboardBehavior.rawValue) failed error=\(String(describing: error))"
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

            appendLog(.diagnostic,
                "Input source observed raw=\(rawDescription) currentInputSource=\(inputSourceID ?? "none") origin=\(origin)"
            )

            if origin == "programmatic" {
                _ = confirmPendingProgrammaticInputSourceSwitchIfNeeded(
                    observedInputSourceID: inputSourceID,
                    reason: "confirmed_observation"
                )
                return
            }

            guard origin == "manual" else {
                return
            }

            do {
                try advanceEngine(for: .manualSwitchDetected, rawDescription: rawDescription)
            } catch {
                appendLog(.diagnostic,
                    "Input source observed raw=\(rawDescription) event=manualSwitchDetected failed error=\(String(describing: error))"
                )
            }
        }
    }

    private func advanceEngine(for event: InputBehavior, rawDescription: String?) throws {
        guard isEnabled else {
            lastInputBehavior = event
            lastEngineAction = .noOp
            appendLog(.diagnostic, "trigger=\(event.rawValue) reason=automation_disabled source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=noOp current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=none cooldown_status=\(cooldownStatusLabel)")
            return
        }

        guard canRun else {
            lastInputBehavior = event
            lastEngineAction = .noOp
            appendLog(.diagnostic, "trigger=\(event.rawValue) reason=automation_unavailable source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=noOp current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=none cooldown_status=\(cooldownStatusLabel)")
            return
        }

        if try handleExplicitControlToggleIfNeeded(for: event, rawDescription: rawDescription) {
            return
        }

        let previousState = currentEngineState
        let result = try engineBridge.transition(
            from: previousState,
            event: event,
            configuration: engineConfiguration
        )
        let resolvedTargetState = resolvedEngineState(
            after: result,
            for: event
        )
        let diagnostic = DiagnosticEntry(
            trigger: result.diagnostic.trigger,
            reason: result.diagnostic.reason,
            sourceState: result.diagnostic.sourceState,
            targetState: resolvedTargetState
        )

        lastInputBehavior = event
        currentEngineState = resolvedTargetState
        lastEngineAction = result.action

        updateTimerScheduling(previousState: previousState, event: event, result: result)
        appendTransitionLog(
            diagnostic: diagnostic,
            action: result.action,
            timer: result.timer,
            rawDescription: rawDescription
        )

        if previousState == .cooldown, event != .cooldownExpired, result.action == .noOp {
            appendLog(.diagnostic,
                "trigger=\(event.rawValue) reason=cooldown_skipped_automatic_switch source_state=\(previousState.rawValue) target_state=\(result.state.rawValue) action=\(result.action.rawValue) current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=\(targetInputSourceID(for: result.action) ?? "none") cooldown_status=\(cooldownStatusLabel)"
            )
        }

        if event == .cooldownExpired {
            isCooldownActive = false
            cooldownDeadline = nil
            appendLog(.user, "冷却已结束，自动切换恢复。")
            appendLog(.diagnostic,
                "trigger=cooldownExpired reason=cooldown_ended source_state=cooldown target_state=\(resolvedTargetState.rawValue) action=noOp current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=none cooldown_status=\(cooldownStatusLabel)"
            )
        }

        executeEngineAction(result.action, delayedBy: result.timer)
    }

    private func keyboardBehaviorToAdvance(for summary: KeyboardEventSummary) -> InputBehavior? {
        switch summary {
        case .controlPressed:
            return nil
        case .controlReleased:
            return nil
        case .controlTapCompleted:
            return summary.mappedBehavior
        default:
            return summary.mappedBehavior
        }
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

    private func handleExplicitControlToggleIfNeeded(
        for event: InputBehavior,
        rawDescription: String?
    ) throws -> Bool {
        guard event == .controlPressed else {
            return false
        }

        let realInputSourceState: RealInputSourceState?
        do {
            realInputSourceState = try currentRealInputSourceState()
        } catch {
            appendLog(.diagnostic,
                "trigger=controlPressed reason=current_input_source_read_failed_fallback_to_engine source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=noOp current_input_source=unknown target_input_source=none cooldown_status=\(cooldownStatusLabel) error=\(String(describing: error))"
            )
            return false
        }

        guard let realInputSourceState else {
            return false
        }

        if currentEngineState == .cooldown {
            switchToVoiceScheduler.cancel()
            switchToPrimaryScheduler.cancel()

            let action = realInputSourceState.toggleAction
            lastInputBehavior = event
            lastEngineAction = action

            var entry = "trigger=controlPressed reason=explicit_toggle_using_current_input_source source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=\(action.rawValue) current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=\(targetInputSourceID(for: action) ?? "none") cooldown_status=\(cooldownStatusLabel)"
            if let rawDescription {
                entry += " raw_event=\(rawDescription)"
            }
            appendLog(.diagnostic, entry)

            executeEngineAction(action, delayedBy: timerForExplicitToggle(action))
            return true
        }

        let realEngineState = realInputSourceState.engineState
        guard realEngineState != currentEngineState else {
            return false
        }

        let previousState = currentEngineState
        currentEngineState = realEngineState
        appendLog(.diagnostic,
            "trigger=controlPressed reason=aligned_with_current_input_source source_state=\(previousState.rawValue) target_state=\(realEngineState.rawValue) action=noOp current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=none cooldown_status=\(cooldownStatusLabel)"
        )
        return false
    }

    private func executeInputSourceSwitch(
        action: EngineAction,
        targetInputSourceID: String?,
        configurationLabel: String
    ) {
        guard let targetInputSourceID else {
            appendLog(.diagnostic,
                "trigger=input_source_switch reason=\(configurationLabel)_input_source_not_configured source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=\(action.rawValue) current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=none cooldown_status=\(cooldownStatusLabel) switch_result=skipped"
            )
            return
        }

        guard availableInputSources.contains(where: { $0.id == targetInputSourceID }) else {
            appendLog(.user, "目标输入法当前不可用，请重新选择。")
            appendLog(.diagnostic,
                "trigger=input_source_switch reason=target_input_source_unavailable source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=\(action.rawValue) current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=\(targetInputSourceID) cooldown_status=\(cooldownStatusLabel) switch_result=skipped"
            )
            return
        }

        let currentInputSourceID: String?
        do {
            currentInputSourceID = try inputSourceSwitchingService.currentSelectedInputSourceID()
        } catch {
            appendLog(.user, "读取当前输入法失败，暂时无法自动切换。")
            appendLog(.diagnostic,
                "trigger=input_source_switch reason=\(String(describing: error)) source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=\(action.rawValue) current_input_source=unknown target_input_source=\(targetInputSourceID) cooldown_status=\(cooldownStatusLabel) switch_result=failed"
            )
            return
        }

        if currentInputSourceID == targetInputSourceID {
            appendLog(.diagnostic,
                "trigger=input_source_switch reason=target_already_selected source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=\(action.rawValue) current_input_source=\(currentInputSourceID ?? "none") target_input_source=\(targetInputSourceID) cooldown_status=\(cooldownStatusLabel) switch_result=skipped"
            )
            return
        }

        do {
            try inputSourceSwitchingService.switchToInputSource(id: targetInputSourceID)
            let requestedAt = nowProvider()
            lastProgrammaticSwitchTargetInputSourceID = targetInputSourceID
            lastProgrammaticSwitchAt = requestedAt
            pendingProgrammaticInputSourceSwitch = PendingProgrammaticInputSourceSwitch(
                action: action,
                targetInputSourceID: targetInputSourceID,
                requestedAt: requestedAt
            )
            pendingVoiceInputSourceSettleTargetInputSourceID = nil
            inputSourceConfirmationScheduler.cancel()
            voiceInputSourceSettleScheduler.cancel()

            appendLog(.diagnostic,
                "trigger=input_source_switch reason=request_sent source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=\(action.rawValue) current_input_source=\(currentInputSourceID ?? "none") target_input_source=\(targetInputSourceID) cooldown_status=\(cooldownStatusLabel) switch_result=requested"
            )

            do {
                let confirmedInputSourceID = try inputSourceSwitchingService.currentSelectedInputSourceID()
                if confirmPendingProgrammaticInputSourceSwitchIfNeeded(
                    observedInputSourceID: confirmedInputSourceID,
                    reason: "confirmed_immediate_read"
                ) {
                    return
                }
            } catch {
                appendLog(.diagnostic,
                    "trigger=input_source_switch reason=confirmation_read_failed source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=\(action.rawValue) current_input_source=unknown target_input_source=\(targetInputSourceID) cooldown_status=\(cooldownStatusLabel) error=\(String(describing: error))"
                )
            }

            scheduleInputSourceConfirmationTimeout()
        } catch {
            appendLog(.user, "输入法切换失败：\(error.localizedDescription)")
            appendLog(.diagnostic,
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

    private func confirmPendingProgrammaticInputSourceSwitchIfNeeded(
        observedInputSourceID: String?,
        reason: String
    ) -> Bool {
        guard
            let pendingProgrammaticInputSourceSwitch,
            observedInputSourceID == pendingProgrammaticInputSourceSwitch.targetInputSourceID
        else {
            return false
        }

        inputSourceConfirmationScheduler.cancel()
        self.pendingProgrammaticInputSourceSwitch = nil

        appendLog(.diagnostic,
            "trigger=input_source_switch reason=\(reason) source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=\(pendingProgrammaticInputSourceSwitch.action.rawValue) current_input_source=\(observedInputSourceID ?? "none") target_input_source=\(pendingProgrammaticInputSourceSwitch.targetInputSourceID) cooldown_status=\(cooldownStatusLabel) switch_result=confirmed"
        )

        if pendingProgrammaticInputSourceSwitch.action == .switchToVoice {
            scheduleVoiceInputSourceSettle(targetInputSourceID: pendingProgrammaticInputSourceSwitch.targetInputSourceID)
        } else {
            appendLog(.user, "已切回普通输入法。")
        }

        return true
    }

    private func scheduleInputSourceConfirmationTimeout() {
        guard let pendingProgrammaticInputSourceSwitch else {
            return
        }

        let deadline = pendingProgrammaticInputSourceSwitch.requestedAt.addingTimeInterval(Self.inputSourceConfirmationTimeout)
        inputSourceConfirmationScheduler.schedule(deadline: deadline) { [weak self] in
            guard let self else {
                return
            }

            if Thread.isMainThread {
                MainActor.assumeIsolated { [weak self] in
                    self?.handleInputSourceConfirmationTimeout(for: pendingProgrammaticInputSourceSwitch)
                }
            } else {
                Task { @MainActor [weak self] in
                    self?.handleInputSourceConfirmationTimeout(for: pendingProgrammaticInputSourceSwitch)
                }
            }
        }
    }

    private func handleInputSourceConfirmationTimeout(for expectedSwitch: PendingProgrammaticInputSourceSwitch) {
        guard pendingProgrammaticInputSourceSwitch == expectedSwitch else {
            return
        }

        pendingProgrammaticInputSourceSwitch = nil
        lastProgrammaticSwitchTargetInputSourceID = nil
        lastProgrammaticSwitchAt = nil
        appendLog(.diagnostic,
            "trigger=input_source_switch reason=confirmation_timeout source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=\(expectedSwitch.action.rawValue) current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=\(expectedSwitch.targetInputSourceID) cooldown_status=\(cooldownStatusLabel) switch_result=unconfirmed"
        )
    }

    private func scheduleVoiceInputSourceSettle(targetInputSourceID: String) {
        pendingVoiceInputSourceSettleTargetInputSourceID = targetInputSourceID
        voiceInputSourceSettleScheduler.cancel()
        let deadline = nowProvider().addingTimeInterval(Self.voiceInputSourceSettleDelay)
        voiceInputSourceSettleScheduler.schedule(deadline: deadline) { [weak self] in
            guard let self else {
                return
            }

            if Thread.isMainThread {
                MainActor.assumeIsolated { [weak self] in
                    self?.completeVoiceInputSourceSettle(targetInputSourceID: targetInputSourceID)
                }
            } else {
                Task { @MainActor [weak self] in
                    self?.completeVoiceInputSourceSettle(targetInputSourceID: targetInputSourceID)
                }
            }
        }
    }

    private func completeVoiceInputSourceSettle(targetInputSourceID: String) {
        guard pendingVoiceInputSourceSettleTargetInputSourceID == targetInputSourceID else {
            return
        }

        pendingVoiceInputSourceSettleTargetInputSourceID = nil
        appendLog(.user, "已切到语音输入法。")
        appendLog(.diagnostic,
            "trigger=input_source_switch reason=voice_input_source_settled source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=switchToVoice current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=\(targetInputSourceID) cooldown_status=\(cooldownStatusLabel) switch_result=settled"
        )
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
            appendLog(.user, "检测到手动切换输入法，冷却已重置。")
            appendLog(.diagnostic, "trigger=manualSwitchDetected reason=cooldown_reset source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=enterCooldown current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=none cooldown_status=\(cooldownStatusLabel) deadline=\(deadline.timeIntervalSince1970)")
        } else {
            appendLog(.user, "检测到手动切换输入法，已进入冷却。")
            appendLog(.diagnostic, "trigger=manualSwitchDetected reason=cooldown_started source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=enterCooldown current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=none cooldown_status=\(cooldownStatusLabel) deadline=\(deadline.timeIntervalSince1970)")
        }
    }

    private func handleCooldownTimerFired() {
        do {
            try advanceEngine(for: .cooldownExpired, rawDescription: nil)
        } catch {
            appendLog(.diagnostic, "trigger=cooldownExpired reason=timer_delivery_failed source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=noOp current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=none cooldown_status=\(cooldownStatusLabel) error=\(String(describing: error))")
        }
    }

    private func resolvedEngineState(
        after result: EngineTransitionResult,
        for event: InputBehavior
    ) -> EngineState {
        guard event == .cooldownExpired else {
            return result.state
        }

        let realInputSourceState: RealInputSourceState?
        do {
            realInputSourceState = try currentRealInputSourceState()
        } catch {
            appendLog(.diagnostic,
                "trigger=cooldownExpired reason=current_input_source_read_failed_fallback_to_engine source_state=\(result.diagnostic.sourceState.rawValue) target_state=\(result.state.rawValue) action=\(result.action.rawValue) current_input_source=unknown target_input_source=none cooldown_status=\(cooldownStatusLabel) error=\(String(describing: error))"
            )
            return result.state
        }

        guard let realInputSourceState else {
            return result.state
        }

        return realInputSourceState.engineState
    }

    private var engineConfiguration: EngineConfiguration {
        EngineConfiguration(
            switchToVoiceDelay: switchToVoiceDelay,
            switchToPrimaryDelay: switchToPrimaryDelay,
            cooldownDuration: cooldownDuration,
            typingKeyWhitelist: EngineConfiguration().typingKeyWhitelist
        )
    }

    private var cooldownStatusLabel: String {
        isCooldownActive ? "active" : "inactive"
    }

    private var shouldRunAutomation: Bool {
        isEnabled &&
        permissionSnapshot.accessibility == .authorized &&
        permissionSnapshot.inputMonitoring == .authorized &&
        configurationIssues.isEmpty
    }

    private func updateAutomationState(forceRestart: Bool = false) {
        guard shouldRunAutomation else {
            stopKeyboardMonitoringIfNeeded()
            stopInputObservationIfNeeded()
            eventTapStatus = .stopped
            if !isEnabled {
                keyboardMonitoringErrorMessage = nil
                logAutomationStatusChange(reason: "disabled")
            } else {
                keyboardMonitoringErrorMessage = blockingReason?.message
                logAutomationStatusChange(reason: "stopped_due_to_blocking_issue")
            }
            return
        }

        if forceRestart {
            stopKeyboardMonitoringIfNeeded()
            stopInputObservationIfNeeded()
        }

        startKeyboardMonitoring()
        startInputObservation()
        keyboardMonitoringErrorMessage = nil
        logAutomationStatusChange(reason: forceRestart ? "restarted" : "running")
    }

    private func startKeyboardMonitoring() {
        guard let keyboardEventService else {
            eventTapStatus = .running
            return
        }
        guard forceStartNeeded(for: keyboardEventService) else {
            eventTapStatus = .running
            return
        }
        keyboardEventService.start { [weak self] summary in
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
        eventTapStatus = keyboardEventService.isRunning ? .running : .stopped
    }

    private func startInputObservation() {
        guard let inputSourceObservationService else {
            isInputObservationActive = false
            return
        }
        guard !isInputObservationActive else {
            return
        }
        inputSourceObservationService.start { [weak self] observation in
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
        isInputObservationActive = true
    }

    private func forceStartNeeded(for service: KeyboardEventListening) -> Bool {
        forceStartNeeded(eventTapStatus: eventTapStatus, isRunning: service.isRunning)
    }

    private func forceStartNeeded(eventTapStatus: KeyboardListenerState, isRunning: Bool) -> Bool {
        eventTapStatus != .running || !isRunning
    }

    private func stopKeyboardMonitoringIfNeeded() {
        guard let keyboardEventService, keyboardEventService.isRunning || eventTapStatus == .running else {
            return
        }
        keyboardEventService.stop()
    }

    private func stopInputObservationIfNeeded() {
        guard isInputObservationActive else {
            return
        }
        inputSourceObservationService?.stop()
        isInputObservationActive = false
    }

    private func updateTimerScheduling(
        previousState: EngineState,
        event: InputBehavior,
        result: EngineTransitionResult
    ) {
        if result.timer?.kind != .switchToVoiceDelay {
            switchToVoiceScheduler.cancel()
        }
        if result.timer?.kind != .switchToPrimaryDelay {
            switchToPrimaryScheduler.cancel()
        }
        if result.timer?.kind != .cooldown && result.state != .cooldown {
            cooldownScheduler.cancel()
        }

        guard let timer = result.timer else {
            return
        }

        switch timer.kind {
        case .switchToVoiceDelay:
            break
        case .switchToPrimaryDelay:
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

        appendLog(.diagnostic,
            "trigger=\(timerTrigger(for: timer.kind)) reason=\(timerReason(for: timer.kind)) source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=\(action.rawValue) current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=\(targetInputSourceID(for: action) ?? "none") cooldown_status=\(cooldownStatusLabel) timer_delay_seconds=\(timer.delaySeconds) deadline=\(deadline.timeIntervalSince1970)"
        )
    }

    private func scheduler(for timerKind: EngineTimerKind) -> CooldownScheduling {
        switch timerKind {
        case .switchToVoiceDelay:
            return switchToVoiceScheduler
        case .switchToPrimaryDelay:
            return switchToPrimaryScheduler
        case .cooldown:
            return cooldownScheduler
        }
    }

    private func timerTrigger(for timerKind: EngineTimerKind) -> String {
        switch timerKind {
        case .switchToVoiceDelay:
            return "controlPressed"
        case .switchToPrimaryDelay:
            return "controlPressed"
        case .cooldown:
            return "manualSwitchDetected"
        }
    }

    private func timerReason(for timerKind: EngineTimerKind) -> String {
        switch timerKind {
        case .switchToVoiceDelay:
            return "switch_to_voice_delay_started"
        case .switchToPrimaryDelay:
            return "switch_to_primary_delay_started"
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
        appendLog(.diagnostic, entry)
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

    private func currentRealInputSourceState() throws -> RealInputSourceState? {
        guard let currentInputSourceID = try inputSourceSwitchingService.currentSelectedInputSourceID() else {
            return nil
        }
        if currentInputSourceID == selectedPrimaryInputSourceID {
            return .idlePrimary
        }
        if currentInputSourceID == selectedVoiceInputSourceID {
            return .voiceMode
        }
        return nil
    }

    private func timerForExplicitToggle(_ action: EngineAction) -> EngineTimer? {
        switch action {
        case .switchToPrimary where switchToPrimaryDelay > 0:
            return EngineTimer(kind: .switchToPrimaryDelay, delaySeconds: switchToPrimaryDelay)
        case .switchToVoice where switchToVoiceDelay > 0:
            return EngineTimer(kind: .switchToVoiceDelay, delaySeconds: switchToVoiceDelay)
        case .switchToPrimary, .switchToVoice, .enterCooldown, .noOp:
            return nil
        }
    }

    private func makeSettings() -> VoiceSwitchSettings {
        VoiceSwitchSettings(
            primaryInputSourceID: selectedPrimaryInputSourceID,
            voiceInputSourceID: selectedVoiceInputSourceID,
            isEnabled: isEnabled,
            launchAtLoginEnabled: launchAtLoginEnabled,
            switchToVoiceDelay: switchToVoiceDelay,
            switchToPrimaryDelay: switchToPrimaryDelay,
            cooldownDuration: cooldownDuration
        )
    }

    private func displayName(forInputSourceID inputSourceID: String?) -> String {
        guard let inputSourceID else {
            return "未设置"
        }
        return availableInputSources.first(where: { $0.id == inputSourceID })?.displayName ?? inputSourceID
    }

    private func displayLabel(for permissionState: PermissionState) -> String {
        switch permissionState {
        case .authorized:
            return "已授权"
        case .denied:
            return "未授权"
        case .unknown:
            return "未知"
        }
    }

    private var permissionBlockingReason: AppBlockingReason? {
        if permissionSnapshot.runtimeIdentityLikelyMismatch {
            return AppBlockingReason(
                kind: .runtimeIdentityMismatch,
                title: "授权对象不匹配",
                message: "系统里已授权的对象可能不是当前这个运行进程，当前进程未命中已授权条目，所以 VoiceSwitch 仍然拿不到权限。若你刚覆盖安装过本地构建，ad hoc 签名变化也会导致系统把它当成新的对象。",
                nextStep: "请只从 /Applications/VoiceSwitch.app 启动，并在系统设置里重新勾选当前运行路径对应的 VoiceSwitch。"
            )
        }

        if permissionSnapshot.accessibility != .authorized {
            return AppBlockingReason(
                kind: .accessibilityDenied,
                title: "辅助功能权限未授权",
                message: "系统尚未授予辅助功能权限，VoiceSwitch 当前无法监听 Fn 双击。",
                nextStep: "请打开系统设置里的“辅助功能”，勾选当前运行的 VoiceSwitch。"
            )
        }

        if permissionSnapshot.inputMonitoring != .authorized {
            return AppBlockingReason(
                kind: .inputMonitoringDenied,
                title: "输入监听权限未授权",
                message: "系统尚未授予输入监听权限，VoiceSwitch 当前无法读取全局键盘事件。",
                nextStep: "请打开系统设置里的“输入监听”，勾选当前运行的 VoiceSwitch。"
            )
        }

        return nil
    }

    private var configurationBlockingReason: AppBlockingReason? {
        if let unavailablePrimaryIssue {
            return AppBlockingReason(
                kind: .primaryInputSourceUnavailable,
                title: "普通输入法已失效",
                message: unavailablePrimaryIssue,
                nextStep: "请在设置里重新选择一个可用的普通输入法。"
            )
        }
        if let unavailableVoiceIssue {
            return AppBlockingReason(
                kind: .voiceInputSourceUnavailable,
                title: "语音输入法已失效",
                message: unavailableVoiceIssue,
                nextStep: "请在设置里重新选择一个可用的语音输入法。"
            )
        }
        if selectedPrimaryInputSourceID == nil {
            return AppBlockingReason(
                kind: .primaryInputSourceMissing,
                title: "普通输入法未配置",
                message: "未配置普通输入法。",
                nextStep: "请先在设置里选择一个普通输入法。"
            )
        }
        if selectedVoiceInputSourceID == nil {
            return AppBlockingReason(
                kind: .voiceInputSourceMissing,
                title: "语音输入法未配置",
                message: "未配置语音输入法。",
                nextStep: "请先在设置里选择一个语音输入法。"
            )
        }
        if
            let selectedPrimaryInputSourceID,
            let selectedVoiceInputSourceID,
            selectedPrimaryInputSourceID == selectedVoiceInputSourceID
        {
            return AppBlockingReason(
                kind: .duplicateInputSources,
                title: "输入法配置冲突",
                message: "普通输入法和语音输入法不能相同。",
                nextStep: "请把普通输入法和语音输入法改成两个不同的选项。"
            )
        }

        return nil
    }

    private func logAutomationStatusChange(reason: String) {
        let entry = "trigger=automation_state reason=\(reason) source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=noOp current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=none cooldown_status=\(cooldownStatusLabel) enabled=\(isEnabled) can_run=\(canRun) event_tap=\(eventTapStatus.rawValue)"
        guard lastLoggedAutomationState != entry else {
            return
        }
        lastLoggedAutomationState = entry
        appendLog(.diagnostic, entry)
    }

    private func appendLog(_ level: AppLogLevel, _ message: String) {
        allLogEntries.append(
            AppLogEntry(
                timestamp: nowProvider(),
                level: level,
                message: message
            )
        )
        trimLogBuffer(for: level)
    }

    private func scheduleAutoSave() {
        pendingSettingsSaveTask?.cancel()
        pendingSettingsSaveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else {
                return
            }
            guard let self else {
                return
            }
            await MainActor.run {
                self.persistSettings(immediate: false)
            }
        }
    }

    private func persistSettings(immediate: Bool) {
        pendingSettingsSaveTask?.cancel()
        pendingSettingsSaveTask = nil

        do {
            try settingsStore.save(
                makeSettings(),
                availableInputSourceIDs: availableInputSources.isEmpty
                    ? nil
                    : Set(availableInputSources.map(\.id))
            )
        } catch {
            settingsSaveStatusMessage = error.localizedDescription
            appendLog(.user, "设置保存失败：\(error.localizedDescription)")
            appendLog(.diagnostic, "trigger=settings_save reason=validation_failed source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=noOp current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=none cooldown_status=\(cooldownStatusLabel) error=\(error.localizedDescription)")
            return
        }
        applyLaunchAtLoginSetting()
        settingsSaveStatusMessage = immediate ? "配置已保存。" : "已自动保存。"
    }

    private func applyLaunchAtLoginSetting() {
        do {
            try launchAtLoginController.setEnabled(launchAtLoginEnabled)
            launchAtLoginErrorMessage = nil
            appendLog(
                .diagnostic,
                "trigger=launch_at_login reason=applied source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=noOp current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=none cooldown_status=\(cooldownStatusLabel) requested=\(launchAtLoginEnabled) result=success"
            )
        } catch {
            launchAtLoginErrorMessage = "登录启动更新失败：\(error.localizedDescription)"
            settingsSaveStatusMessage = "配置已保存，但登录启动更新失败。"
            appendLog(
                .diagnostic,
                "trigger=launch_at_login reason=apply_failed source_state=\(currentEngineState.rawValue) target_state=\(currentEngineState.rawValue) action=noOp current_input_source=\(currentInputSourceIDForLog() ?? "unknown") target_input_source=none cooldown_status=\(cooldownStatusLabel) requested=\(launchAtLoginEnabled) result=failed error=\(error.localizedDescription)"
            )
        }
    }

    private func trimLogBuffer(for level: AppLogLevel) {
        let limit = switch level {
        case .user:
            200
        case .diagnostic:
            1000
        }

        while allLogEntries.filter({ $0.level == level }).count > limit {
            guard let index = allLogEntries.firstIndex(where: { $0.level == level }) else {
                return
            }
            allLogEntries.remove(at: index)
        }
    }

    private func makeLogExportReport() -> String {
        let formatter = ISO8601DateFormatter()
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"

        let header = [
            "# VoiceSwitch Log Export",
            "generated_at=\(formatter.string(from: nowProvider()))",
            "version=\(version)",
            "build=\(build)",
            "status=\(statusSummary)",
            "permissions=辅助功能：\(accessibilityStatusLabel) | 输入监听：\(inputMonitoringStatusLabel)",
            "listener=\(keyboardListenerStatusLabel)",
            "runtime_executable_path=\(runtimeExecutablePath)",
            "bundle_identifier=\(runtimeBundleIdentifier)",
            "bundle_path=\(runtimeBundlePath)",
            ""
        ]

        let entries = allLogEntries.map {
            "[\($0.level.rawValue)] \(formatter.string(from: $0.timestamp)) \($0.message)"
        }

        return (header + entries).joined(separator: "\n")
    }

    private func maskPath(_ path: String?) -> String {
        guard let path, !path.isEmpty else {
            return "无"
        }

        var normalized = path
        let homeDirectory = NSHomeDirectory()
        if normalized.hasPrefix(homeDirectory) {
            normalized = "~" + normalized.dropFirst(homeDirectory.count)
        }

        let components = normalized.split(separator: "/")
        guard components.count > 4 else {
            return normalized
        }

        let prefix = components.prefix(2).joined(separator: "/")
        let suffix = components.suffix(2).joined(separator: "/")
        return "\(prefix)/.../\(suffix)"
    }
}

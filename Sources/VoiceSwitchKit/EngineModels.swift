import Foundation

public enum EngineState: String, Codable, CaseIterable, Sendable {
    case idlePrimary
    case optionPending
    case voiceActive
    case cooldown
}

public enum InputBehavior: String, Codable, CaseIterable, Sendable {
    case optionPressed
    case optionReleased
    case optionWindowExpired
    case typingDetected
    case typingKeyLetters
    case typingKeyNumbers
    case typingKeySpace
    case typingKeyDelete
    case typingKeyReturnKey
    case manualSwitchDetected
    case cooldownExpired
    case voiceExitDelayElapsed
}

public enum EngineAction: String, Codable, CaseIterable, Sendable {
    case switchToPrimary
    case switchToVoice
    case enterCooldown
    case noOp
}

public enum TypingKeyCategory: String, Codable, CaseIterable, Sendable {
    case letters
    case numbers
    case space
    case delete
    case returnKey
}

public struct EngineConfiguration: Codable, Equatable, Sendable {
    public var optionPendingWindow: TimeInterval
    public var cooldownDuration: TimeInterval
    public var voiceExitDelay: TimeInterval
    public var typingKeyWhitelist: [TypingKeyCategory]

    public init(
        optionPendingWindow: TimeInterval = 0.18,
        cooldownDuration: TimeInterval = 5,
        voiceExitDelay: TimeInterval = 10,
        typingKeyWhitelist: [TypingKeyCategory] = [.letters, .numbers, .space, .delete, .returnKey]
    ) {
        self.optionPendingWindow = optionPendingWindow
        self.cooldownDuration = cooldownDuration
        self.voiceExitDelay = voiceExitDelay
        self.typingKeyWhitelist = typingKeyWhitelist
    }
}

public struct DiagnosticEntry: Codable, Equatable, Sendable {
    public let trigger: String
    public let reason: String
    public let sourceState: EngineState
    public let targetState: EngineState

    public init(trigger: String, reason: String, sourceState: EngineState, targetState: EngineState) {
        self.trigger = trigger
        self.reason = reason
        self.sourceState = sourceState
        self.targetState = targetState
    }
}

public enum EngineTimerKind: String, Codable, Equatable, Sendable {
    case optionPendingWindow
    case voiceExitDelay
    case cooldown
}

public struct EngineTimer: Codable, Equatable, Sendable {
    public let kind: EngineTimerKind
    public let delaySeconds: TimeInterval

    public init(kind: EngineTimerKind, delaySeconds: TimeInterval) {
        self.kind = kind
        self.delaySeconds = delaySeconds
    }
}

public struct EngineTransitionResult: Codable, Equatable, Sendable {
    public let state: EngineState
    public let action: EngineAction
    public let diagnostic: DiagnosticEntry
    public let timer: EngineTimer?

    public init(
        state: EngineState,
        action: EngineAction,
        diagnostic: DiagnosticEntry,
        timer: EngineTimer? = nil
    ) {
        self.state = state
        self.action = action
        self.diagnostic = diagnostic
        self.timer = timer
    }
}

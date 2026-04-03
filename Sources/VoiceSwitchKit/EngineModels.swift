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
    case typingDetected
    case manualSwitchDetected
    case cooldownExpired
}

public enum EngineAction: String, Codable, CaseIterable, Sendable {
    case switchToPrimary
    case switchToVoice
    case enterCooldown
    case noOp
}

public struct DiagnosticEntry: Codable, Equatable, Sendable {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}

public struct EngineTransitionResult: Codable, Equatable, Sendable {
    public let state: EngineState
    public let action: EngineAction
    public let diagnostic: DiagnosticEntry

    public init(state: EngineState, action: EngineAction, diagnostic: DiagnosticEntry) {
        self.state = state
        self.action = action
        self.diagnostic = diagnostic
    }
}

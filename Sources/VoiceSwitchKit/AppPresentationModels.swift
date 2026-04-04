import Foundation

public enum AppBlockingReasonKind: String, Equatable, Sendable {
    case accessibilityDenied
    case inputMonitoringDenied
    case runtimeIdentityMismatch
    case keyboardMonitoringStopped
    case primaryInputSourceMissing
    case voiceInputSourceMissing
    case duplicateInputSources
    case primaryInputSourceUnavailable
    case voiceInputSourceUnavailable
}

public struct AppBlockingReason: Equatable, Sendable {
    public let kind: AppBlockingReasonKind
    public let title: String
    public let message: String
    public let nextStep: String

    public init(
        kind: AppBlockingReasonKind,
        title: String,
        message: String,
        nextStep: String
    ) {
        self.kind = kind
        self.title = title
        self.message = message
        self.nextStep = nextStep
    }
}

public enum RuntimeIdentityStatus: String, Equatable, Sendable {
    case matched
    case mismatched
    case unknown
}

public enum AppLogLevel: String, CaseIterable, Equatable, Sendable {
    case user
    case diagnostic
}

public enum AppLogFilter: String, CaseIterable, Equatable, Sendable {
    case all
    case user
    case diagnostic
}

public struct AppLogEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let level: AppLogLevel
    public let message: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        level: AppLogLevel,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.message = message
    }
}

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

import ApplicationServices
import Foundation

public enum KeyboardEventSummary: Equatable, Sendable {
    case controlPressed(keyCode: Int)
    case controlReleased(keyCode: Int)
    case controlTapCompleted(keyCode: Int)
    case typingKey(keyCode: Int, category: TypingKeyCategory)
    case tapDisabled(reason: String)
    case tapRecoveryAttempted(reason: String)
    case listenerInactive(reason: String)

    public var mappedBehavior: InputBehavior? {
        switch self {
        case .controlTapCompleted:
            return .controlPressed
        case .controlPressed:
            return nil
        case .controlReleased:
            return .controlReleased
        case let .typingKey(_, category):
            switch category {
            case .letters:
                return .typingKeyLetters
            case .numbers:
                return .typingKeyNumbers
            case .space:
                return .typingKeySpace
            case .delete:
                return .typingKeyDelete
            case .returnKey:
                return .typingKeyReturnKey
            }
        case .tapDisabled, .tapRecoveryAttempted, .listenerInactive:
            return nil
        }
    }

    public var rawDescription: String {
        switch self {
        case let .controlPressed(keyCode):
            return "fnDown(keyCode:\(keyCode))"
        case let .controlReleased(keyCode):
            return "fnUp(keyCode:\(keyCode))"
        case let .controlTapCompleted(keyCode):
            return "fnDoubleTapCompleted(keyCode:\(keyCode))"
        case let .typingKey(keyCode, category):
            return "typingKey(keyCode:\(keyCode),category:\(category.rawValue))"
        case let .tapDisabled(reason):
            return "tapDisabled(reason:\(reason))"
        case let .tapRecoveryAttempted(reason):
            return "tapRecoveryAttempted(reason:\(reason))"
        case let .listenerInactive(reason):
            return "listenerInactive(reason:\(reason))"
        }
    }
}

public final class KeyboardEventTapService: KeyboardEventListening {
    private let permissionProvider: PermissionStatusProviding
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var eventHandler: (@Sendable (KeyboardEventSummary) -> Void)?
    private var functionKeyIsDown = false
    private var functionTapCandidate = false
    private var awaitingSecondFunctionTap = false

    public var isRunning: Bool {
        eventTap != nil
    }

    public init(permissionProvider: PermissionStatusProviding) {
        self.permissionProvider = permissionProvider
    }

    deinit {
        stop()
    }

    public func start(eventHandler: @escaping @Sendable (KeyboardEventSummary) -> Void) {
        self.eventHandler = eventHandler

        guard eventTap == nil else {
            return
        }

        let permissionSnapshot = permissionProvider.snapshot()
        guard permissionSnapshot.accessibility == .authorized else {
            emit(.listenerInactive(reason: "Accessibility permission denied"))
            return
        }
        guard permissionSnapshot.inputMonitoring == .authorized else {
            emit(.listenerInactive(reason: "Input Monitoring permission denied"))
            return
        }

        let interestedEvents =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.tapDisabledByTimeout.rawValue) |
            (1 << CGEventType.tapDisabledByUserInput.rawValue)

        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(interestedEvents),
            callback: { _, type, event, userInfo in
                guard let userInfo else {
                    return Unmanaged.passUnretained(event)
                }

                let service = Unmanaged<KeyboardEventTapService>
                    .fromOpaque(userInfo)
                    .takeUnretainedValue()
                service.handleEvent(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: userInfo
        ) else {
            emit(.listenerInactive(reason: "Failed to create event tap"))
            return
        }

        self.eventTap = eventTap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        self.runLoopSource = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    public func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        runLoopSource = nil
        eventTap = nil
        eventHandler = nil
    }

    func handleEvent(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout {
            emit(.tapDisabled(reason: "timeout"))
            reenableTap(reason: "timeout")
            return
        }

        if type == .tapDisabledByUserInput {
            emit(.tapDisabled(reason: "userInput"))
            reenableTap(reason: "userInput")
            return
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        for summary in processedSummaries(for: type, keyCode: keyCode, flags: event.flags) {
            emit(summary)
        }
    }

    func reenableTap(reason: String) {
        guard let eventTap else {
            emit(.listenerInactive(reason: "Event tap was unavailable during recovery"))
            return
        }

        CGEvent.tapEnable(tap: eventTap, enable: true)
        emit(.tapRecoveryAttempted(reason: reason))
    }

    static func summary(for type: CGEventType, keyCode: CGKeyCode, flags: CGEventFlags) -> KeyboardEventSummary? {
        switch type {
        case .flagsChanged:
            guard isFunctionKey(keyCode) else {
                return nil
            }
            if flags.contains(.maskSecondaryFn) {
                return .controlPressed(keyCode: Int(keyCode))
            }
            return .controlReleased(keyCode: Int(keyCode))
        case .keyDown:
            guard let category = typingKeyCategory(for: keyCode) else {
                return nil
            }
            return .typingKey(keyCode: Int(keyCode), category: category)
        case .tapDisabledByTimeout:
            return .tapDisabled(reason: "timeout")
        case .tapDisabledByUserInput:
            return .tapDisabled(reason: "userInput")
        default:
            return nil
        }
    }

    func processedSummaries(for type: CGEventType, keyCode: CGKeyCode, flags: CGEventFlags) -> [KeyboardEventSummary] {
        switch type {
        case .flagsChanged:
            let functionModifierIsDown = flags.contains(.maskSecondaryFn)
            if functionModifierIsDown != functionKeyIsDown {
                return processFunctionKeyStateChange(
                    keyCode: keyCode,
                    isDown: functionModifierIsDown
                )
            }

            if Self.isRepeatedFunctionKeySignal(keyCode: keyCode) {
                return []
            }

            if functionKeyIsDown || awaitingSecondFunctionTap {
                invalidatePendingFunctionDoubleTap()
            }
            return []
        case .keyDown:
            if Self.isSyntheticFunctionKeyDown(keyCode: keyCode) {
                return []
            }

            if functionKeyIsDown || awaitingSecondFunctionTap {
                invalidatePendingFunctionDoubleTap()
            }

            guard let summary = Self.summary(for: type, keyCode: keyCode, flags: flags) else {
                return []
            }
            return [summary]
        default:
            guard let summary = Self.summary(for: type, keyCode: keyCode, flags: flags) else {
                return []
            }
            return [summary]
        }
    }

    static func isFunctionKey(_ keyCode: CGKeyCode) -> Bool {
        keyCode == 63
    }

    static func isRepeatedFunctionKeySignal(keyCode: CGKeyCode) -> Bool {
        repeatedFunctionKeyCodes.contains(Int(keyCode))
    }

    static func isSyntheticFunctionKeyDown(keyCode: CGKeyCode) -> Bool {
        repeatedFunctionKeyCodes.contains(Int(keyCode))
    }

    static func typingKeyCategory(for keyCode: CGKeyCode) -> TypingKeyCategory? {
        let keyCode = Int(keyCode)
        if letterKeyCodes.contains(keyCode) {
            return .letters
        }
        if numberKeyCodes.contains(keyCode) {
            return .numbers
        }
        switch keyCode {
        case 49:
            return .space
        case 51:
            return .delete
        case 36:
            return .returnKey
        default:
            return nil
        }
    }

    private static let letterKeyCodes: Set<Int> = [
        0, 1, 2, 3, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 17,
        31, 32, 34, 35, 37, 38, 40, 41, 45, 46,
    ]

    private static let numberKeyCodes: Set<Int> = [
        18, 19, 20, 21, 22, 23, 25, 26, 28, 29,
    ]

    private static let repeatedFunctionKeyCodes: Set<Int> = [
        63,
        179,
    ]

    private func emit(_ summary: KeyboardEventSummary) {
        eventHandler?(summary)
    }

    private func processFunctionKeyStateChange(keyCode: CGKeyCode, isDown: Bool) -> [KeyboardEventSummary] {
        let keyCode = Int(keyCode)

        if isDown {
            guard !functionKeyIsDown else {
                return []
            }

            functionKeyIsDown = true
            functionTapCandidate = true
            return [.controlPressed(keyCode: keyCode)]
        }

        guard functionKeyIsDown else {
            return []
        }

        functionKeyIsDown = false
        let completedCleanTap = functionTapCandidate
        let shouldEmitTapCompletion = completedCleanTap && awaitingSecondFunctionTap
        functionTapCandidate = false

        if completedCleanTap {
            awaitingSecondFunctionTap = !shouldEmitTapCompletion
        } else {
            awaitingSecondFunctionTap = false
        }

        if shouldEmitTapCompletion {
            return [.controlReleased(keyCode: keyCode), .controlTapCompleted(keyCode: keyCode)]
        }

        return [.controlReleased(keyCode: keyCode)]
    }

    private func invalidatePendingFunctionDoubleTap() {
        awaitingSecondFunctionTap = false
        if functionKeyIsDown {
            functionTapCandidate = false
        }
    }
}

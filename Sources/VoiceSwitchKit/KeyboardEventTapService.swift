import ApplicationServices
import Foundation

public enum KeyboardEventSummary: Equatable, Sendable {
    case optionPressed(keyCode: Int)
    case optionReleased(keyCode: Int)
    case typingKey(keyCode: Int)
    case tapDisabled(reason: String)
    case tapRecoveryAttempted(reason: String)
    case listenerInactive(reason: String)

    public var mappedBehavior: InputBehavior? {
        switch self {
        case .optionPressed:
            return .optionPressed
        case .optionReleased:
            return .optionReleased
        case .typingKey:
            return .typingDetected
        case .tapDisabled, .tapRecoveryAttempted, .listenerInactive:
            return nil
        }
    }

    public var rawDescription: String {
        switch self {
        case let .optionPressed(keyCode):
            return "optionDown(keyCode:\(keyCode))"
        case let .optionReleased(keyCode):
            return "optionUp(keyCode:\(keyCode))"
        case let .typingKey(keyCode):
            return "typingKey(keyCode:\(keyCode))"
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
        guard let summary = Self.summary(for: type, keyCode: keyCode, flags: event.flags) else {
            return
        }

        emit(summary)
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
            guard isOptionKey(keyCode) else {
                return nil
            }
            return flags.contains(.maskAlternate)
                ? .optionPressed(keyCode: Int(keyCode))
                : .optionReleased(keyCode: Int(keyCode))
        case .keyDown:
            guard isTypingKey(keyCode) else {
                return nil
            }
            return .typingKey(keyCode: Int(keyCode))
        case .tapDisabledByTimeout:
            return .tapDisabled(reason: "timeout")
        case .tapDisabledByUserInput:
            return .tapDisabled(reason: "userInput")
        default:
            return nil
        }
    }

    static func isOptionKey(_ keyCode: CGKeyCode) -> Bool {
        keyCode == 58 || keyCode == 61
    }

    static func isTypingKey(_ keyCode: CGKeyCode) -> Bool {
        typingKeyCodes.contains(Int(keyCode))
    }

    private static let typingKeyCodes: Set<Int> = [
        0, 1, 2, 3, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 17,
        18, 19, 20, 21, 22, 23, 25, 26, 28, 29,
        31, 32, 34, 35, 37, 38, 40, 41, 45, 46,
        49, 36, 51,
    ]

    private func emit(_ summary: KeyboardEventSummary) {
        eventHandler?(summary)
    }
}

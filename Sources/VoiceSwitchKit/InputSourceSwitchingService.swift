import Carbon
import Foundation

public enum InputSourceSwitchingError: LocalizedError {
    case currentInputSourceUnavailable
    case targetInputSourceNotFound(String)
    case selectFailed(String, OSStatus)

    public var errorDescription: String? {
        switch self {
        case .currentInputSourceUnavailable:
            return "Current input source is unavailable."
        case let .targetInputSourceNotFound(id):
            return "Target input source was not found: \(id)"
        case let .selectFailed(id, status):
            return "Failed to select input source \(id). OSStatus=\(status)"
        }
    }
}

public final class InputSourceSwitchingService: InputSourceSwitching, @unchecked Sendable {
    public init() {}

    public func currentSelectedInputSourceID() throws -> String? {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        return stringProperty(for: source, key: kTISPropertyInputSourceID)
    }

    public func switchToInputSource(id: String) throws {
        let filter = [kTISPropertyInputSourceID: id as CFString] as CFDictionary
        let sourceList = TISCreateInputSourceList(filter, false).takeRetainedValue() as NSArray

        guard let source = sourceList.firstObject as CFTypeRef? else {
            throw InputSourceSwitchingError.targetInputSourceNotFound(id)
        }
        let inputSource = unsafeDowncast(source, to: TISInputSource.self)

        let status = TISSelectInputSource(inputSource)
        guard status == noErr else {
            throw InputSourceSwitchingError.selectFailed(id, status)
        }
    }

    private func stringProperty(for inputSource: TISInputSource, key: CFString) -> String? {
        guard let rawValue = TISGetInputSourceProperty(inputSource, key) else {
            return nil
        }

        return unsafeBitCast(rawValue, to: CFString.self) as String
    }
}

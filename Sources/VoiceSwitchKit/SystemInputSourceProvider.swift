import Carbon
import Foundation

public final class SystemInputSourceProvider: InputSourceProviding, @unchecked Sendable {
    public init() {}

    public func selectableInputSources() throws -> [InputSourceDescriptor] {
        let filter = [kTISPropertyInputSourceIsSelectCapable: kCFBooleanTrue] as CFDictionary
        let sourceList = TISCreateInputSourceList(filter, false).takeRetainedValue() as NSArray

        return sourceList.compactMap { item in
            guard let source = item as CFTypeRef? else {
                return nil
            }

            let inputSource = unsafeDowncast(source, to: TISInputSource.self)
            guard
                let id = stringProperty(for: inputSource, key: kTISPropertyInputSourceID),
                let displayName = stringProperty(for: inputSource, key: kTISPropertyLocalizedName)
            else {
                return nil
            }

            return InputSourceDescriptor(
                id: id,
                displayName: displayName,
                isSelected: boolProperty(for: inputSource, key: kTISPropertyInputSourceIsSelected)
            )
        }
        .sorted { lhs, rhs in
            lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }

    private func stringProperty(for inputSource: TISInputSource, key: CFString) -> String? {
        guard let rawValue = TISGetInputSourceProperty(inputSource, key) else {
            return nil
        }

        return unsafeBitCast(rawValue, to: CFString.self) as String
    }

    private func boolProperty(for inputSource: TISInputSource, key: CFString) -> Bool {
        guard let rawValue = TISGetInputSourceProperty(inputSource, key) else {
            return false
        }

        return CFBooleanGetValue(unsafeBitCast(rawValue, to: CFBoolean.self))
    }
}

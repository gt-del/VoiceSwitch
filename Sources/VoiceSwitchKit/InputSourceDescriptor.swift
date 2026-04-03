import Foundation

public struct InputSourceDescriptor: Equatable, Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let isSelected: Bool

    public init(id: String, displayName: String, isSelected: Bool) {
        self.id = id
        self.displayName = displayName
        self.isSelected = isSelected
    }
}

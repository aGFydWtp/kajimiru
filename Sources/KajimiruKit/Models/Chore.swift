import Foundation

/// Definition of a chore shared within a group.
public struct Chore: Identifiable, Codable, Hashable, Sendable {
    public static let allowedWeights: Set<Int> = [1, 2, 3, 5, 8]
    public static let defaultWeight: Int = 1

    public let id: UUID
    public var groupId: UUID
    public var title: String
    public var weight: Int
    public var notes: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        groupId: UUID,
        title: String,
        weight: Int = Chore.defaultWeight,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        precondition(Self.allowedWeights.contains(weight), "Invalid chore weight")
        self.id = id
        self.groupId = groupId
        self.title = title
        self.weight = weight
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func isValidWeight(_ weight: Int) -> Bool {
        allowedWeights.contains(weight)
    }

    public func updating(
        title: String? = nil,
        weight: Int? = nil,
        notes: String?? = nil
    ) -> Chore {
        var copy = self
        if let title {
            copy.title = title
        }
        if let weight {
            precondition(Self.isValidWeight(weight), "Invalid chore weight")
            copy.weight = weight
        }
        if let notes {
            copy.notes = notes
        }
        copy.updatedAt = Date()
        return copy
    }
}

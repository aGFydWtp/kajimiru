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
    public var isFavorite: Bool
    public var createdAt: Date
    public var createdBy: UUID
    public var updatedAt: Date
    public var updatedBy: UUID
    public var deletedAt: Date?
    public var deletedBy: UUID?

    public init(
        id: UUID = UUID(),
        groupId: UUID,
        title: String,
        weight: Int = Chore.defaultWeight,
        notes: String? = nil,
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        createdBy: UUID,
        updatedAt: Date = Date(),
        updatedBy: UUID,
        deletedAt: Date? = nil,
        deletedBy: UUID? = nil
    ) {
        precondition(Self.allowedWeights.contains(weight), "Invalid chore weight")
        self.id = id
        self.groupId = groupId
        self.title = title
        self.weight = weight
        self.notes = notes
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.updatedAt = updatedAt
        self.updatedBy = updatedBy
        self.deletedAt = deletedAt
        self.deletedBy = deletedBy
    }

    public static func isValidWeight(_ weight: Int) -> Bool {
        allowedWeights.contains(weight)
    }

    public func updating(
        title: String? = nil,
        weight: Int? = nil,
        notes: String?? = nil,
        isFavorite: Bool? = nil,
        updatedBy: UUID
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
        if let isFavorite {
            copy.isFavorite = isFavorite
        }
        copy.updatedBy = updatedBy
        copy.updatedAt = Date()
        return copy
    }
}

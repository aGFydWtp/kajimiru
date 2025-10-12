import Foundation

/// Collaborative space (household, office, etc.) where chores and records are shared.
public struct Group: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var icon: String?
    public var members: [Member]
    public var createdAt: Date
    public var createdBy: String
    public var updatedAt: Date
    public var updatedBy: String

    public init(
        id: UUID = UUID(),
        name: String,
        icon: String? = nil,
        members: [Member] = [],
        createdAt: Date = Date(),
        createdBy: String,
        updatedAt: Date = Date(),
        updatedBy: String
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.members = members
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.updatedAt = updatedAt
        self.updatedBy = updatedBy
    }

    /// Returns active (non-deleted) members only.
    public var activeMembers: [Member] {
        members.filter { !$0.isDeleted }
    }

    /// Returns a new group with updated properties.
    public func updating(
        name: String? = nil,
        icon: String?? = nil,
        members: [Member]? = nil,
        updatedBy: String
    ) -> Group {
        var copy = self
        if let name {
            copy.name = name
        }
        if let icon {
            copy.icon = icon
        }
        if let members {
            copy.members = members
        }
        copy.updatedBy = updatedBy
        copy.updatedAt = Date()
        return copy
    }
}

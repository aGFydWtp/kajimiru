import Foundation

/// Represents a member who performs chores within a group.
/// Members can optionally be linked to a User account but exist independently.
/// Supports soft deletion to preserve historical chore log references.
public struct Member: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let userId: UUID?
    public var displayName: String
    public var avatarURL: URL?
    public var createdAt: Date
    public var createdBy: UUID
    public var updatedAt: Date
    public var updatedBy: UUID
    public var deletedAt: Date?
    public var deletedBy: UUID?

    public init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        displayName: String,
        avatarURL: URL? = nil,
        createdAt: Date = Date(),
        createdBy: UUID,
        updatedAt: Date = Date(),
        updatedBy: UUID,
        deletedAt: Date? = nil,
        deletedBy: UUID? = nil
    ) {
        self.id = id
        self.userId = userId
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.updatedAt = updatedAt
        self.updatedBy = updatedBy
        self.deletedAt = deletedAt
        self.deletedBy = deletedBy
    }

    /// Returns true if this member has been soft deleted.
    public var isDeleted: Bool {
        deletedAt != nil
    }

    /// Returns a new member with updated properties.
    public func updating(
        displayName: String? = nil,
        avatarURL: URL?? = nil,
        updatedBy: UUID
    ) -> Member {
        var copy = self
        if let displayName {
            copy.displayName = displayName
        }
        if let avatarURL {
            copy.avatarURL = avatarURL
        }
        copy.updatedBy = updatedBy
        copy.updatedAt = Date()
        return copy
    }

    /// Returns a new member marked as deleted.
    public func softDeleting(deletedBy: UUID) -> Member {
        var copy = self
        copy.deletedAt = Date()
        copy.deletedBy = deletedBy
        return copy
    }
}

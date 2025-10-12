import Foundation

/// Role of a member within a group
public enum MemberRole: String, Codable, Hashable, Sendable {
    case admin
    case member
}

/// Represents a member who performs chores within a group.
/// Members can optionally be linked to a User account (via userId = Firebase UID) but exist independently.
/// Supports soft deletion to preserve historical chore log references.
public struct Member: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let userId: String?  // Firebase Authentication UID (links to User.id)
    public var displayName: String
    public var avatarURL: URL?
    public var groupId: UUID
    public var role: MemberRole
    public var createdAt: Date
    public var createdBy: String
    public var updatedAt: Date
    public var updatedBy: String
    public var deletedAt: Date?
    public var deletedBy: String?

    public init(
        id: UUID = UUID(),
        userId: String? = nil,
        displayName: String,
        avatarURL: URL? = nil,
        groupId: UUID,
        role: MemberRole = .member,
        createdAt: Date = Date(),
        createdBy: String,
        updatedAt: Date = Date(),
        updatedBy: String,
        deletedAt: Date? = nil,
        deletedBy: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.groupId = groupId
        self.role = role
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
        updatedBy: String
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

    /// Returns a new member with updated userId and firebaseUid (for linking to Firebase Auth).
    public func updating(
        userId: String,
        updatedBy: String
    ) -> Member {
        Member(
            id: self.id,
            userId: userId,
            displayName: self.displayName,
            avatarURL: self.avatarURL,
            groupId: self.groupId,
            role: self.role,
            createdAt: self.createdAt,
            createdBy: self.createdBy,
            updatedAt: Date(),
            updatedBy: updatedBy,
            deletedAt: self.deletedAt,
            deletedBy: self.deletedBy
        )
    }

    /// Returns a new member marked as deleted.
    public func softDeleting(deletedBy: String) -> Member {
        var copy = self
        copy.deletedAt = Date()
        copy.deletedBy = deletedBy
        return copy
    }
}

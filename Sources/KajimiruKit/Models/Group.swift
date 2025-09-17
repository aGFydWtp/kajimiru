import Foundation

/// Role a user can have within a group when collaborating on chore management.
public enum GroupRole: String, Codable, CaseIterable, Sendable {
    case admin
    case editor
    case viewer
}

/// Represents membership information for a user in a specific group.
public struct GroupMembership: Codable, Hashable, Sendable {
    public var userId: UUID
    public var role: GroupRole
    public var joinedAt: Date

    public init(userId: UUID, role: GroupRole, joinedAt: Date = Date()) {
        self.userId = userId
        self.role = role
        self.joinedAt = joinedAt
    }
}

/// Collaborative space (household, office, etc.) where chores and records are shared.
public struct Group: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var icon: String?
    public var members: [GroupMembership]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        icon: String? = nil,
        members: [GroupMembership] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.members = members
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Returns the membership role for a given user if present.
    public func role(of userId: UUID) -> GroupRole? {
        members.first { $0.userId == userId }?.role
    }

    /// Returns a new group with the provided membership list.
    public func updatingMembers(_ members: [GroupMembership]) -> Group {
        var copy = self
        copy.members = members
        copy.updatedAt = Date()
        return copy
    }
}

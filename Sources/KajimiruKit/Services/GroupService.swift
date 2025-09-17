import Foundation

public struct GroupDraft: Sendable {
    public var name: String
    public var icon: String?
    public var initialMembers: [GroupMemberInput]

    public init(name: String, icon: String? = nil, initialMembers: [GroupMemberInput] = []) {
        self.name = name
        self.icon = icon
        self.initialMembers = initialMembers
    }
}

public struct GroupMemberInput: Sendable {
    public var userId: UUID
    public var role: GroupRole

    public init(userId: UUID, role: GroupRole) {
        self.userId = userId
        self.role = role
    }
}

public struct GroupUpdate: Sendable {
    public var name: String?
    public var icon: String??

    public init(name: String? = nil, icon: String?? = nil) {
        self.name = name
        self.icon = icon
    }
}

/// Service responsible for coordinating collaboration rules around groups and memberships.
public final class GroupService: Sendable {
    private let groupRepository: GroupRepository

    public init(groupRepository: GroupRepository) {
        self.groupRepository = groupRepository
    }

    /// Creates a new collaborative space owned by the actor and persists it.
    public func createGroup(draft: GroupDraft, ownerId: UUID) async throws -> Group {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw KajimiruError.validationFailed(reason: "Group name must not be empty.")
        }

        var seenUserIds: Set<UUID> = [ownerId]
        var members: [GroupMembership] = [GroupMembership(userId: ownerId, role: .admin)]

        for member in draft.initialMembers {
            guard seenUserIds.insert(member.userId).inserted else {
                throw KajimiruError.validationFailed(reason: "Duplicate member entries are not allowed.")
            }
            members.append(GroupMembership(userId: member.userId, role: member.role))
        }

        try ensureAtLeastOneAdmin(in: members)

        var group = Group(
            name: name,
            icon: draft.icon?.trimmingCharacters(in: .whitespacesAndNewlines),
            members: members
        )
        group.updatedAt = Date()
        try await groupRepository.save(group)
        return group
    }

    /// Applies updates to the group metadata, requiring admin privileges.
    public func updateGroup(groupId: UUID, actorId: UUID, update: GroupUpdate) async throws -> Group {
        var group = try await loadGroup(groupId: groupId)
        try ensureActorIsAdmin(group: group, actorId: actorId)

        if let name = update.name {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw KajimiruError.validationFailed(reason: "Group name must not be empty.")
            }
            group.name = trimmed
        }
        if let icon = update.icon {
            group.icon = icon?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        group.updatedAt = Date()
        try await groupRepository.save(group)
        return group
    }

    /// Adds a new member to the group with the specified role.
    public func addMember(groupId: UUID, actorId: UUID, member: GroupMemberInput) async throws -> Group {
        var group = try await loadGroup(groupId: groupId)
        try ensureActorIsAdmin(group: group, actorId: actorId)

        guard group.members.contains(where: { $0.userId == member.userId }) == false else {
            throw KajimiruError.validationFailed(reason: "User is already a member of the group.")
        }

        var members = group.members
        members.append(GroupMembership(userId: member.userId, role: member.role))
        try ensureAtLeastOneAdmin(in: members)
        group = group.updatingMembers(members)
        try await groupRepository.save(group)
        return group
    }

    /// Changes the role assigned to a member, enforcing admin restrictions.
    public func updateMemberRole(groupId: UUID, actorId: UUID, memberId: UUID, role: GroupRole) async throws -> Group {
        var group = try await loadGroup(groupId: groupId)
        try ensureActorIsAdmin(group: group, actorId: actorId)

        guard let index = group.members.firstIndex(where: { $0.userId == memberId }) else {
            throw KajimiruError.notFound
        }

        var members = group.members
        members[index].role = role
        try ensureAtLeastOneAdmin(in: members)
        group = group.updatingMembers(members)
        try await groupRepository.save(group)
        return group
    }

    /// Removes a member from the group. Actors may remove themselves while preserving admin invariants.
    public func removeMember(groupId: UUID, actorId: UUID, memberId: UUID) async throws -> Group {
        var group = try await loadGroup(groupId: groupId)
        guard let actorRole = group.role(of: actorId) else {
            throw KajimiruError.unauthorized
        }
        if actorId != memberId {
            guard actorRole == .admin else { throw KajimiruError.unauthorized }
        }

        guard let index = group.members.firstIndex(where: { $0.userId == memberId }) else {
            throw KajimiruError.notFound
        }

        var members = group.members
        let removedMember = members.remove(at: index)
        if removedMember.role == .admin {
            try ensureAtLeastOneAdmin(in: members)
        }
        group = group.updatingMembers(members)
        try await groupRepository.save(group)
        return group
    }

    private func loadGroup(groupId: UUID) async throws -> Group {
        guard let group = try await groupRepository.fetchGroup(id: groupId) else {
            throw KajimiruError.notFound
        }
        return group
    }

    private func ensureActorIsAdmin(group: Group, actorId: UUID) throws {
        guard let role = group.role(of: actorId), role == .admin else {
            throw KajimiruError.unauthorized
        }
    }

    private func ensureAtLeastOneAdmin(in members: [GroupMembership]) throws {
        guard members.contains(where: { $0.role == .admin }) else {
            throw KajimiruError.validationFailed(reason: "Group must contain at least one admin.")
        }
    }
}

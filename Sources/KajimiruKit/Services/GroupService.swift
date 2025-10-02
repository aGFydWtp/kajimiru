import Foundation

public struct GroupDraft: Sendable {
    public var name: String
    public var icon: String?

    public init(name: String, icon: String? = nil) {
        self.name = name
        self.icon = icon
    }
}

public struct MemberDraft: Sendable {
    public var displayName: String
    public var userId: UUID?
    public var avatarURL: URL?

    public init(displayName: String, userId: UUID? = nil, avatarURL: URL? = nil) {
        self.displayName = displayName
        self.userId = userId
        self.avatarURL = avatarURL
    }
}

/// Service responsible for group and member management.
public final class GroupService: Sendable {
    private let groupRepository: GroupRepository
    private let memberRepository: MemberRepository

    public init(groupRepository: GroupRepository, memberRepository: MemberRepository) {
        self.groupRepository = groupRepository
        self.memberRepository = memberRepository
    }

    /// Creates a new group.
    public func createGroup(draft: GroupDraft, createdBy: UUID) async throws -> Group {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw KajimiruError.validationFailed(reason: "Group name must not be empty.")
        }

        let group = Group(
            name: name,
            icon: draft.icon?.trimmingCharacters(in: .whitespacesAndNewlines),
            members: [],
            createdBy: createdBy,
            updatedBy: createdBy
        )
        try await groupRepository.save(group)
        return group
    }

    /// Updates group metadata.
    public func updateGroup(groupId: UUID, name: String? = nil, icon: String?? = nil, updatedBy: UUID) async throws -> Group {
        guard var group = try await groupRepository.fetchGroup(id: groupId) else {
            throw KajimiruError.notFound
        }

        if let name {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw KajimiruError.validationFailed(reason: "Group name must not be empty.")
            }
            group = group.updating(name: trimmed, updatedBy: updatedBy)
        }
        if let icon {
            group = group.updating(icon: icon, updatedBy: updatedBy)
        }

        try await groupRepository.save(group)
        return group
    }

    /// Adds a new member to the group.
    public func addMember(groupId: UUID, draft: MemberDraft, createdBy: UUID) async throws -> Member {
        guard let group = try await groupRepository.fetchGroup(id: groupId) else {
            throw KajimiruError.notFound
        }

        let displayName = draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !displayName.isEmpty else {
            throw KajimiruError.validationFailed(reason: "Member display name must not be empty.")
        }

        let member = Member(
            userId: draft.userId,
            displayName: displayName,
            avatarURL: draft.avatarURL,
            createdBy: createdBy,
            updatedBy: createdBy
        )
        try await memberRepository.save(member)

        // Update group's member list
        var updatedGroup = group
        updatedGroup = updatedGroup.updating(members: group.members + [member], updatedBy: createdBy)
        try await groupRepository.save(updatedGroup)

        return member
    }

    /// Updates an existing member.
    public func updateMember(memberId: UUID, displayName: String? = nil, avatarURL: URL?? = nil, updatedBy: UUID) async throws -> Member {
        guard let member = try await memberRepository.fetchMember(id: memberId) else {
            throw KajimiruError.notFound
        }

        let updated = member.updating(displayName: displayName, avatarURL: avatarURL, updatedBy: updatedBy)
        try await memberRepository.save(updated)
        return updated
    }

    /// Soft deletes a member.
    public func deleteMember(groupId: UUID, memberId: UUID, deletedBy: UUID) async throws {
        guard let member = try await memberRepository.fetchMember(id: memberId) else {
            throw KajimiruError.notFound
        }

        let deleted = member.softDeleting(deletedBy: deletedBy)
        try await memberRepository.save(deleted)

        // Update group's member list
        guard var group = try await groupRepository.fetchGroup(id: groupId) else {
            throw KajimiruError.notFound
        }
        if let index = group.members.firstIndex(where: { $0.id == memberId }) {
            var members = group.members
            members[index] = deleted
            group = group.updating(members: members, updatedBy: deletedBy)
            try await groupRepository.save(group)
        }
    }

    /// Lists members in a group.
    public func listMembers(in groupId: UUID, includeDeleted: Bool = false) async throws -> [Member] {
        try await memberRepository.listMembers(in: groupId, includeDeleted: includeDeleted)
    }
}

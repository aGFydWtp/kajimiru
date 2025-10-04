import Foundation

public actor InMemoryChoreRepository: ChoreRepository {
    private var chores: [UUID: Chore] = [:]

    public init() {}

    public func listChores(in groupId: UUID, includeDeleted: Bool) async throws -> [Chore] {
        chores.values.filter {
            $0.groupId == groupId && (includeDeleted || $0.deletedAt == nil)
        }
    }

    public func fetchChore(id: UUID) async throws -> Chore? {
        chores[id]
    }

    public func save(_ chore: Chore) async throws {
        chores[chore.id] = chore
    }
}

public actor InMemoryChoreLogRepository: ChoreLogRepository {
    private var logs: [UUID: ChoreLog] = [:]

    public init() {}

    public func listLogs(in groupId: UUID, since date: Date?) async throws -> [ChoreLog] {
        logs.values
            .filter { $0.groupId == groupId && (date == nil || $0.createdAt >= date!) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    public func save(_ log: ChoreLog) async throws {
        logs[log.id] = log
    }

    public func deleteLog(id: UUID, in groupId: UUID) async throws {
        guard let log = logs[id], log.groupId == groupId else {
            throw KajimiruError.notFound
        }
        logs.removeValue(forKey: id)
    }
}

public actor InMemoryGroupRepository: GroupRepository {
    private var groups: [UUID: Group] = [:]

    public init(groups: [Group] = []) {
        for group in groups { self.groups[group.id] = group }
    }

    public func fetchGroup(id: UUID) async throws -> Group? {
        groups[id]
    }

    public func save(_ group: Group) async throws {
        groups[group.id] = group
    }
}

public actor InMemoryReminderRepository: ReminderRepository {
    private var reminders: [UUID: Reminder] = [:]

    public init(reminders: [Reminder] = []) {
        for reminder in reminders { self.reminders[reminder.id] = reminder }
    }

    public func listReminders(choreId: UUID) async throws -> [Reminder] {
        reminders.values.filter { $0.choreId == choreId }
    }

    public func save(_ reminder: Reminder) async throws {
        reminders[reminder.id] = reminder
    }

    public func deleteReminder(id: UUID, choreId: UUID) async throws {
        guard let reminder = reminders[id], reminder.choreId == choreId else {
            throw KajimiruError.notFound
        }
        reminders.removeValue(forKey: id)
    }
}

public actor InMemoryUserRepository: UserRepository {
    private var users: [UUID: User] = [:]

    public init(users: [User] = []) {
        for user in users { self.users[user.id] = user }
    }

    public func fetchUsers(ids: [UUID]) async throws -> [User] {
        ids.compactMap { users[$0] }
    }

    public func save(_ user: User) async throws {
        users[user.id] = user
    }
}

public actor InMemoryMemberRepository: MemberRepository {
    private var members: [UUID: Member] = [:]
    private var groupMembers: [UUID: Set<UUID>] = [:] // groupId -> Set<memberId>

    public init(members: [Member] = []) {
        for member in members {
            self.members[member.id] = member
        }
    }

    public func listMembers(in groupId: UUID, includeDeleted: Bool) async throws -> [Member] {
        guard let memberIds = groupMembers[groupId] else { return [] }
        return memberIds.compactMap { members[$0] }.filter { includeDeleted || !$0.isDeleted }
    }

    public func fetchMember(id: UUID) async throws -> Member? {
        members[id]
    }

    public func save(_ member: Member) async throws {
        members[member.id] = member
        // Auto-associate member with group
        if groupMembers[member.groupId] == nil {
            groupMembers[member.groupId] = []
        }
        groupMembers[member.groupId]?.insert(member.id)
    }

    public func softDeleteMember(id: UUID, in groupId: UUID, deletedBy: UUID) async throws {
        guard var member = members[id] else {
            throw KajimiruError.notFound
        }
        member = member.softDeleting(deletedBy: deletedBy)
        members[id] = member
    }

    /// List all groups that a user belongs to by their Firebase UID
    public func listGroupsForUser(firebaseUid: String) async throws -> [UUID] {
        var groupIds: [UUID] = []
        
        // Search through all members to find those with matching firebaseUid
        for member in members.values {
            if member.firebaseUid == firebaseUid && !member.isDeleted {
                if !groupIds.contains(member.groupId) {
                    groupIds.append(member.groupId)
                }
            }
        }
        
        return groupIds
    }
}

public actor InMemoryGroupInviteRepository: GroupInviteRepository {
    private var invites: [UUID: GroupInvite] = [:]
    private var codeIndex: [String: UUID] = [:] // code -> invite ID

    public init(invites: [GroupInvite] = []) {
        for invite in invites {
            self.invites[invite.id] = invite
            self.codeIndex[invite.code] = invite.id
        }
    }

    public func fetchInvite(code: String) async throws -> GroupInvite? {
        guard let inviteId = codeIndex[code] else { return nil }
        return invites[inviteId]
    }

    public func listInvites(for groupId: UUID) async throws -> [GroupInvite] {
        invites.values
            .filter { $0.groupId == groupId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public func save(_ invite: GroupInvite) async throws {
        invites[invite.id] = invite
        codeIndex[invite.code] = invite.id
    }

    public func deleteInvite(id: UUID) async throws {
        guard let invite = invites[id] else {
            throw KajimiruError.notFound
        }
        invites.removeValue(forKey: id)
        codeIndex.removeValue(forKey: invite.code)
    }
}

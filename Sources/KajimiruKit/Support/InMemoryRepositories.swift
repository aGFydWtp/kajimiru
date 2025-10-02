import Foundation

public actor InMemoryChoreRepository: ChoreRepository {
    private var chores: [UUID: Chore] = [:]

    public init() {}

    public func listChores(in groupId: UUID) async throws -> [Chore] {
        chores.values.filter { $0.groupId == groupId }
    }

    public func fetchChore(id: UUID) async throws -> Chore? {
        chores[id]
    }

    public func save(_ chore: Chore) async throws {
        chores[chore.id] = chore
    }

    public func deleteChore(id: UUID, in groupId: UUID) async throws {
        guard let chore = chores[id], chore.groupId == groupId else {
            throw KajimiruError.notFound
        }
        chores.removeValue(forKey: id)
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

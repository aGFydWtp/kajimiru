import Foundation

/// Handles persistence for chores shared within a group.
public protocol ChoreRepository: Sendable {
    func listChores(in groupId: UUID) async throws -> [Chore]
    func fetchChore(id: UUID) async throws -> Chore?
    func save(_ chore: Chore) async throws
    func deleteChore(id: UUID, in groupId: UUID) async throws
}

/// Handles persistence for chore execution logs.
public protocol ChoreLogRepository: Sendable {
    func listLogs(in groupId: UUID, since date: Date?) async throws -> [ChoreLog]
    func save(_ log: ChoreLog) async throws
    func deleteLog(id: UUID, in groupId: UUID) async throws
}

/// Handles persistence for group level metadata.
public protocol GroupRepository: Sendable {
    func fetchGroup(id: UUID) async throws -> Group?
    func save(_ group: Group) async throws
}

/// Handles reminder configuration and scheduling metadata.
public protocol ReminderRepository: Sendable {
    func listReminders(choreId: UUID) async throws -> [Reminder]
    func save(_ reminder: Reminder) async throws
    func deleteReminder(id: UUID, choreId: UUID) async throws
}

/// Handles user profile information.
public protocol UserRepository: Sendable {
    func fetchUsers(ids: [UUID]) async throws -> [User]
    func save(_ user: User) async throws
}

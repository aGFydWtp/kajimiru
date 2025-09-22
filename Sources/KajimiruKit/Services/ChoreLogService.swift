import Foundation

public struct ChoreLogDraft: Sendable {
    public var groupId: UUID
    public var choreId: UUID
    public var performerId: UUID
    public var memo: String?
    public var createdAt: Date?

    public init(
        groupId: UUID,
        choreId: UUID,
        performerId: UUID,
        memo: String? = nil,
        createdAt: Date? = nil
    ) {
        self.groupId = groupId
        self.choreId = choreId
        self.performerId = performerId
        self.memo = memo
        self.createdAt = createdAt
    }
}

public struct ChoreLogUpdate: Sendable {
    public var performerId: UUID?
    public var memo: String??

    public init(performerId: UUID? = nil, memo: String?? = nil) {
        self.performerId = performerId
        self.memo = memo
    }
}

/// Service responsible for recording the execution of chores and ensuring data consistency.
public final class ChoreLogService: Sendable {
    private let logRepository: ChoreLogRepository
    private let choreRepository: ChoreRepository
    private let groupRepository: GroupRepository

    public init(
        logRepository: ChoreLogRepository,
        choreRepository: ChoreRepository,
        groupRepository: GroupRepository
    ) {
        self.logRepository = logRepository
        self.choreRepository = choreRepository
        self.groupRepository = groupRepository
    }

    /// Persists a new chore log after validating the request.
    public func recordChore(draft: ChoreLogDraft, actorId: UUID) async throws -> ChoreLog {
        try await validatePermissions(groupId: draft.groupId, actorId: actorId)
        let chore = try await fetchChore(id: draft.choreId, groupId: draft.groupId)
        try validate(logDraft: draft)

        let createdAt = draft.createdAt ?? Date()
        let log = ChoreLog(
            choreId: draft.choreId,
            groupId: draft.groupId,
            performerId: draft.performerId,
            weight: chore.weight,
            memo: draft.memo?.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: createdAt,
            updatedAt: createdAt
        )
        try await logRepository.save(log)
        return log
    }

    /// Applies updates to an existing log while ensuring the actor has access.
    public func updateLog(logId: UUID, groupId: UUID, actorId: UUID, update: ChoreLogUpdate) async throws -> ChoreLog {
        try await validatePermissions(groupId: groupId, actorId: actorId)
        let logs = try await logRepository.listLogs(in: groupId, since: nil)
        guard let existingIndex = logs.firstIndex(where: { $0.id == logId }) else {
            throw KajimiruError.notFound
        }
        var log = logs[existingIndex]

        if let performerId = update.performerId {
            log.performerId = performerId
        }
        if let memo = update.memo {
            log.memo = memo?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        log = log.updating()
        try await logRepository.save(log)
        return log
    }

    /// Deletes the log if the actor has modification permissions.
    public func deleteLog(logId: UUID, groupId: UUID, actorId: UUID) async throws {
        try await validatePermissions(groupId: groupId, actorId: actorId)
        try await logRepository.deleteLog(id: logId, in: groupId)
    }

    /// Fetches logs for dashboards or analytics use cases.
    public func fetchLogs(groupId: UUID, since date: Date?) async throws -> [ChoreLog] {
        try await logRepository.listLogs(in: groupId, since: date)
    }

    private func validatePermissions(groupId: UUID, actorId: UUID) async throws {
        guard let group = try await groupRepository.fetchGroup(id: groupId),
              let role = group.role(of: actorId), role != .viewer else {
            throw KajimiruError.unauthorized
        }
    }

    private func fetchChore(id: UUID, groupId: UUID) async throws -> Chore {
        guard let chore = try await choreRepository.fetchChore(id: id), chore.groupId == groupId else {
            throw KajimiruError.validationFailed(reason: "Chore does not belong to the provided group.")
        }
        return chore
    }

    private func validate(logDraft: ChoreLogDraft) throws {
        if let timestamp = logDraft.createdAt {
            let futureThreshold = Date().addingTimeInterval(60 * 60 * 24)
            guard timestamp <= futureThreshold else {
                throw KajimiruError.validationFailed(reason: "Created date cannot be more than 24 hours in the future.")
            }
        }
    }
}

import Foundation

/// Input model used when creating a new chore from user supplied data.
public struct ChoreDraft: Sendable {
    public var groupId: UUID
    public var title: String
    public var category: ChoreCategory
    public var defaultAssigneeId: UUID?
    public var estimatedMinutes: Int?
    public var notes: String?
    public var frequency: ChoreFrequency

    public init(
        groupId: UUID,
        title: String,
        category: ChoreCategory,
        defaultAssigneeId: UUID? = nil,
        estimatedMinutes: Int? = nil,
        notes: String? = nil,
        frequency: ChoreFrequency = .onDemand
    ) {
        self.groupId = groupId
        self.title = title
        self.category = category
        self.defaultAssigneeId = defaultAssigneeId
        self.estimatedMinutes = estimatedMinutes
        self.notes = notes
        self.frequency = frequency
    }
}

/// Patch model describing updates applied to an existing chore.
public struct ChoreUpdate: Sendable {
    public var title: String?
    public var category: ChoreCategory?
    public var defaultAssigneeId: UUID??
    public var estimatedMinutes: Int??
    public var notes: String??
    public var frequency: ChoreFrequency?

    public init(
        title: String? = nil,
        category: ChoreCategory? = nil,
        defaultAssigneeId: UUID?? = nil,
        estimatedMinutes: Int?? = nil,
        notes: String?? = nil,
        frequency: ChoreFrequency? = nil
    ) {
        self.title = title
        self.category = category
        self.defaultAssigneeId = defaultAssigneeId
        self.estimatedMinutes = estimatedMinutes
        self.notes = notes
        self.frequency = frequency
    }
}

/// Service responsible for enforcing business rules around chore definitions.
public final class ChoreService: Sendable {
    private let choreRepository: ChoreRepository
    private let groupRepository: GroupRepository

    public init(choreRepository: ChoreRepository, groupRepository: GroupRepository) {
        self.choreRepository = choreRepository
        self.groupRepository = groupRepository
    }

    /// Creates a new chore if the actor has the appropriate permissions.
    public func createChore(draft: ChoreDraft, actorId: UUID) async throws -> Chore {
        try validate(draft: draft)
        guard let group = try await groupRepository.fetchGroup(id: draft.groupId) else {
            throw KajimiruError.notFound
        }
        guard let role = group.role(of: actorId), role != .viewer else {
            throw KajimiruError.unauthorized
        }

        let chore = Chore(
            groupId: draft.groupId,
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            category: draft.category,
            defaultAssigneeId: draft.defaultAssigneeId,
            estimatedMinutes: draft.estimatedMinutes,
            notes: draft.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
            frequency: draft.frequency
        )
        try await choreRepository.save(chore)
        return chore
    }

    /// Applies updates to an existing chore and persists the result.
    public func updateChore(id: UUID, actorId: UUID, update: ChoreUpdate) async throws -> Chore {
        guard var chore = try await choreRepository.fetchChore(id: id) else {
            throw KajimiruError.notFound
        }
        guard let group = try await groupRepository.fetchGroup(id: chore.groupId),
              let role = group.role(of: actorId), role != .viewer else {
            throw KajimiruError.unauthorized
        }

        if let title = update.title {
            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw KajimiruError.validationFailed(reason: "Title must not be empty.")
            }
            chore.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let category = update.category {
            chore.category = category
        }
        if let defaultAssigneeId = update.defaultAssigneeId {
            chore.defaultAssigneeId = defaultAssigneeId
        }
        if let estimatedMinutes = update.estimatedMinutes {
            if let minutes = estimatedMinutes {
                guard minutes > 0 else {
                    throw KajimiruError.validationFailed(reason: "Estimated minutes must be positive when provided.")
                }
            }
            chore.estimatedMinutes = estimatedMinutes
        }
        if let notes = update.notes {
            chore.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let frequency = update.frequency {
            chore.frequency = frequency
        }
        chore = chore.updating()
        try await choreRepository.save(chore)
        return chore
    }

    /// Deletes the chore if the actor has the required role.
    public func deleteChore(id: UUID, groupId: UUID, actorId: UUID) async throws {
        guard let group = try await groupRepository.fetchGroup(id: groupId),
              let role = group.role(of: actorId), role != .viewer else {
            throw KajimiruError.unauthorized
        }
        try await choreRepository.deleteChore(id: id, in: groupId)
    }

    private func validate(draft: ChoreDraft) throws {
        guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw KajimiruError.validationFailed(reason: "Title must not be empty.")
        }
        if let estimatedMinutes = draft.estimatedMinutes, estimatedMinutes <= 0 {
            throw KajimiruError.validationFailed(reason: "Estimated minutes must be positive when provided.")
        }
    }
}

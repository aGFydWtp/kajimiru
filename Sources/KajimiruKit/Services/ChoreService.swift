import Foundation

/// Input model used when creating a new chore from user supplied data.
public struct ChoreDraft: Sendable {
    public var groupId: UUID
    public var title: String
    public var weight: Int
    public var notes: String?

    public init(
        groupId: UUID,
        title: String,
        weight: Int = Chore.defaultWeight,
        notes: String? = nil
    ) {
        self.groupId = groupId
        self.title = title
        self.weight = weight
        self.notes = notes
    }
}

/// Patch model describing updates applied to an existing chore.
public struct ChoreUpdate: Sendable {
    public var title: String?
    public var weight: Int?
    public var notes: String??

    public init(title: String? = nil, weight: Int? = nil, notes: String?? = nil) {
        self.title = title
        self.weight = weight
        self.notes = notes
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
            weight: draft.weight,
            notes: draft.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
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
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else {
                throw KajimiruError.validationFailed(reason: "Title must not be empty.")
            }
            chore.title = trimmed
        }
        if let weight = update.weight {
            guard Chore.isValidWeight(weight) else {
                throw KajimiruError.validationFailed(reason: "Weight must be one of \(Chore.allowedWeights.sorted()).")
            }
            chore.weight = weight
        }
        if let notes = update.notes {
            chore.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
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
        guard Chore.isValidWeight(draft.weight) else {
            throw KajimiruError.validationFailed(reason: "Weight must be one of \(Chore.allowedWeights.sorted()).")
        }
    }
}

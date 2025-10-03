import Foundation

/// Input model used when creating a new chore from user supplied data.
public struct ChoreDraft: Sendable {
    public var groupId: UUID
    public var title: String
    public var weight: Int
    public var isFavorite: Bool
    public var notes: String?

    public init(
        groupId: UUID,
        title: String,
        weight: Int = Chore.defaultWeight,
        isFavorite: Bool = false,
        notes: String? = nil
    ) {
        self.groupId = groupId
        self.title = title
        self.weight = weight
        self.isFavorite = isFavorite
        self.notes = notes
    }
}

/// Patch model describing updates applied to an existing chore.
public struct ChoreUpdate: Sendable {
    public var title: String?
    public var weight: Int?
    public var notes: String??
    public var isFavorite: Bool?

    public init(title: String? = nil, weight: Int? = nil, notes: String?? = nil, isFavorite: Bool? = nil) {
        self.title = title
        self.weight = weight
        self.notes = notes
        self.isFavorite = isFavorite
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

    /// Creates a new chore.
    public func createChore(draft: ChoreDraft, createdBy: UUID) async throws -> Chore {
        try validate(draft: draft)
        guard try await groupRepository.fetchGroup(id: draft.groupId) != nil else {
            throw KajimiruError.notFound
        }

        let chore = Chore(
            groupId: draft.groupId,
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            weight: draft.weight,
            notes: draft.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
            isFavorite: draft.isFavorite,
            createdBy: createdBy,
            updatedBy: createdBy
        )
        try await choreRepository.save(chore)
        return chore
    }

    /// Applies updates to an existing chore and persists the result.
    public func updateChore(id: UUID, update: ChoreUpdate, updatedBy: UUID) async throws -> Chore {
        guard var chore = try await choreRepository.fetchChore(id: id) else {
            throw KajimiruError.notFound
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
        if let isFavorite = update.isFavorite {
            chore.isFavorite = isFavorite
        }
        chore = chore.updating(updatedBy: updatedBy)
        try await choreRepository.save(chore)
        return chore
    }

    /// Soft deletes the chore.
    public func deleteChore(id: UUID, deletedBy: UUID) async throws {
        guard var chore = try await choreRepository.fetchChore(id: id) else {
            throw KajimiruError.notFound
        }

        chore.deletedAt = Date()
        chore.deletedBy = deletedBy
        chore.updatedAt = Date()
        chore.updatedBy = deletedBy

        try await choreRepository.save(chore)
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

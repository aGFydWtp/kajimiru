import Foundation

/// Represents a completed chore record that can be aggregated for analytics while preserving the recorded weight.
public struct ChoreLog: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var choreId: UUID
    public var groupId: UUID
    public var performerId: UUID
    public let weight: Double
    public var memo: String?
    public var batchId: UUID
    public var performerCount: Int
    public var createdAt: Date
    public var createdBy: UUID
    public var updatedAt: Date
    public var updatedBy: UUID

    public init(
        id: UUID = UUID(),
        choreId: UUID,
        groupId: UUID,
        performerId: UUID,
        weight: Double,
        memo: String? = nil,
        batchId: UUID = UUID(),
        performerCount: Int = 1,
        createdAt: Date = Date(),
        createdBy: UUID,
        updatedAt: Date = Date(),
        updatedBy: UUID
    ) {
        precondition(weight > 0, "Weight must be positive")
        precondition(performerCount > 0, "Performer count must be positive")
        self.id = id
        self.choreId = choreId
        self.groupId = groupId
        self.performerId = performerId
        self.weight = weight
        self.memo = memo
        self.batchId = batchId
        self.performerCount = performerCount
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.updatedAt = updatedAt
        self.updatedBy = updatedBy
    }

    public func updating(
        performerId: UUID? = nil,
        memo: String?? = nil,
        updatedBy: UUID
    ) -> ChoreLog {
        var copy = self
        if let performerId {
            copy.performerId = performerId
        }
        if let memo {
            copy.memo = memo
        }
        copy.updatedBy = updatedBy
        copy.updatedAt = Date()
        return copy
    }
}

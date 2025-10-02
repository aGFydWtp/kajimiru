import Foundation

/// Represents a completed chore record that can be aggregated for analytics while preserving the recorded weight.
public struct ChoreLog: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var choreId: UUID
    public var groupId: UUID
    public var performerId: UUID
    public let weight: Int
    public var memo: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        choreId: UUID,
        groupId: UUID,
        performerId: UUID,
        weight: Int,
        memo: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        precondition(Chore.isValidWeight(weight), "Invalid chore weight")
        self.id = id
        self.choreId = choreId
        self.groupId = groupId
        self.performerId = performerId
        self.weight = weight
        self.memo = memo
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func updating(
        performerId: UUID? = nil,
        memo: String?? = nil
    ) -> ChoreLog {
        var copy = self
        if let performerId {
            copy.performerId = performerId
        }
        if let memo {
            copy.memo = memo
        }
        copy.updatedAt = Date()
        return copy
    }
}

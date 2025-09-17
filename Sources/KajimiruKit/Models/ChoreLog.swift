import Foundation

/// Represents a completed chore record that can be aggregated for analytics.
public struct ChoreLog: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var choreId: UUID
    public var groupId: UUID
    public var performerId: UUID
    public var startedAt: Date
    public var durationMinutes: Int?
    public var memo: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        choreId: UUID,
        groupId: UUID,
        performerId: UUID,
        startedAt: Date,
        durationMinutes: Int? = nil,
        memo: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.choreId = choreId
        self.groupId = groupId
        self.performerId = performerId
        self.startedAt = startedAt
        self.durationMinutes = durationMinutes
        self.memo = memo
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func updating(
        startedAt: Date? = nil,
        durationMinutes: Int?? = nil,
        memo: String?? = nil
    ) -> ChoreLog {
        var copy = self
        if let startedAt { copy.startedAt = startedAt }
        if let durationMinutes { copy.durationMinutes = durationMinutes }
        if let memo { copy.memo = memo }
        copy.updatedAt = Date()
        return copy
    }
}

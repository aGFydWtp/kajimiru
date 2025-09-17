import Foundation

/// Represents a semantic category used to group chores when analysing workloads.
public struct ChoreCategory: Hashable, Codable, Sendable, RawRepresentable {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let cleaning = ChoreCategory(rawValue: "cleaning")
    public static let laundry = ChoreCategory(rawValue: "laundry")
    public static let cooking = ChoreCategory(rawValue: "cooking")
    public static let shopping = ChoreCategory(rawValue: "shopping")
    public static let maintenance = ChoreCategory(rawValue: "maintenance")
    public static let other = ChoreCategory(rawValue: "other")
}

/// Frequency metadata describing how often a chore is expected to occur.
public enum ChoreFrequency: Codable, Hashable, Sendable {
    case onDemand
    case recurring(RecurrenceRule)
    case custom(description: String)
}

/// Simplified recurrence rule that supports day-based scheduling used for reminders.
public struct RecurrenceRule: Codable, Hashable, Sendable {
    public enum Period: String, Codable, Sendable {
        case daily
        case weekly
        case monthly
    }

    public var period: Period
    public var interval: Int
    public var weekdays: Set<Int> // 1 = Sunday ... 7 = Saturday following Foundation's Calendar component

    public init(period: Period, interval: Int = 1, weekdays: Set<Int> = []) {
        self.period = period
        self.interval = max(interval, 1)
        self.weekdays = weekdays
    }
}

/// Definition of a chore shared within a group.
public struct Chore: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var groupId: UUID
    public var title: String
    public var category: ChoreCategory
    public var defaultAssigneeId: UUID?
    public var estimatedMinutes: Int?
    public var notes: String?
    public var frequency: ChoreFrequency
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        groupId: UUID,
        title: String,
        category: ChoreCategory,
        defaultAssigneeId: UUID? = nil,
        estimatedMinutes: Int? = nil,
        notes: String? = nil,
        frequency: ChoreFrequency = .onDemand,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.groupId = groupId
        self.title = title
        self.category = category
        self.defaultAssigneeId = defaultAssigneeId
        self.estimatedMinutes = estimatedMinutes
        self.notes = notes
        self.frequency = frequency
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func updating(
        title: String? = nil,
        category: ChoreCategory? = nil,
        defaultAssigneeId: UUID?? = nil,
        estimatedMinutes: Int?? = nil,
        notes: String?? = nil,
        frequency: ChoreFrequency? = nil
    ) -> Chore {
        var copy = self
        if let title { copy.title = title }
        if let category { copy.category = category }
        if let defaultAssigneeId { copy.defaultAssigneeId = defaultAssigneeId }
        if let estimatedMinutes { copy.estimatedMinutes = estimatedMinutes }
        if let notes { copy.notes = notes }
        if let frequency { copy.frequency = frequency }
        copy.updatedAt = Date()
        return copy
    }
}

extension ChoreFrequency {
    private enum CodingKeys: String, CodingKey {
        case type
        case recurrence
        case description
    }

    private enum FrequencyType: String, Codable {
        case onDemand
        case recurring
        case custom
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(FrequencyType.self, forKey: .type)
        switch type {
        case .onDemand:
            self = .onDemand
        case .recurring:
            let rule = try container.decode(RecurrenceRule.self, forKey: .recurrence)
            self = .recurring(rule)
        case .custom:
            let description = try container.decode(String.self, forKey: .description)
            self = .custom(description: description)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .onDemand:
            try container.encode(FrequencyType.onDemand, forKey: .type)
        case let .recurring(rule):
            try container.encode(FrequencyType.recurring, forKey: .type)
            try container.encode(rule, forKey: .recurrence)
        case let .custom(description):
            try container.encode(FrequencyType.custom, forKey: .type)
            try container.encode(description, forKey: .description)
        }
    }
}

import Foundation

/// Defines how a reminder should notify users about upcoming or overdue chores.
public enum ReminderNotificationType: String, Codable, Sendable {
    case push
    case inApp
    case email
}

/// Represents a schedule for a reminder. For MVP we support weekday + time combinations.
public struct ReminderSchedule: Codable, Hashable, Sendable {
    public var weekdays: Set<Int> // 1 = Sunday ... 7 = Saturday
    public var time: DateComponents

    public init(weekdays: Set<Int>, time: DateComponents) {
        self.weekdays = weekdays
        self.time = time
    }
}

/// Reminder configuration linked to a chore.
public struct Reminder: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var choreId: UUID
    public var groupId: UUID
    public var schedule: ReminderSchedule
    public var notificationType: ReminderNotificationType
    public var isEnabled: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        choreId: UUID,
        groupId: UUID,
        schedule: ReminderSchedule,
        notificationType: ReminderNotificationType = .push,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.choreId = choreId
        self.groupId = groupId
        self.schedule = schedule
        self.notificationType = notificationType
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

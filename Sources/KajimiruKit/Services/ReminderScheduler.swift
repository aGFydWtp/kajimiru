import Foundation

/// Utility responsible for calculating upcoming reminder fire dates to integrate with notification backends.
public final class ReminderScheduler: Sendable {
    private let reminderRepository: ReminderRepository
    private let calendar: Calendar

    public init(reminderRepository: ReminderRepository, calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.reminderRepository = reminderRepository
        self.calendar = calendar
    }

    /// Calculates the next fire date for a given reminder relative to the supplied reference date.
    public func nextFireDate(for reminder: Reminder, from referenceDate: Date = Date()) -> Date? {
        guard reminder.isEnabled else { return nil }
        let weekdays = reminder.schedule.weekdays.isEmpty ? Set(1...7) : reminder.schedule.weekdays
        let components = reminder.schedule.time

        for dayOffset in 0..<14 { // search within two weeks which covers weekly schedules
            guard let candidateDay = calendar.date(byAdding: .day, value: dayOffset, to: referenceDate) else { continue }
            let weekday = calendar.component(.weekday, from: candidateDay)
            guard weekdays.contains(weekday) else { continue }
            var targetComponents = calendar.dateComponents([.year, .month, .day], from: candidateDay)
            targetComponents.hour = components.hour
            targetComponents.minute = components.minute
            targetComponents.second = components.second ?? 0

            guard let targetDate = calendar.date(from: targetComponents) else { continue }
            if targetDate >= referenceDate { return targetDate }
        }
        return nil
    }

    /// Returns the next upcoming reminder instances for a specific chore.
    public func upcomingReminders(for choreId: UUID, limit: Int = 5, referenceDate: Date = Date()) async throws -> [Date] {
        guard limit > 0 else { return [] }
        let reminders = try await reminderRepository.listReminders(choreId: choreId)
        var occurrences: [Date] = []

        for reminder in reminders {
            var reference = referenceDate
            for _ in 0..<limit {
                guard let next = nextFireDate(for: reminder, from: reference) else { break }
                occurrences.append(next)
                reference = next.addingTimeInterval(1)
            }
        }

        occurrences.sort()
        return Array(occurrences.prefix(limit))
    }
}

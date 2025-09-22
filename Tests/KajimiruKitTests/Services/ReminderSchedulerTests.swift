import XCTest
@testable import KajimiruKit

final class ReminderSchedulerTests: XCTestCase {
    func testNextFireDateRespectsWeekdays() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let reminderRepository = InMemoryReminderRepository()
        let scheduler = ReminderScheduler(reminderRepository: reminderRepository, calendar: calendar)

        let schedule = ReminderSchedule(
            weekdays: [2, 4], // Monday & Wednesday in Gregorian calendar where 1 = Sunday
            time: DateComponents(hour: 9, minute: 0)
        )
        let reminder = Reminder(choreId: UUID(), groupId: UUID(), schedule: schedule)

        let reference = calendar.date(from: DateComponents(year: 2024, month: 5, day: 20, hour: 8, minute: 0))! // Monday
        let fireDate = scheduler.nextFireDate(for: reminder, from: reference)
        let expected = calendar.date(from: DateComponents(year: 2024, month: 5, day: 20, hour: 9, minute: 0))
        XCTAssertEqual(fireDate, expected)

        let disabledReminder = Reminder(
            choreId: reminder.choreId,
            groupId: reminder.groupId,
            schedule: schedule,
            isEnabled: false
        )
        XCTAssertNil(scheduler.nextFireDate(for: disabledReminder, from: reference))
    }

    func testUpcomingReminderQueriesRepository() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let choreId = UUID()
        let groupId = UUID()

        let schedule = ReminderSchedule(weekdays: [3], time: DateComponents(hour: 18, minute: 30))
        let reminder = Reminder(choreId: choreId, groupId: groupId, schedule: schedule)

        let reminderRepository = InMemoryReminderRepository(reminders: [reminder])
        let scheduler = ReminderScheduler(reminderRepository: reminderRepository, calendar: calendar)
        let reference = calendar.date(from: DateComponents(year: 2024, month: 5, day: 20, hour: 8, minute: 0))!

        let upcoming = try await scheduler.upcomingReminders(for: choreId, limit: 2, referenceDate: reference)
        XCTAssertEqual(upcoming.count, 2)
        XCTAssertTrue(upcoming[0] < upcoming[1])
    }
}

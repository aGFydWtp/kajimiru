import XCTest
@testable import KajimiruKit

final class ChoreAnalyticsServiceTests: XCTestCase {
    func testWeeklySnapshotsCalculateContributions() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let anchorDate = calendar.date(from: DateComponents(year: 2024, month: 5, day: 19))!

        let userA = UUID()
        let userB = UUID()
        let groupId = UUID()

        let chores: [Chore] = [
            Chore(id: UUID(), groupId: groupId, title: "Dishes", category: .cooking, estimatedMinutes: 30),
            Chore(id: UUID(), groupId: groupId, title: "Vacuum", category: .cleaning, estimatedMinutes: 40)
        ]

        let logs: [ChoreLog] = [
            ChoreLog(
                choreId: chores[0].id,
                groupId: groupId,
                performerId: userA,
                startedAt: calendar.date(byAdding: .day, value: -1, to: anchorDate)!,
                durationMinutes: nil
            ),
            ChoreLog(
                choreId: chores[1].id,
                groupId: groupId,
                performerId: userB,
                startedAt: calendar.date(byAdding: .day, value: -2, to: anchorDate)!,
                durationMinutes: 60
            )
        ]

        let service = ChoreAnalyticsService(calendar: calendar)
        let snapshots = service.weeklySnapshots(logs: logs, chores: chores, endingOn: anchorDate, weekCount: 1)

        XCTAssertEqual(snapshots.count, 1)
        let snapshot = try XCTUnwrap(snapshots.first)
        XCTAssertEqual(snapshot.totalCount, 2)
        XCTAssertEqual(snapshot.totalDurationMinutes, 90)

        let contributionA = try XCTUnwrap(snapshot.contributions.first { $0.userId == userA })
        XCTAssertEqual(contributionA.totalDurationMinutes, 30)
        XCTAssertEqual(contributionA.completedCount, 1)
        XCTAssertEqual(contributionA.shareOfTotalDuration(snapshot.totalDurationMinutes), 30.0 / 90.0)

        let contributionB = try XCTUnwrap(snapshot.contributions.first { $0.userId == userB })
        XCTAssertEqual(contributionB.totalDurationMinutes, 60)
        XCTAssertEqual(contributionB.categoryDurations[.cleaning], 60)
        XCTAssertEqual(contributionB.shareOfTotalCount(snapshot.totalCount), 0.5)
    }

    func testMonthlySnapshotsSortedChronologically() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let anchorDate = calendar.date(from: DateComponents(year: 2024, month: 6, day: 1))!
        let groupId = UUID()
        let user = UUID()
        let chore = Chore(id: UUID(), groupId: groupId, title: "Trash", category: .cleaning, estimatedMinutes: 10)

        let log = ChoreLog(
            choreId: chore.id,
            groupId: groupId,
            performerId: user,
            startedAt: calendar.date(from: DateComponents(year: 2024, month: 5, day: 10))!,
            durationMinutes: nil
        )

        let service = ChoreAnalyticsService(calendar: calendar)
        let snapshots = service.monthlySnapshots(logs: [log], chores: [chore], endingOn: anchorDate, monthCount: 2)

        XCTAssertEqual(snapshots.count, 2)
        XCTAssertTrue(snapshots[0].interval.start < snapshots[1].interval.start)
        XCTAssertEqual(snapshots[0].totalCount + snapshots[1].totalCount, 1)
    }
}

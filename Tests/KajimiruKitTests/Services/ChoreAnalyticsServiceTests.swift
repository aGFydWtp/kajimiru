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

        let logs: [ChoreLog] = [
            ChoreLog(
                choreId: UUID(),
                groupId: groupId,
                performerId: userA,
                weight: 3,
                createdAt: calendar.date(byAdding: .day, value: -1, to: anchorDate)!
            ),
            ChoreLog(
                choreId: UUID(),
                groupId: groupId,
                performerId: userB,
                weight: 5,
                createdAt: calendar.date(byAdding: .day, value: -2, to: anchorDate)!
            )
        ]

        let service = ChoreAnalyticsService(calendar: calendar)
        let snapshots = service.weeklySnapshots(logs: logs, endingOn: anchorDate, weekCount: 1)

        XCTAssertEqual(snapshots.count, 1)
        let snapshot = try XCTUnwrap(snapshots.first)
        XCTAssertEqual(snapshot.totalCount, 2)
        XCTAssertEqual(snapshot.totalWeight, 8)

        let contributionA = try XCTUnwrap(snapshot.contributions.first { $0.userId == userA })
        XCTAssertEqual(contributionA.completedCount, 1)
        XCTAssertEqual(contributionA.totalWeight, 3)
        XCTAssertEqual(contributionA.shareOfTotalWeight(snapshot.totalWeight), 3.0 / 8.0, accuracy: 0.001)

        let contributionB = try XCTUnwrap(snapshot.contributions.first { $0.userId == userB })
        XCTAssertEqual(contributionB.totalWeight, 5)
        XCTAssertEqual(contributionB.shareOfTotalCount(snapshot.totalCount), 0.5)
    }

    func testMonthlySnapshotsSortedChronologically() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let anchorDate = calendar.date(from: DateComponents(year: 2024, month: 6, day: 1))!
        let groupId = UUID()
        let user = UUID()
        let log = ChoreLog(
            choreId: UUID(),
            groupId: groupId,
            performerId: user,
            weight: 2,
            createdAt: calendar.date(from: DateComponents(year: 2024, month: 5, day: 10))!
        )

        let service = ChoreAnalyticsService(calendar: calendar)
        let snapshots = service.monthlySnapshots(logs: [log], endingOn: anchorDate, monthCount: 2)

        XCTAssertEqual(snapshots.count, 2)
        XCTAssertTrue(snapshots[0].interval.start < snapshots[1].interval.start)
        XCTAssertEqual(snapshots[0].totalCount + snapshots[1].totalCount, 1)
    }
}

import Foundation

/// Summary metrics for an individual contributor within a time window.
public struct ContributorSummary: Hashable, Sendable {
    public let userId: UUID
    public let completedCount: Int
    public let totalWeight: Int

    public init(userId: UUID, completedCount: Int, totalWeight: Int) {
        self.userId = userId
        self.completedCount = completedCount
        self.totalWeight = totalWeight
    }

    public func shareOfTotalCount(_ totalCount: Int) -> Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    public func shareOfTotalWeight(_ totalWeight: Int) -> Double {
        guard totalWeight > 0 else { return 0 }
        return Double(self.totalWeight) / Double(totalWeight)
    }
}

/// Aggregate of contributions for a specific analysis period (week/month).
public struct WorkloadSnapshot: Hashable, Sendable {
    public let interval: DateInterval
    public let contributions: [ContributorSummary]
    public let totalCount: Int
    public let totalWeight: Int

    public init(interval: DateInterval, contributions: [ContributorSummary]) {
        self.interval = interval
        self.contributions = contributions.sorted { $0.totalWeight > $1.totalWeight }
        self.totalCount = contributions.reduce(0) { $0 + $1.completedCount }
        self.totalWeight = contributions.reduce(0) { $0 + $1.totalWeight }
    }
}

/// Provides analytics used by the dashboard to visualise workload balance.
public final class ChoreAnalyticsService: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.calendar = calendar
    }

    /// Generates weekly snapshots for the current week (Monday start) and previous weeks.
    /// The current week is defined as Monday 00:00 to Sunday 23:59:59.
    public func weeklySnapshots(
        logs: [ChoreLog],
        endingOn anchorDate: Date,
        weekCount: Int
    ) -> [WorkloadSnapshot] {
        var modifiedCalendar = calendar
        modifiedCalendar.firstWeekday = 2 // Monday = 2 (Sunday = 1)

        let normalizedAnchor = modifiedCalendar.startOfDay(for: anchorDate)
        var snapshots: [WorkloadSnapshot] = []

        for offset in 0..<weekCount {
            // Calculate the Monday of the week we're interested in
            guard let targetDate = modifiedCalendar.date(byAdding: .weekOfYear, value: -offset, to: normalizedAnchor) else {
                continue
            }

            // Get the start of the week (Monday 00:00)
            guard let weekStart = modifiedCalendar.dateInterval(of: .weekOfYear, for: targetDate)?.start else {
                continue
            }

            // Get the end of the week (Sunday 23:59:59)
            guard let weekEnd = modifiedCalendar.date(byAdding: .day, value: 7, to: weekStart) else {
                continue
            }

            let interval = DateInterval(start: weekStart, end: weekEnd)
            let filteredLogs = logs.filter { interval.contains($0.createdAt) }
            let contributions = Self.contributions(for: filteredLogs)
            snapshots.append(WorkloadSnapshot(interval: interval, contributions: contributions))
        }
        return snapshots.sorted { $0.interval.start < $1.interval.start }
    }

    /// Generates monthly snapshots for the current month and previous months.
    /// The current month is defined as the 1st day 00:00 to the last day 23:59:59 of the month.
    public func monthlySnapshots(
        logs: [ChoreLog],
        endingOn anchorDate: Date,
        monthCount: Int
    ) -> [WorkloadSnapshot] {
        let normalizedAnchor = calendar.startOfDay(for: anchorDate)
        var snapshots: [WorkloadSnapshot] = []

        for offset in 0..<monthCount {
            // Calculate the date in the target month
            guard let targetDate = calendar.date(byAdding: .month, value: -offset, to: normalizedAnchor) else {
                continue
            }

            // Get the start of the month (1st day 00:00)
            guard let monthStart = calendar.dateInterval(of: .month, for: targetDate)?.start else {
                continue
            }

            // Get the end of the month (last day 23:59:59)
            guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                continue
            }

            let interval = DateInterval(start: monthStart, end: monthEnd)
            let filteredLogs = logs.filter { interval.contains($0.createdAt) }
            let contributions = Self.contributions(for: filteredLogs)
            snapshots.append(WorkloadSnapshot(interval: interval, contributions: contributions))
        }
        return snapshots.sorted { $0.interval.start < $1.interval.start }
    }

    /// Aggregates logs by assignee and recorded chore weight.
    private static func contributions(for logs: [ChoreLog]) -> [ContributorSummary] {
        var counts: [UUID: Int] = [:]
        var totalWeights: [UUID: Double] = [:]

        for log in logs {
            counts[log.performerId, default: 0] += 1
            totalWeights[log.performerId, default: 0] += log.weight
        }

        return counts.map { userId, count in
            ContributorSummary(
                userId: userId,
                completedCount: count,
                totalWeight: Int(totalWeights[userId, default: 0].rounded())
            )
        }
    }
}

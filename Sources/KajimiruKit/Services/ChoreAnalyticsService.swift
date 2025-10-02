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

    /// Generates weekly snapshots ending at the provided anchor date.
    public func weeklySnapshots(
        logs: [ChoreLog],
        endingOn anchorDate: Date,
        weekCount: Int
    ) -> [WorkloadSnapshot] {
        let normalizedAnchor = calendar.startOfDay(for: anchorDate)
        var snapshots: [WorkloadSnapshot] = []

        for offset in 0..<weekCount {
            guard let weekEnd = calendar.date(byAdding: .day, value: -7 * offset, to: normalizedAnchor)?.addingTimeInterval(60 * 60 * 24) else {
                continue
            }
            guard let weekStart = calendar.date(byAdding: .day, value: -7, to: weekEnd) else { continue }
            let interval = DateInterval(start: weekStart, end: weekEnd)
            let filteredLogs = logs.filter { interval.contains($0.createdAt) }
            let contributions = Self.contributions(for: filteredLogs)
            snapshots.append(WorkloadSnapshot(interval: interval, contributions: contributions))
        }
        return snapshots.sorted { $0.interval.start < $1.interval.start }
    }

    /// Generates monthly snapshots covering the specified number of months ending at the anchor.
    public func monthlySnapshots(
        logs: [ChoreLog],
        endingOn anchorDate: Date,
        monthCount: Int
    ) -> [WorkloadSnapshot] {
        let normalizedAnchor = calendar.startOfDay(for: anchorDate)
        var snapshots: [WorkloadSnapshot] = []

        for offset in 0..<monthCount {
            guard let monthEnd = calendar.date(byAdding: .month, value: -offset, to: normalizedAnchor)?.addingTimeInterval(60 * 60 * 24) else {
                continue
            }
            guard let monthStart = calendar.date(byAdding: .month, value: -1, to: monthEnd) else { continue }
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
        var totalWeights: [UUID: Int] = [:]

        for log in logs {
            counts[log.performerId, default: 0] += 1
            totalWeights[log.performerId, default: 0] += log.weight
        }

        return counts.map { userId, count in
            ContributorSummary(
                userId: userId,
                completedCount: count,
                totalWeight: totalWeights[userId, default: 0]
            )
        }
    }
}

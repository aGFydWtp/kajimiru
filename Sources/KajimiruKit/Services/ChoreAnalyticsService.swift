import Foundation

/// Summary metrics for an individual contributor within a time window.
public struct ContributorSummary: Hashable, Sendable {
    public let userId: UUID
    public let completedCount: Int
    public let totalDurationMinutes: Int
    public let categoryCounts: [ChoreCategory: Int]
    public let categoryDurations: [ChoreCategory: Int]

    public init(
        userId: UUID,
        completedCount: Int,
        totalDurationMinutes: Int,
        categoryCounts: [ChoreCategory: Int],
        categoryDurations: [ChoreCategory: Int]
    ) {
        self.userId = userId
        self.completedCount = completedCount
        self.totalDurationMinutes = totalDurationMinutes
        self.categoryCounts = categoryCounts
        self.categoryDurations = categoryDurations
    }

    public func shareOfTotalCount(_ totalCount: Int) -> Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    public func shareOfTotalDuration(_ totalDuration: Int) -> Double {
        guard totalDuration > 0 else { return 0 }
        return Double(totalDurationMinutes) / Double(totalDuration)
    }
}

/// Aggregate of contributions for a specific analysis period (week/month).
public struct WorkloadSnapshot: Hashable, Sendable {
    public let interval: DateInterval
    public let contributions: [ContributorSummary]
    public let totalCount: Int
    public let totalDurationMinutes: Int

    public init(interval: DateInterval, contributions: [ContributorSummary]) {
        self.interval = interval
        self.contributions = contributions.sorted { $0.totalDurationMinutes > $1.totalDurationMinutes }
        self.totalCount = contributions.reduce(0) { $0 + $1.completedCount }
        self.totalDurationMinutes = contributions.reduce(0) { $0 + $1.totalDurationMinutes }
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
        chores: [Chore],
        endingOn anchorDate: Date,
        weekCount: Int
    ) -> [WorkloadSnapshot] {
        let normalizedAnchor = calendar.startOfDay(for: anchorDate)
        var snapshots: [WorkloadSnapshot] = []
        let choresById = Dictionary(uniqueKeysWithValues: chores.map { ($0.id, $0) })

        for offset in 0..<weekCount {
            guard let weekEnd = calendar.date(byAdding: .day, value: -7 * offset, to: normalizedAnchor)?.addingTimeInterval(60 * 60 * 24) else {
                continue
            }
            guard let weekStart = calendar.date(byAdding: .day, value: -7, to: weekEnd) else { continue }
            let interval = DateInterval(start: weekStart, end: weekEnd)
            let filteredLogs = logs.filter { interval.contains($0.startedAt) }
            let contributions = Self.contributions(for: filteredLogs, chores: choresById)
            snapshots.append(WorkloadSnapshot(interval: interval, contributions: contributions))
        }
        return snapshots.sorted { $0.interval.start < $1.interval.start }
    }

    /// Generates monthly snapshots covering the specified number of months ending at the anchor.
    public func monthlySnapshots(
        logs: [ChoreLog],
        chores: [Chore],
        endingOn anchorDate: Date,
        monthCount: Int
    ) -> [WorkloadSnapshot] {
        let normalizedAnchor = calendar.startOfDay(for: anchorDate)
        var snapshots: [WorkloadSnapshot] = []
        let choresById = Dictionary(uniqueKeysWithValues: chores.map { ($0.id, $0) })

        for offset in 0..<monthCount {
            guard let monthEnd = calendar.date(byAdding: .month, value: -offset, to: normalizedAnchor)?.addingTimeInterval(60 * 60 * 24) else {
                continue
            }
            guard let monthStart = calendar.date(byAdding: .month, value: -1, to: monthEnd) else { continue }
            let interval = DateInterval(start: monthStart, end: monthEnd)
            let filteredLogs = logs.filter { interval.contains($0.startedAt) }
            let contributions = Self.contributions(for: filteredLogs, chores: choresById)
            snapshots.append(WorkloadSnapshot(interval: interval, contributions: contributions))
        }
        return snapshots.sorted { $0.interval.start < $1.interval.start }
    }

    /// Aggregates logs by assignee and chore metadata.
    private static func contributions(for logs: [ChoreLog], chores: [UUID: Chore]) -> [ContributorSummary] {
        var counts: [UUID: Int] = [:]
        var durations: [UUID: Int] = [:]
        var categoryCounts: [UUID: [ChoreCategory: Int]] = [:]
        var categoryDurations: [UUID: [ChoreCategory: Int]] = [:]

        for log in logs {
            guard let chore = chores[log.choreId] else { continue }
            let duration = log.durationMinutes ?? chore.estimatedMinutes ?? 0
            counts[log.performerId, default: 0] += 1
            durations[log.performerId, default: 0] += max(duration, 0)
            categoryCounts[log.performerId, default: [:]][chore.category, default: 0] += 1
            categoryDurations[log.performerId, default: [:]][chore.category, default: 0] += max(duration, 0)
        }

        return counts.map { userId, count in
            let totalDuration = durations[userId, default: 0]
            let countsByCategory = categoryCounts[userId, default: [:]]
            let durationsByCategory = categoryDurations[userId, default: [:]]
            return ContributorSummary(
                userId: userId,
                completedCount: count,
                totalDurationMinutes: totalDuration,
                categoryCounts: countsByCategory,
                categoryDurations: durationsByCategory
            )
        }
    }
}

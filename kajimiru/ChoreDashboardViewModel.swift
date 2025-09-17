import Foundation
import KajimiruKit

@MainActor
final class ChoreDashboardViewModel: ObservableObject {
    @Published private(set) var group: Group?
    @Published private(set) var chores: [Chore] = []
    @Published private(set) var logs: [ChoreLog] = []
    @Published private(set) var weeklySnapshots: [WorkloadSnapshot] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let sampleUsers: [User]
    private let usersById: [UUID: User]
    private let groupRepository: InMemoryGroupRepository
    private let choreRepository: InMemoryChoreRepository
    private let logRepository: InMemoryChoreLogRepository
    private let groupService: GroupService
    private let choreService: ChoreService
    private let choreLogService: ChoreLogService
    private let analyticsService: ChoreAnalyticsService
    private let calendar: Calendar

    private enum SampleDataError: Error {
        case invalidDate
    }

    init(calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.calendar = calendar
        self.sampleUsers = ChoreDashboardViewModel.defaultUsers()
        self.usersById = Dictionary(uniqueKeysWithValues: sampleUsers.map { ($0.id, $0) })
        self.groupRepository = InMemoryGroupRepository()
        self.choreRepository = InMemoryChoreRepository()
        self.logRepository = InMemoryChoreLogRepository()
        self.groupService = GroupService(groupRepository: groupRepository)
        self.choreService = ChoreService(choreRepository: choreRepository, groupRepository: groupRepository)
        self.choreLogService = ChoreLogService(
            logRepository: logRepository,
            choreRepository: choreRepository,
            groupRepository: groupRepository
        )
        self.analyticsService = ChoreAnalyticsService(calendar: calendar)
    }

    var groupMembers: [User] {
        guard let group else { return [] }
        return group.members.compactMap { usersById[$0.userId] }
    }

    var latestWeeklySnapshot: WorkloadSnapshot? {
        weeklySnapshots.last
    }

    func userDisplayName(for id: UUID) -> String {
        usersById[id]?.displayName ?? "不明なメンバー"
    }

    func defaultAssigneeName(for chore: Chore) -> String? {
        guard let assigneeId = chore.defaultAssigneeId else { return nil }
        return usersById[assigneeId]?.displayName
    }

    func loadDemoData() async {
        guard isLoading == false else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let state = try await bootstrapSampleData()
            group = state.group
            chores = state.chores
            logs = state.logs
            weeklySnapshots = state.weekly
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func bootstrapSampleData() async throws -> (
        group: Group,
        chores: [Chore],
        logs: [ChoreLog],
        weekly: [WorkloadSnapshot]
    ) {
        guard let owner = sampleUsers.first else {
            throw KajimiruError.validationFailed(reason: "Missing sample users")
        }

        let members = sampleUsers.dropFirst().map { user in
            GroupMemberInput(userId: user.id, role: .editor)
        }
        let groupDraft = GroupDraft(name: "江口家", icon: "house.fill", initialMembers: members)
        let group = try await groupService.createGroup(draft: groupDraft, ownerId: owner.id)

        let chores = try await createSampleChores(group: group, owner: owner)
        let logs = try await recordSampleLogs(group: group, owner: owner, chores: chores)
        let weekly = analyticsService.weeklySnapshots(
            logs: logs,
            chores: chores,
            endingOn: Date(),
            weekCount: 4
        )
        return (
            group: group,
            chores: chores.sorted { $0.title < $1.title },
            logs: logs,
            weekly: weekly
        )
    }

    private func createSampleChores(group: Group, owner: User) async throws -> [Chore] {
        let members = sampleUsers
        let kitchenReset = ChoreDraft(
            groupId: group.id,
            title: "ダイニングの片付け",
            category: .cleaning,
            defaultAssigneeId: members.dropFirst().first?.id,
            estimatedMinutes: 20,
            notes: "テーブル拭きと食洗機のセット",
            frequency: .recurring(RecurrenceRule(period: .weekly, interval: 1, weekdays: [2, 3, 4, 5, 6]))
        )
        let laundry = ChoreDraft(
            groupId: group.id,
            title: "週末の洗濯",
            category: .laundry,
            defaultAssigneeId: members.last?.id,
            estimatedMinutes: 45,
            notes: "シーツとタオルまで実施",
            frequency: .recurring(RecurrenceRule(period: .weekly, interval: 1, weekdays: [7]))
        )
        let shopping = ChoreDraft(
            groupId: group.id,
            title: "食材のまとめ買い",
            category: .shopping,
            defaultAssigneeId: owner.id,
            estimatedMinutes: 60,
            notes: "冷凍庫のストック確認も忘れずに",
            frequency: .recurring(RecurrenceRule(period: .weekly, interval: 1, weekdays: [1]))
        )
        let trash = ChoreDraft(
            groupId: group.id,
            title: "資源ゴミの準備",
            category: .maintenance,
            defaultAssigneeId: members.dropFirst().first?.id,
            estimatedMinutes: 15,
            notes: "段ボールをまとめて玄関へ",
            frequency: .custom(description: "第2・第4木曜日")
        )

        let created = try await [kitchenReset, laundry, shopping, trash].asyncCompactMap { draft in
            try await choreService.createChore(draft: draft, actorId: owner.id)
        }
        return created
    }

    private func recordSampleLogs(group: Group, owner: User, chores: [Chore]) async throws -> [ChoreLog] {
        let baseDate = calendar.startOfDay(for: Date())

        func makeDate(dayOffset: Int, hour: Int, minute: Int) throws -> Date {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: baseDate),
                  let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) else {
                throw SampleDataError.invalidDate
            }
            return date
        }

        let members = sampleUsers
        if let kitchen = chores.first(where: { $0.title == "ダイニングの片付け" }) {
            _ = try await choreLogService.recordChore(
                draft: ChoreLogDraft(
                    groupId: group.id,
                    choreId: kitchen.id,
                    performerId: members[1].id,
                    startedAt: try makeDate(dayOffset: -1, hour: 20, minute: 30),
                    durationMinutes: 18,
                    memo: "食洗機まで実施"
                ),
                actorId: owner.id
            )
            _ = try await choreLogService.recordChore(
                draft: ChoreLogDraft(
                    groupId: group.id,
                    choreId: kitchen.id,
                    performerId: members[2].id,
                    startedAt: try makeDate(dayOffset: -10, hour: 21, minute: 15),
                    durationMinutes: 20,
                    memo: "遅番の片付け"
                ),
                actorId: owner.id
            )
        }
        if let laundry = chores.first(where: { $0.title == "週末の洗濯" }) {
            _ = try await choreLogService.recordChore(
                draft: ChoreLogDraft(
                    groupId: group.id,
                    choreId: laundry.id,
                    performerId: owner.id,
                    startedAt: try makeDate(dayOffset: -8, hour: 9, minute: 0),
                    durationMinutes: 50,
                    memo: "シーツも交換"
                ),
                actorId: owner.id
            )
            _ = try await choreLogService.recordChore(
                draft: ChoreLogDraft(
                    groupId: group.id,
                    choreId: laundry.id,
                    performerId: members[2].id,
                    startedAt: try makeDate(dayOffset: -2, hour: 10, minute: 0),
                    durationMinutes: 45
                ),
                actorId: owner.id
            )
        }
        if let shopping = chores.first(where: { $0.title == "食材のまとめ買い" }) {
            _ = try await choreLogService.recordChore(
                draft: ChoreLogDraft(
                    groupId: group.id,
                    choreId: shopping.id,
                    performerId: owner.id,
                    startedAt: try makeDate(dayOffset: -5, hour: 18, minute: 0),
                    durationMinutes: 70,
                    memo: "冷凍食品を追加購入"
                ),
                actorId: owner.id
            )
        }
        if let trash = chores.first(where: { $0.title == "資源ゴミの準備" }) {
            _ = try await choreLogService.recordChore(
                draft: ChoreLogDraft(
                    groupId: group.id,
                    choreId: trash.id,
                    performerId: members[1].id,
                    startedAt: try makeDate(dayOffset: -4, hour: 7, minute: 30),
                    durationMinutes: 15
                ),
                actorId: owner.id
            )
        }

        let logs = try await choreLogService.fetchLogs(groupId: group.id, since: nil)
        return logs.sorted { $0.startedAt > $1.startedAt }
    }

    private static func defaultUsers() -> [User] {
        [
            User(displayName: "江口 晴希", email: "haruki@example.com"),
            User(displayName: "江口 美奈"),
            User(displayName: "江口 優斗")
        ]
    }
}

private extension Array where Element == ChoreDraft {
    func asyncCompactMap(_ transform: @escaping (ChoreDraft) async throws -> Chore) async rethrows -> [Chore] {
        var result: [Chore] = []
        for draft in self {
            let value = try await transform(draft)
            result.append(value)
        }
        return result
    }
}

#if DEBUG
extension ChoreDashboardViewModel {
    static func preview() -> ChoreDashboardViewModel {
        let model = ChoreDashboardViewModel()
        Task { @MainActor in
            await model.loadDemoData()
        }
        return model
    }
}
#endif

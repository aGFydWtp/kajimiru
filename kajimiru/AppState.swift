import Foundation
import KajimiruKit

/// Global app state for MVP (single-user, local data only)
@MainActor
class AppState: ObservableObject {
    @Published var group: Group?
    @Published var members: [Member] = []
    @Published var chores: [Chore] = []
    @Published var choreLogs: [ChoreLog] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    let currentUserId = MockDataHelper.userId

    // In-memory repositories
    private let groupRepo = InMemoryGroupRepository()
    private let memberRepo = InMemoryMemberRepository()
    private let choreRepo = InMemoryChoreRepository()
    private let choreLogRepo = InMemoryChoreLogRepository()

    // Services
    private lazy var groupService = GroupService(
        groupRepository: groupRepo,
        memberRepository: memberRepo
    )
    private lazy var choreService = ChoreService(
        choreRepository: choreRepo,
        groupRepository: groupRepo
    )
    private lazy var choreLogService = ChoreLogService(
        logRepository: choreLogRepo,
        choreRepository: choreRepo,
        groupRepository: groupRepo
    )
    private lazy var analyticsService = ChoreAnalyticsService()

    func loadMVPData() async {
        isLoading = true
        errorMessage = nil

        do {
            let mockData = MockDataHelper.createMVPData()

            // Save to repositories
            try await groupRepo.save(mockData.group)
            for member in mockData.members {
                try await memberRepo.save(member)
            }
            for chore in mockData.chores {
                try await choreRepo.save(chore)
            }
            for log in mockData.logs {
                try await choreLogRepo.save(log)
            }

            // Update published properties
            self.group = mockData.group
            self.members = mockData.members
            self.chores = mockData.chores
            self.choreLogs = mockData.logs

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func addChore(title: String, weight: Int, notes: String?) async throws {
        guard let group = group else { return }

        let draft = ChoreDraft(
            groupId: group.id,
            title: title,
            weight: weight,
            notes: notes
        )
        let chore = try await choreService.createChore(draft: draft, createdBy: currentUserId)
        chores.append(chore)
    }

    func recordChore(choreId: UUID, performerId: UUID, memo: String?) async throws {
        guard let group = group else { return }

        let draft = ChoreLogDraft(
            groupId: group.id,
            choreId: choreId,
            performerId: performerId,
            memo: memo
        )
        let log = try await choreLogService.recordChore(draft: draft, createdBy: currentUserId)
        choreLogs.append(log)
    }

    func getWeeklySnapshot() async throws -> WorkloadSnapshot? {
        guard group != nil else { return nil }

        let now = Date()
        let snapshots = analyticsService.weeklySnapshots(
            logs: choreLogs,
            endingOn: now,
            weekCount: 1
        )

        return snapshots.first
    }

    func memberDisplayName(for memberId: UUID) -> String {
        members.first { $0.id == memberId }?.displayName ?? "不明"
    }
}

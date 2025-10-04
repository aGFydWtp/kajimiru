import Foundation
import KajimiruKit

/// Global app state managing data persistence and business logic
@MainActor
class AppState: ObservableObject {
    @Published var currentUser: User?
    @Published var group: Group?
    @Published var members: [Member] = []
    @Published var chores: [Chore] = []
    @Published var choreLogs: [ChoreLog] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasCompletedSetup = false
    @Published var availableGroups: [Group] = []
    @Published var needsGroupSelection = false

    private weak var authService: AuthenticationService?

    // Repository selection based on environment
    private let useMockData: Bool

    var currentUserId: UUID {
        // Use authenticated user ID if available, otherwise use mock ID
        if let userID = authService?.userID, let uuid = UUID(uuidString: userID) {
            return uuid
        }
        return MockDataHelper.userId
    }

    var isAuthenticated: Bool {
        authService?.isAuthenticated ?? false
    }

    // MARK: - Initialization

    init(useMockData: Bool = false) {
        self.useMockData = useMockData
    }

    func setAuthService(_ service: AuthenticationService) {
        self.authService = service
    }

    // MARK: - Repositories

    private lazy var userRepo: any UserRepository = {
        if useMockData {
            return InMemoryUserRepository()
        } else {
            return FirestoreUserRepository()
        }
    }()

    private lazy var groupRepo: any GroupRepository = {
        if useMockData {
            return InMemoryGroupRepository()
        } else {
            return FirestoreGroupRepository()
        }
    }()

    private lazy var memberRepo: any MemberRepository = {
        if useMockData {
            return InMemoryMemberRepository()
        } else {
            return FirestoreMemberRepository()
        }
    }()

    private lazy var choreRepo: any ChoreRepository = {
        if useMockData {
            return InMemoryChoreRepository()
        } else {
            return FirestoreChoreRepository()
        }
    }()

    private lazy var choreLogRepo: any ChoreLogRepository = {
        if useMockData {
            return InMemoryChoreLogRepository()
        } else {
            return FirestoreChoreLogRepository()
        }
    }()

    // MARK: - Services

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

    // MARK: - User Setup and Status Check

    /// Check if the current user exists and has a group
    func checkUserStatus() async {
        guard let authUID = authService?.userID else {
            hasCompletedSetup = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // Try to fetch user from Firestore using Firebase UID
            if let firestoreUserRepo = userRepo as? FirestoreUserRepository,
               let firestoreMemberRepo = memberRepo as? FirestoreMemberRepository {
                let user = try await firestoreUserRepo.fetchUserByFirebaseUid(authUID)

                if let user = user {
                    currentUser = user

                    // Get all groups the user belongs to
                    let groupIds = try await firestoreMemberRepo.listGroupsForUser(firebaseUid: authUID)

                    if groupIds.isEmpty {
                        // No groups found - show initial setup
                        hasCompletedSetup = false
                        needsGroupSelection = false
                    } else if groupIds.count == 1 {
                        // Only one group - auto-select it
                        await loadUserGroup(groupId: groupIds[0])

                        // Update user's currentGroupId if needed
                        if user.currentGroupId != groupIds[0] {
                            var updatedUser = user
                            updatedUser.currentGroupId = groupIds[0]
                            try await userRepo.save(updatedUser)
                            currentUser = updatedUser
                        }

                        hasCompletedSetup = true
                        needsGroupSelection = false
                    } else {
                        // Multiple groups - show group selection
                        availableGroups = try await fetchGroups(ids: groupIds)

                        // If user has a currentGroupId and it's in the list, auto-load it
                        if let currentGroupId = user.currentGroupId, groupIds.contains(currentGroupId) {
                            await loadUserGroup(groupId: currentGroupId)
                            hasCompletedSetup = true
                            needsGroupSelection = false
                        } else {
                            needsGroupSelection = true
                            hasCompletedSetup = false
                        }
                    }
                } else {
                    // User doesn't exist in Firestore yet
                    hasCompletedSetup = false
                    needsGroupSelection = false
                }
            }
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            hasCompletedSetup = false
            needsGroupSelection = false
        }
    }

    /// Fetch multiple groups by IDs
    private func fetchGroups(ids: [UUID]) async throws -> [Group] {
        var groups: [Group] = []
        for id in ids {
            if let group = try await groupRepo.fetchGroup(id: id) {
                groups.append(group)
            }
        }
        return groups
    }

    /// Load user's group data
    private func loadUserGroup(groupId: UUID) async {
        do {
            group = try await groupRepo.fetchGroup(id: groupId)
            if let group = group {
                members = try await memberRepo.listMembers(in: group.id, includeDeleted: false)
                chores = try await choreRepo.listChores(in: group.id, includeDeleted: false)
                choreLogs = try await choreLogRepo.listLogs(in: group.id, since: nil)
            }
        } catch {
            print("❌ Error loading group: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// Select a group and load its data
    func selectGroup(_ group: Group) async {
        guard let user = currentUser else { return }

        isLoading = true

        do {
            // Update user's currentGroupId
            var updatedUser = user
            updatedUser.currentGroupId = group.id
            try await userRepo.save(updatedUser)
            currentUser = updatedUser

            // Load group data
            await loadUserGroup(groupId: group.id)

            // Update state
            needsGroupSelection = false
            hasCompletedSetup = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Create initial group for first-time user
    func createInitialGroup(groupName: String, yourName: String, memberNames: [String]) async throws {
        guard let authUID = authService?.userID,
              let userEmail = authService?.userEmail else {
            throw AppStateError.authenticationRequired
        }

        isLoading = true
        errorMessage = nil

        do {
            let userId = UUID()  // Generate new UUID for internal use

            // 1. Create User
            let user = User(
                id: userId,
                firebaseUid: authUID,  // Store Firebase UID
                displayName: yourName,
                email: userEmail,
                avatarURL: nil,
                currentGroupId: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            try await userRepo.save(user)

            // 2. Create Group
            let group = Group(
                name: groupName,
                icon: "house.fill",
                members: [],
                createdBy: userId,
                updatedBy: userId
            )
            try await groupRepo.save(group)

            // 3. Create self as admin member
            // Use Firebase UID as Member document ID for security rules
            let selfMember = Member(
                id: userId,
                userId: userId,
                firebaseUid: authUID,  // Store Firebase UID for Firestore document ID
                displayName: yourName,
                avatarURL: nil,
                groupId: group.id,
                role: .admin,
                createdBy: userId,
                updatedBy: userId
            )
            try await memberRepo.save(selfMember)

            // 4. Create additional members (optional)
            var allMembers = [selfMember]
            for memberName in memberNames where !memberName.isEmpty {
                let member = Member(
                    userId: nil,
                    displayName: memberName,
                    avatarURL: nil,
                    groupId: group.id,
                    role: .member,
                    createdBy: userId,
                    updatedBy: userId
                )
                try await memberRepo.save(member)
                allMembers.append(member)
            }

            // 5. Update user with group ID
            var updatedUser = user
            updatedUser.currentGroupId = group.id
            try await userRepo.save(updatedUser)

            // 6. Update local state
            self.currentUser = updatedUser
            self.group = group
            self.members = allMembers
            self.chores = []
            self.choreLogs = []
            self.hasCompletedSetup = true

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }


    func addChore(title: String, weight: Int, isFavorite: Bool = false, notes: String?) async throws {
        guard let group = group else { return }

        let draft = ChoreDraft(
            groupId: group.id,
            title: title,
            weight: weight,
            isFavorite: isFavorite,
            notes: notes
        )
        let chore = try await choreService.createChore(draft: draft, createdBy: currentUserId)
        chores.append(chore)
    }

    func updateChore(choreId: UUID, title: String, weight: Int, notes: String?, isFavorite: Bool) async throws {
        // Find chore in local state
        guard let index = chores.firstIndex(where: { $0.id == choreId }) else {
            throw AppStateError.choreNotFound
        }

        var chore = chores[index]
        chore.title = title
        chore.weight = weight
        chore.notes = notes
        chore.isFavorite = isFavorite
        chore = chore.updating(updatedBy: currentUserId)

        // Save to repository
        try await choreRepo.save(chore)

        // Update local state
        chores[index] = chore
    }

    func deleteChore(choreId: UUID) async {
        do {
            // Find chore in local state
            guard let index = chores.firstIndex(where: { $0.id == choreId }) else {
                throw AppStateError.choreNotFound
            }

            var chore = chores[index]
            chore.deletedAt = Date()
            chore.deletedBy = currentUserId
            chore.updatedAt = Date()
            chore.updatedBy = currentUserId

            // Save to repository
            try await choreRepo.save(chore)

            // Remove from local state
            chores.remove(at: index)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func recordChore(choreId: UUID, performerIds: [UUID], memo: String?) async throws {
        guard let group = group else { return }

        let draft = ChoreLogDraft(
            groupId: group.id,
            choreId: choreId,
            performerIds: performerIds,
            memo: memo
        )
        let logs = try await choreLogService.recordChore(draft: draft, createdBy: currentUserId)
        choreLogs.append(contentsOf: logs)
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

// MARK: - Errors

enum AppStateError: LocalizedError {
    case authenticationRequired
    case choreNotFound

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "認証が必要です"
        case .choreNotFound:
            return "家事が見つかりません"
        }
    }
}

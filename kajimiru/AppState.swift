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

    // MARK: - Persistence
    
    private enum StorageKeys {
        static let lastSelectedGroupId = "lastSelectedGroupId"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }
    
    private var lastSelectedGroupId: UUID? {
        get {
            guard let string = UserDefaults.standard.string(forKey: StorageKeys.lastSelectedGroupId) else {
                return nil
            }
            return UUID(uuidString: string)
        }
        set {
            UserDefaults.standard.set(newValue?.uuidString, forKey: StorageKeys.lastSelectedGroupId)
        }
    }
    
    private var hasCompletedOnboardingPersisted: Bool {
        get {
            UserDefaults.standard.bool(forKey: StorageKeys.hasCompletedOnboarding)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: StorageKeys.hasCompletedOnboarding)
        }
    }

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

    private lazy var inviteRepo: any GroupInviteRepository = {
        if useMockData {
            return InMemoryGroupInviteRepository()
        } else {
            return FirestoreGroupInviteRepository()
        }
    }()

    // MARK: - Services

    private lazy var groupService = GroupService(
        groupRepository: groupRepo,
        memberRepository: memberRepo,
        inviteRepository: inviteRepo
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
            print("🔍 checkUserStatus: No auth UID")
            hasCompletedSetup = false
            return
        }

        print("🔍 checkUserStatus: Starting for UID: \(authUID)")
        isLoading = true
        errorMessage = nil

        do {
            // Try to fetch user from Firestore using Firebase UID
            if let firestoreUserRepo = userRepo as? FirestoreUserRepository,
               let firestoreMemberRepo = memberRepo as? FirestoreMemberRepository {
                let user = try await firestoreUserRepo.fetchUserByFirebaseUid(authUID)

                if let user = user {
                    currentUser = user
                    print("🔍 checkUserStatus: User found: \(user.id)")

                    // Get all groups the user belongs to
                    let groupIds = try await firestoreMemberRepo.listGroupsForUser(firebaseUid: authUID)
                    print("🔍 checkUserStatus: Found \(groupIds.count) groups")

                    if groupIds.isEmpty {
                        // No groups found - show initial setup
                        print("🔍 checkUserStatus: No groups - showing initial setup")
                        hasCompletedSetup = false
                        needsGroupSelection = false
                    } else if groupIds.count == 1 {
                        // Only one group - auto-select it
                        print("🔍 checkUserStatus: Single group - auto-loading: \(groupIds[0])")
                        try await loadUserGroup(groupId: groupIds[0])
                        lastSelectedGroupId = groupIds[0]
                        hasCompletedOnboardingPersisted = true

                        // Update user's currentGroupId if needed
                        if user.currentGroupId != groupIds[0] {
                            var updatedUser = user
                            updatedUser.currentGroupId = groupIds[0]
                            try await userRepo.save(updatedUser)
                            currentUser = updatedUser
                        }

                        hasCompletedSetup = true
                        needsGroupSelection = false
                        print("🔍 checkUserStatus: ✅ Setup complete - should show MainTabView")
                    } else {
                        // Multiple groups - show group selection
                        availableGroups = try await fetchGroups(ids: groupIds)

                        // Try to restore last selected group from UserDefaults
                        let groupIdToLoad: UUID?
                        if let lastGroupId = lastSelectedGroupId, groupIds.contains(lastGroupId) {
                            groupIdToLoad = lastGroupId
                        } else if let currentGroupId = user.currentGroupId, groupIds.contains(currentGroupId) {
                            groupIdToLoad = currentGroupId
                        } else {
                            groupIdToLoad = nil
                        }

                        if let groupIdToLoad = groupIdToLoad {
                            try await loadUserGroup(groupId: groupIdToLoad)
                            lastSelectedGroupId = groupIdToLoad
                            hasCompletedSetup = true
                            needsGroupSelection = false
                        } else {
                            needsGroupSelection = true
                            hasCompletedSetup = false
                        }
                    }
                } else {
                    // User doesn't exist in Firestore yet - check if onboarding was completed
                    print("🔍 checkUserStatus: No user in Firestore - hasCompletedOnboarding: \(hasCompletedOnboardingPersisted)")
                    hasCompletedSetup = hasCompletedOnboardingPersisted
                    needsGroupSelection = false
                }
            }
            print("🔍 checkUserStatus: Completed - hasCompletedSetup: \(hasCompletedSetup), needsGroupSelection: \(needsGroupSelection)")
            isLoading = false
        } catch {
            print("🔍 checkUserStatus: ❌ Error: \(error.localizedDescription)")
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
    private func loadUserGroup(groupId: UUID) async throws {
        group = try await groupRepo.fetchGroup(id: groupId)
        if let group = group {
            members = try await memberRepo.listMembers(in: group.id, includeDeleted: false)
            chores = try await choreRepo.listChores(in: group.id, includeDeleted: false)
            choreLogs = try await choreLogRepo.listLogs(in: group.id, since: nil)
            print("✅ Successfully loaded group: \(group.name)")
        } else {
            throw KajimiruError.notFound
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
            try await loadUserGroup(groupId: group.id)

            // Persist to UserDefaults
            lastSelectedGroupId = group.id
            hasCompletedOnboardingPersisted = true

            // Update state
            needsGroupSelection = false
            hasCompletedSetup = true
        } catch {
            errorMessage = error.localizedDescription
            hasCompletedSetup = false
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

            // 7. Persist to UserDefaults
            lastSelectedGroupId = group.id
            hasCompletedOnboardingPersisted = true

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

    // MARK: - Member Management

    /// Add a new member to the current group
    func addMember(displayName: String) async throws {
        guard let group = group else {
            throw AppStateError.groupRequired
        }

        isLoading = true
        errorMessage = nil

        do {
            let draft = MemberDraft(
                displayName: displayName,
                userId: nil,
                avatarURL: nil
            )
            let member = try await groupService.addMember(
                groupId: group.id,
                draft: draft,
                createdBy: currentUserId
            )
            members.append(member)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Invite Code Management

    /// Generate an invite code for the current group
    func generateInviteCode() async throws -> String {
        guard let group = group else {
            throw AppStateError.groupRequired
        }

        let invite = try await groupService.generateInviteCode(
            for: group.id,
            expiresInDays: 30,
            maxUses: nil,
            createdBy: currentUserId
        )
        return invite.code
    }

    /// Join a group using an invite code
    func joinGroupWithInviteCode(code: String, yourName: String) async throws {
        guard let authUID = authService?.userID,
              let userEmail = authService?.userEmail else {
            throw AppStateError.authenticationRequired
        }

        isLoading = true
        errorMessage = nil

        do {
            let userId = UUID()  // Generate new UUID for internal use

            // Join the group via invite code
            let group = try await groupService.joinGroupWithInviteCode(
                code: code,
                userId: userId,
                firebaseUid: authUID,
                displayName: yourName,
                avatarURL: nil
            )

            // Check if user already exists
            if let firestoreUserRepo = userRepo as? FirestoreUserRepository,
               let existingUser = try await firestoreUserRepo.fetchUserByFirebaseUid(authUID) {
                // Update existing user's current group
                var updatedUser = existingUser
                updatedUser.currentGroupId = group.id
                try await userRepo.save(updatedUser)
                currentUser = updatedUser
            } else {
                // Create new user
                let user = User(
                    id: userId,
                    firebaseUid: authUID,
                    displayName: yourName,
                    email: userEmail,
                    avatarURL: nil,
                    currentGroupId: group.id,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                try await userRepo.save(user)
                currentUser = user
            }

            // Load group data
            try await loadUserGroup(groupId: group.id)

            // Persist to UserDefaults
            lastSelectedGroupId = group.id
            hasCompletedOnboardingPersisted = true

            // Update state
            hasCompletedSetup = true
            needsGroupSelection = false
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            hasCompletedSetup = false
            throw error
        }
    }

    // MARK: - Group Management

    /// Update group name and icon
    func updateGroup(name: String, icon: String?) async throws {
        guard let group = group else {
            throw AppStateError.groupRequired
        }

        isLoading = true
        errorMessage = nil

        do {
            let updatedGroup = try await groupService.updateGroup(
                groupId: group.id,
                name: name,
                icon: icon,
                updatedBy: currentUserId
            )
            self.group = updatedGroup
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// Load all groups the current user belongs to
    func loadAvailableGroups() async throws {
        print("🔍 AppState.loadAvailableGroups: Starting...")
        guard let authUID = authService?.userID else {
            print("❌ AppState.loadAvailableGroups: No auth UID")
            throw AppStateError.authenticationRequired
        }
        print("🔍 AppState.loadAvailableGroups: Auth UID = \(authUID)")

        // Don't set isLoading here to avoid ContentView switching to ProgressView
        errorMessage = nil

        do {
            print("🔍 AppState.loadAvailableGroups: Calling memberRepo.listGroupsForUser...")
            let groupIds = try await memberRepo.listGroupsForUser(firebaseUid: authUID)
            print("🔍 AppState.loadAvailableGroups: Found \(groupIds.count) group IDs: \(groupIds)")
            availableGroups = try await fetchGroups(ids: groupIds)
            print("✅ AppState.loadAvailableGroups: Loaded \(availableGroups.count) groups")
        } catch {
            print("❌ AppState.loadAvailableGroups: Error - \(error)")
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// Switch to a different group
    func switchToGroup(groupId: UUID) async throws {
        guard let user = currentUser else {
            throw AppStateError.authenticationRequired
        }

        isLoading = true
        errorMessage = nil

        do {
            // Load the target group
            guard let targetGroup = try await groupRepo.fetchGroup(id: groupId) else {
                throw AppStateError.groupRequired
            }

            // Update user's current group
            var updatedUser = user
            updatedUser.currentGroupId = groupId
            try await userRepo.save(updatedUser)

            // Update local state
            self.currentUser = updatedUser

            // Load group data
            try await loadUserGroup(groupId: groupId)

            // Persist to UserDefaults
            lastSelectedGroupId = groupId

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
}

// MARK: - Errors

enum AppStateError: LocalizedError {
    case authenticationRequired
    case choreNotFound
    case groupRequired

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "認証が必要です"
        case .choreNotFound:
            return "家事が見つかりません"
        case .groupRequired:
            return "グループが選択されていません"
        }
    }
}

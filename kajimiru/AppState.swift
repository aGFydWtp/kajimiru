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
    
    func getCurrentUserId() throws -> String {
        guard let firebaseUid = authService?.userID else {
            throw AppStateError.authenticationRequired
        }
        return firebaseUid
    }

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
                    // User doesn't exist in Firestore yet - need initial setup
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
            } else {
            }
        }
        return groups
    }

    /// Load user's group data and setup real-time listeners
    private func loadUserGroup(groupId: UUID) async throws {

        do {
            group = try await groupRepo.fetchGroup(id: groupId)

            if let group = group {
                // Initial load
                do {
                    members = try await memberRepo.listMembers(in: group.id, includeDeleted: false)
                } catch {
                    members = []
                }

                do {
                    chores = try await choreRepo.listChores(in: group.id, includeDeleted: false)
                } catch {
                    chores = []
                }

                do {
                    choreLogs = try await choreLogRepo.listLogs(in: group.id, since: nil)
                } catch {
                    choreLogs = []
                }

                // Setup real-time listeners for Firebase repositories
                await setupRealtimeListeners(for: group.id)

            } else {
                throw KajimiruError.notFound
            }
        } catch {
            throw error
        }
    }

    /// Setup real-time listeners for group data (only for Firebase repositories)
    private func setupRealtimeListeners(for groupId: UUID) async {
        // Listen to group document to detect deletion
        if let firestoreGroupRepo = groupRepo as? FirestoreGroupRepository {
            await firestoreGroupRepo.observeGroup(id: groupId) { [weak self] group in
                Task { @MainActor in
                    if group == nil {
                        // Group was deleted - handle it
                        await self?.handleGroupDeletion()
                    }
                }
            }
        }

        // Check if using Firebase repositories
        if let firestoreChoreRepo = choreRepo as? FirestoreChoreRepository {
            await firestoreChoreRepo.observeChores(in: groupId, includeDeleted: false) { [weak self] chores in
                Task { @MainActor in
                    self?.chores = chores
                }
            }
        }

        if let firestoreLogRepo = choreLogRepo as? FirestoreChoreLogRepository {
            await firestoreLogRepo.observeLogs(in: groupId, since: nil) { [weak self] logs in
                Task { @MainActor in
                    self?.choreLogs = logs
                }
            }
        }

        if let firestoreMemberRepo = memberRepo as? FirestoreMemberRepository {
            await firestoreMemberRepo.observeMembers(in: groupId, includeDeleted: false) { [weak self] members in
                Task { @MainActor in
                    self?.members = members
                }
            }
        }
    }

    /// Stop all real-time listeners
    private func stopRealtimeListeners() async {
        if let firestoreGroupRepo = groupRepo as? FirestoreGroupRepository {
            await firestoreGroupRepo.stopObserving()
        }

        if let firestoreChoreRepo = choreRepo as? FirestoreChoreRepository {
            await firestoreChoreRepo.stopObserving()
        }

        if let firestoreLogRepo = choreLogRepo as? FirestoreChoreLogRepository {
            await firestoreLogRepo.stopObserving()
        }

        if let firestoreMemberRepo = memberRepo as? FirestoreMemberRepository {
            await firestoreMemberRepo.stopObserving()
        }
    }

    /// Handle when current group is deleted (by self or others)
    private func handleGroupDeletion() async {
        guard let authUID = authService?.userID else { return }

        // Clear current group state
        self.group = nil
        self.members = []
        self.chores = []
        self.choreLogs = []

        // Stop all listeners
        await stopRealtimeListeners()

        // Check remaining groups
        do {
            guard let firestoreMemberRepo = memberRepo as? FirestoreMemberRepository else {
                // Not using Firestore, show initial setup
                hasCompletedSetup = false
                needsGroupSelection = false
                return
            }

            let groupIds = try await firestoreMemberRepo.listGroupsForUser(firebaseUid: authUID)

            if groupIds.isEmpty {
                // No groups remaining - show initial setup
                hasCompletedSetup = false
                needsGroupSelection = false
            } else if groupIds.count == 1 {
                // Only one group remaining - auto-select it
                try await loadUserGroup(groupId: groupIds[0])
                lastSelectedGroupId = groupIds[0]

                // Update user's currentGroupId
                if var user = currentUser {
                    user.currentGroupId = groupIds[0]
                    try await userRepo.save(user)
                    currentUser = user
                }

                hasCompletedSetup = true
                needsGroupSelection = false
            } else {
                // Multiple groups remaining - show group selection
                availableGroups = try await fetchGroups(ids: groupIds)
                hasCompletedSetup = false
                needsGroupSelection = true
            }
        } catch {
            print("Error handling group deletion: \(error)")
            // Fallback to initial setup
            hasCompletedSetup = false
            needsGroupSelection = false
        }
    }

    /// Select a group and load its data
    func selectGroup(_ group: Group) async {
        guard let user = currentUser else { return }

        isLoading = true

        // Stop existing listeners before switching groups
        await stopRealtimeListeners()

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

    /// Find a User by their Firebase UID
    func findUserByFirebaseUid(_ firebaseUid: String) async throws -> User? {
        // Query Firestore for user with matching firebaseUid (which is now the User.id)
        guard let firestoreUserRepo = userRepo as? FirestoreUserRepository else {
            // For mock repositories, check currentUser
            if currentUser?.id == firebaseUid {
                return currentUser
            }
            return nil
        }

        return try await firestoreUserRepo.fetchUserByFirebaseUid(firebaseUid)
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
            // 1. Create User - use Firebase UID as User.id
            let user = User(
                id: authUID,  // Firebase UID is now the User ID
                displayName: yourName,
                email: userEmail,
                avatarURL: nil,
                currentGroupId: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            try await userRepo.save(user)

            // 2. Create Group - use Member UUID for createdBy/updatedBy
            let memberUUID = UUID()  // Generate UUID for Member
            let group = Group(
                name: groupName,
                icon: "house.fill",
                members: [],
                createdBy: authUID,
                updatedBy: authUID
            )
            try await groupRepo.save(group)

            // 3. Create self as admin member
            // Member.id is UUID, Member.userId links to User.id (Firebase UID)
            let selfMember = Member(
                id: memberUUID,
                userId: authUID,  // Link to User.id (Firebase UID)
                displayName: yourName,
                avatarURL: nil,
                groupId: group.id,
                role: .admin,
                createdBy: authUID,
                updatedBy: authUID,
                deletedAt: nil,
                deletedBy: nil
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
                    createdBy: authUID,
                    updatedBy: authUID,
                    deletedAt: nil,
                    deletedBy: nil
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
        let chore = try await choreService.createChore(draft: draft, createdBy: getCurrentUserId())
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
        chore = try chore.updating(updatedBy: getCurrentUserId())

        // Save to repository
        try await choreRepo.save(chore)

        // Update local state
        chores[index] = chore
    }

    func deleteChore(choreId: UUID) async {
        do {
            let currentUserId = try getCurrentUserId()
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
        let logs = try await choreLogService.recordChore(draft: draft, createdBy: getCurrentUserId())
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

    func getMonthlySnapshot() async throws -> WorkloadSnapshot? {
        guard group != nil else { return nil }

        let now = Date()
        let snapshots = analyticsService.monthlySnapshots(
            logs: choreLogs,
            endingOn: now,
            monthCount: 1
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

        let draft = MemberDraft(
            displayName: displayName,
            userId: nil,
            avatarURL: nil
        )
        _ = try await groupService.addMember(
            groupId: group.id,
            draft: draft,
            createdBy: getCurrentUserId()
        )
        // Note: Don't append locally - real-time listener will update members array
    }

    // MARK: - Invite Code Management

    /// Generate an invite code for the current group
    func generateInviteCode() async throws -> String {
        guard let group = group else {
            throw AppStateError.groupRequired
        }

        guard let firebaseUid = authService?.userID else {
            throw AppStateError.authenticationRequired
        }

        let invite = try await groupService.generateInviteCode(
            for: group.id,
            expiresInDays: 30,
            createdBy: firebaseUid
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
            // Join the group via invite code
            let group = try await groupService.joinGroupWithInviteCode(
                code: code,
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
                // Create new user - use Firebase UID as User.id
                let user = User(
                    id: authUID,  // Firebase UID is now the User ID
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

    /// Link Firebase Auth user to an existing unlinked member
    func linkToExistingMember(
        memberId: UUID,
        groupId: UUID,
        inviteCode: String
    ) async throws {
        guard let authUID = authService?.userID,
              let userEmail = authService?.userEmail else {
            throw AppStateError.authenticationRequired
        }

        isLoading = true
        errorMessage = nil

        do {
            // Link the member to Firebase Auth
            let linkedMember = try await groupService.linkMemberToFirebaseAuth(
                memberId: memberId,
                groupId: groupId,
                firebaseUid: authUID
            )

            // Verify and increment invite code usage
            if let firestoreInviteRepo = inviteRepo as? FirestoreGroupInviteRepository,
               let invite = try await firestoreInviteRepo.fetchInvite(code: inviteCode) {
                let updatedInvite = invite.incrementUses()
                try await inviteRepo.save(updatedInvite)
            }

            // Check if user already exists
            if let firestoreUserRepo = userRepo as? FirestoreUserRepository,
               let existingUser = try await firestoreUserRepo.fetchUserByFirebaseUid(authUID) {
                // Update existing user's current group
                var updatedUser = existingUser
                updatedUser.currentGroupId = groupId
                try await userRepo.save(updatedUser)
                currentUser = updatedUser
            } else {
                // Create new user - use Firebase UID as User.id
                let user = User(
                    id: authUID,  // Firebase UID is now the User ID
                    displayName: linkedMember.displayName,
                    email: userEmail,
                    avatarURL: linkedMember.avatarURL,
                    currentGroupId: groupId,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                try await userRepo.save(user)
                currentUser = user
            }

            // Load group data
            try await loadUserGroup(groupId: groupId)

            // Persist to UserDefaults
            lastSelectedGroupId = groupId
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

    /// Get unlinked members (members without firebaseUid) for a group
    func getUnlinkedMembers(for groupId: UUID) async throws -> [Member] {
        let allMembers = try await memberRepo.listMembers(in: groupId, includeDeleted: false)
        return allMembers.filter { $0.userId == nil }
    }

    /// Validate an invite code and return the group ID if valid
    func validateInviteCode(_ code: String) async throws -> UUID {
        if let firestoreInviteRepo = inviteRepo as? FirestoreGroupInviteRepository,
           let invite = try await firestoreInviteRepo.fetchInvite(code: code) {

            guard invite.isValid else {
                throw AppStateError.invalidInviteCode
            }

            return invite.groupId
        } else {
            throw AppStateError.inviteCodeNotFound
        }
    }

    // MARK: - Group Management

    /// Update group name and icon
    func updateGroup(name: String, icon: String?) async throws {
        guard let group = group else {
            throw AppStateError.groupRequired
        }

        // Don't set isLoading here to avoid ContentView switching to ProgressView
        errorMessage = nil

        do {
            let updatedGroup = try await groupService.updateGroup(
                groupId: group.id,
                name: name,
                icon: icon,
                updatedBy: getCurrentUserId()
            )
            self.group = updatedGroup
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// Load all groups the current user belongs to
    func loadAvailableGroups() async throws {
        guard let authUID = authService?.userID else {
            throw AppStateError.authenticationRequired
        }

        // Don't set isLoading here to avoid ContentView switching to ProgressView
        errorMessage = nil

        do {
            let groupIds = try await memberRepo.listGroupsForUser(firebaseUid: authUID)
            availableGroups = try await fetchGroups(ids: groupIds)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// Switch to a different group
    /// Create or update User document after joining via invite code
    func createOrUpdateUserAfterJoin(
        firebaseUid: String,
        displayName: String,
        groupId: UUID
    ) async throws {
        guard let authService = authService else {
            throw AppStateError.authenticationRequired
        }

        // Check if user already exists - use Firebase UID as User.id
        let existingUsers = try await userRepo.fetchUsers(ids: [firebaseUid])
        if let existingUser = existingUsers.first {
            var updatedUser = existingUser
            updatedUser.currentGroupId = groupId
            try await userRepo.save(updatedUser)
            currentUser = updatedUser
        } else {
            let user = User(
                id: firebaseUid,  // Firebase UID is now the User ID
                displayName: displayName,
                email: authService.userEmail,
                avatarURL: nil,
                currentGroupId: groupId,
                createdAt: Date(),
                updatedAt: Date()
            )
            try await userRepo.save(user)
            currentUser = user
        }

        // Update state flags
        hasCompletedOnboardingPersisted = true
        lastSelectedGroupId = groupId
    }

    func switchToGroup(groupId: UUID) async throws {
        guard let user = currentUser else {
            throw AppStateError.authenticationRequired
        }

        isLoading = true
        errorMessage = nil

        do {
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

            // Update state flags
            hasCompletedSetup = true
            needsGroupSelection = false

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// Update member display name
    func updateMember(memberId: UUID, displayName: String) async throws {
        guard group != nil else {
            throw AppStateError.groupRequired
        }

        guard let index = members.firstIndex(where: { $0.id == memberId }) else {
            throw AppStateError.memberNotFound
        }

        var member = members[index]
        member.displayName = displayName
        member = member.updating(updatedBy: try getCurrentUserId())

        try await memberRepo.save(member)
        // Note: Don't update locally - real-time listener will update members array
    }

    /// Delete (soft delete) a member
    func deleteMember(memberId: UUID) async throws {
        guard let groupId = group?.id else {
            throw AppStateError.groupRequired
        }

        let currentUserId = try getCurrentUserId()
        try await memberRepo.softDeleteMember(id: memberId, in: groupId, deletedBy: currentUserId)
        // Note: Don't update locally - real-time listener will update members array
    }

    /// Link a member to a Firebase user account
    func linkMemberToUser(memberId: UUID, firebaseUid: String) async throws {
        guard group != nil else {
            throw AppStateError.groupRequired
        }

        guard let index = members.firstIndex(where: { $0.id == memberId }) else {
            throw AppStateError.memberNotFound
        }

        var member = members[index]
        member = member.updating(userId: firebaseUid, updatedBy: firebaseUid)

        try await memberRepo.save(member)
        // Note: Don't update locally - real-time listener will update members array
    }

    /// Unlink a member from their Firebase user account
    func unlinkMember(memberId: UUID) async throws {
        guard group != nil else {
            throw AppStateError.groupRequired
        }

        guard let index = members.firstIndex(where: { $0.id == memberId }) else {
            throw AppStateError.memberNotFound
        }

        let currentUserId = try getCurrentUserId()
        var member = members[index]
        member = member.updatingWithNilUserId(updatedBy: currentUserId)

        try await memberRepo.save(member)
        // Note: Don't update locally - real-time listener will update members array
    }

    /// Transfer user link from one member to another using Firestore transaction
    func transferMemberLink(fromMemberId: UUID, toMemberId: UUID, userId: String) async throws {
        guard let groupId = group?.id else {
            throw AppStateError.groupRequired
        }

        // For Firestore repositories, use transaction
        if let firestoreMemberRepo = memberRepo as? FirestoreMemberRepository {
            try await firestoreMemberRepo.transferUserLink(
                fromMemberId: fromMemberId,
                toMemberId: toMemberId,
                userId: userId,
                groupId: groupId
            )
        } else {
            // For non-Firestore repositories, do it sequentially
            guard let fromIndex = members.firstIndex(where: { $0.id == fromMemberId }),
                  let toIndex = members.firstIndex(where: { $0.id == toMemberId }) else {
                throw AppStateError.memberNotFound
            }

            // Unlink from source
            var fromMember = members[fromIndex]
            fromMember = fromMember.updatingWithNilUserId(updatedBy: userId)
            try await memberRepo.save(fromMember)

            // Link to target
            var toMember = members[toIndex]
            toMember = toMember.updating(userId: userId, updatedBy: userId)
            try await memberRepo.save(toMember)
        }
        // Note: Don't update locally - real-time listener will update members array
    }

    /// Physically delete the current group
    func deleteGroup() async throws {
        guard let groupId = group?.id else {
            throw AppStateError.groupRequired
        }

        try await groupService.deleteGroup(groupId: groupId)

        // handleGroupDeletion will be called by the group listener
        // when it detects the group no longer exists
    }
}

// MARK: - Errors

enum AppStateError: LocalizedError {
    case authenticationRequired
    case choreNotFound
    case groupRequired
    case inviteCodeNotFound
    case invalidInviteCode
    case memberNotFound

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "認証が必要です"
        case .choreNotFound:
            return "家事が見つかりません"
        case .groupRequired:
            return "グループが選択されていません"
        case .inviteCodeNotFound:
            return "招待コードが見つかりません"
        case .invalidInviteCode:
            return "招待コードが無効です（期限切れまたは使用済み）"
        case .memberNotFound:
            return "メンバーが見つかりません"
        }
    }
}

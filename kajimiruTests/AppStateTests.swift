import XCTest
@testable import kajimiru
@testable import KajimiruKit

/// Tests for AppState user status check logic
@MainActor
final class AppStateTests: XCTestCase {

    func testCheckUserStatusWithSingleGroupAutoLoads() async throws {
        // This test verifies that when a user belongs to exactly one group,
        // checkUserStatus() automatically loads that group and sets hasCompletedSetup to true

        // Setup: Create user, group, and member
        let testUserId = UUID()
        let testFirebaseUid = "test-firebase-uid"
        let testGroupId = UUID()

        let user = User(
            id: testUserId,
            firebaseUid: testFirebaseUid,
            displayName: "Test User",
            email: "test@example.com",
            avatarURL: nil,
            currentGroupId: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        let group = Group(
            id: testGroupId,
            name: "Test Group",
            icon: "house.fill",
            members: [],
            createdBy: testUserId,
            updatedBy: testUserId
        )

        let member = Member(
            id: testUserId,
            userId: testUserId,
            firebaseUid: testFirebaseUid,
            displayName: "Test User",
            avatarURL: nil,
            groupId: testGroupId,
            role: .admin,
            createdBy: testUserId,
            updatedBy: testUserId
        )

        // Create in-memory repositories with test data
        let userRepo = InMemoryUserRepository(users: [user])
        let groupRepo = InMemoryGroupRepository(groups: [group])
        let memberRepo = InMemoryMemberRepository(members: [member])

        // Create mock auth service
        let mockAuthService = MockAuthService(firebaseUid: testFirebaseUid)

        // Create AppState with mock data enabled
        let appState = AppState(useMockData: true)
        appState.setAuthService(mockAuthService)

        // Clear any persisted data
        UserDefaults.standard.removeObject(forKey: "lastSelectedGroupId")
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")

        // Verify the test scenario
        let groupIds = try await memberRepo.listGroupsForUser(firebaseUid: testFirebaseUid)
        XCTAssertEqual(groupIds.count, 1, "User should belong to exactly one group")
        XCTAssertEqual(groupIds.first, testGroupId, "User should belong to the test group")

        // Execute checkUserStatus
        await appState.checkUserStatus()

        // Expected behavior:
        // When user belongs to exactly one group:
        // - hasCompletedSetup should be true
        // - needsGroupSelection should be false
        // - group should be loaded automatically

        XCTAssertTrue(appState.hasCompletedSetup, "hasCompletedSetup should be true for single group user")
        XCTAssertFalse(appState.needsGroupSelection, "needsGroupSelection should be false for single group user")
        XCTAssertNotNil(appState.group, "Group should be loaded automatically")
        XCTAssertEqual(appState.group?.id, testGroupId, "Loaded group should match the user's group")

        print("✅ Test complete: Single group auto-load verified")
    }
}

// Mock authentication service for testing
class MockAuthService: AuthenticationService {
    let testFirebaseUid: String

    init(firebaseUid: String) {
        self.testFirebaseUid = firebaseUid
        super.init()
        self.isAuthenticated = true
    }

    override var userID: String? {
        return testFirebaseUid
    }
}

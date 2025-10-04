import XCTest
@testable import KajimiruKit

final class ChoreServiceTests: XCTestCase {
    func testCreateChorePersistsAndTrimsFields() async throws {
        let testUserId = UUID()
        let adminId = UUID()
        let group = Group(
            name: "Home",
            members: [
                Member(
                    userId: adminId,
                    displayName: "Admin User",
                    groupId: UUID(), // Will be set after group creation
                    role: .admin,
                    createdBy: testUserId,
                    updatedBy: testUserId
                )
            ],
            createdBy: testUserId,
            updatedBy: testUserId
        )
        let choreRepository = InMemoryChoreRepository()
        let groupRepository = InMemoryGroupRepository(groups: [group])
        let service = ChoreService(choreRepository: choreRepository, groupRepository: groupRepository)

        let draft = ChoreDraft(
            groupId: group.id,
            title: "  Take out trash  ",
            weight: 3,
            notes: "  Leave by 8am  "
        )

        let chore = try await service.createChore(draft: draft, createdBy: adminId)
        let stored = try await choreRepository.fetchChore(id: chore.id)

        XCTAssertEqual(stored?.title, "Take out trash")
        XCTAssertEqual(stored?.notes, "Leave by 8am")
        XCTAssertEqual(stored?.weight, 3)
        XCTAssertEqual(stored?.groupId, group.id)
    }

    func testCreateChoreRejectsInvalidInput() async throws {
        let testUserId = UUID()
        let adminId = UUID()
        let group = Group(
            name: "Home",
            members: [
                Member(
                    userId: adminId,
                    displayName: "Admin User",
                    groupId: UUID(),
                    role: .admin,
                    createdBy: testUserId,
                    updatedBy: testUserId
                )
            ],
            createdBy: testUserId,
            updatedBy: testUserId
        )
        let choreRepository = InMemoryChoreRepository()
        let groupRepository = InMemoryGroupRepository(groups: [group])
        let service = ChoreService(choreRepository: choreRepository, groupRepository: groupRepository)

        let invalidDraft = ChoreDraft(
            groupId: group.id,
            title: "   ",
            weight: 1
        )

        do {
            _ = try await service.createChore(draft: invalidDraft, createdBy: adminId)
            XCTFail("Expected validation error")
        } catch let error as KajimiruError {
            if case let .validationFailed(reason) = error {
                XCTAssertEqual(reason, "Title must not be empty.")
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testDeleteChoreSoftDeletes() async throws {
        let testUserId = UUID()
        let adminId = UUID()
        let group = Group(
            name: "Home",
            members: [
                Member(
                    userId: adminId,
                    displayName: "Admin User",
                    groupId: UUID(),
                    role: .admin,
                    createdBy: testUserId,
                    updatedBy: testUserId
                )
            ],
            createdBy: testUserId,
            updatedBy: testUserId
        )
        let choreRepository = InMemoryChoreRepository()
        let groupRepository = InMemoryGroupRepository(groups: [group])
        let service = ChoreService(choreRepository: choreRepository, groupRepository: groupRepository)

        let draft = ChoreDraft(groupId: group.id, title: "Laundry", weight: 2)
        let chore = try await service.createChore(draft: draft, createdBy: adminId)

        try await service.deleteChore(id: chore.id, deletedBy: adminId)
        let stored = try await choreRepository.fetchChore(id: chore.id)

        XCTAssertNotNil(stored?.deletedAt)
        XCTAssertEqual(stored?.deletedBy, adminId)
    }
}

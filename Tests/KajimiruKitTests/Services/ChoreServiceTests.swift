import XCTest
@testable import KajimiruKit

final class ChoreServiceTests: XCTestCase {
    func testCreateChorePersistsAndTrimsFields() async throws {
        let adminId = UUID()
        let group = Group(
            name: "Home",
            members: [
                GroupMembership(userId: adminId, role: .admin)
            ]
        )
        let choreRepository = InMemoryChoreRepository()
        let groupRepository = InMemoryGroupRepository(groups: [group])
        let service = ChoreService(choreRepository: choreRepository, groupRepository: groupRepository)

        let draft = ChoreDraft(
            groupId: group.id,
            title: "  Take out trash  ",
            category: .cleaning,
            estimatedMinutes: 10,
            notes: "  Leave by 8am  "
        )

        let chore = try await service.createChore(draft: draft, actorId: adminId)
        let stored = try await choreRepository.fetchChore(id: chore.id)

        XCTAssertEqual(stored?.title, "Take out trash")
        XCTAssertEqual(stored?.notes, "Leave by 8am")
        XCTAssertEqual(stored?.estimatedMinutes, 10)
        XCTAssertEqual(stored?.groupId, group.id)
    }

    func testCreateChoreRejectsInvalidInput() async throws {
        let adminId = UUID()
        let group = Group(
            name: "Home",
            members: [GroupMembership(userId: adminId, role: .admin)]
        )
        let choreRepository = InMemoryChoreRepository()
        let groupRepository = InMemoryGroupRepository(groups: [group])
        let service = ChoreService(choreRepository: choreRepository, groupRepository: groupRepository)

        let invalidDraft = ChoreDraft(
            groupId: group.id,
            title: "   ",
            category: .cleaning
        )

        do {
            _ = try await service.createChore(draft: invalidDraft, actorId: adminId)
            XCTFail("Expected validation error")
        } catch let error as KajimiruError {
            if case let .validationFailed(reason) = error {
                XCTAssertEqual(reason, "Title must not be empty.")
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testDeleteChoreRequiresPermissions() async throws {
        let adminId = UUID()
        let viewerId = UUID()
        let group = Group(
            name: "Home",
            members: [
                GroupMembership(userId: adminId, role: .admin),
                GroupMembership(userId: viewerId, role: .viewer)
            ]
        )
        let choreRepository = InMemoryChoreRepository()
        let groupRepository = InMemoryGroupRepository(groups: [group])
        let service = ChoreService(choreRepository: choreRepository, groupRepository: groupRepository)

        let draft = ChoreDraft(groupId: group.id, title: "Laundry", category: .laundry)
        let chore = try await service.createChore(draft: draft, actorId: adminId)

        do {
            try await service.deleteChore(id: chore.id, groupId: group.id, actorId: viewerId)
            XCTFail("Expected unauthorized error")
        } catch let error as KajimiruError {
            XCTAssertEqual(error, .unauthorized)
        }

        try await service.deleteChore(id: chore.id, groupId: group.id, actorId: adminId)
        let stored = try await choreRepository.fetchChore(id: chore.id)
        XCTAssertNil(stored)
    }
}

import XCTest
@testable import KajimiruKit

final class ChoreLogServiceTests: XCTestCase {
    func testRecordChorePersistsLog() async throws {
        let adminId = UUID()
        let performerId = adminId
        let group = Group(
            name: "Home",
            members: [GroupMembership(userId: adminId, role: .admin)]
        )
        let groupRepository = InMemoryGroupRepository(groups: [group])
        let choreRepository = InMemoryChoreRepository()
        let logRepository = InMemoryChoreLogRepository()
        let service = ChoreLogService(
            logRepository: logRepository,
            choreRepository: choreRepository,
            groupRepository: groupRepository
        )

        let chore = Chore(groupId: group.id, title: "Dishes", weight: 3)
        try await choreRepository.save(chore)

        let timestamp = Date().addingTimeInterval(-3600)
        let draft = ChoreLogDraft(
            groupId: group.id,
            choreId: chore.id,
            performerId: performerId,
            memo: "  Used new sponge  ",
            createdAt: timestamp
        )

        let log = try await service.recordChore(draft: draft, actorId: adminId)
        let stored = try await logRepository.listLogs(in: group.id, since: nil)

        XCTAssertEqual(stored.count, 1)
        let storedLog = try XCTUnwrap(stored.first)
        XCTAssertEqual(storedLog.id, log.id)
        XCTAssertEqual(storedLog.memo, "Used new sponge")
        XCTAssertEqual(storedLog.weight, chore.weight)
        XCTAssertEqual(storedLog.createdAt.timeIntervalSince1970, timestamp.timeIntervalSince1970, accuracy: 0.5)
    }

    func testUpdateLogUpdatesFields() async throws {
        let adminId = UUID()
        let newPerformer = UUID()
        let group = Group(
            name: "Home",
            members: [GroupMembership(userId: adminId, role: .admin)]
        )
        let groupRepository = InMemoryGroupRepository(groups: [group])
        let choreRepository = InMemoryChoreRepository()
        let logRepository = InMemoryChoreLogRepository()
        let service = ChoreLogService(
            logRepository: logRepository,
            choreRepository: choreRepository,
            groupRepository: groupRepository
        )

        let chore = Chore(groupId: group.id, title: "Vacuum", weight: 2)
        try await choreRepository.save(chore)

        let initialLog = try await service.recordChore(
            draft: ChoreLogDraft(
                groupId: group.id,
                choreId: chore.id,
                performerId: adminId
            ),
            actorId: adminId
        )

        let updated = try await service.updateLog(
            logId: initialLog.id,
            groupId: group.id,
            actorId: adminId,
            update: ChoreLogUpdate(performerId: newPerformer, memo: .some(" Updated "))
        )
        XCTAssertEqual(updated.memo, "Updated")
        XCTAssertEqual(updated.performerId, newPerformer)
        XCTAssertEqual(updated.weight, chore.weight)
        XCTAssertTrue(updated.updatedAt >= initialLog.updatedAt)
    }

    func testRecordChoreRejectsFarFutureDate() async throws {
        let adminId = UUID()
        let group = Group(
            name: "Home",
            members: [GroupMembership(userId: adminId, role: .admin)]
        )
        let groupRepository = InMemoryGroupRepository(groups: [group])
        let choreRepository = InMemoryChoreRepository()
        let logRepository = InMemoryChoreLogRepository()
        let service = ChoreLogService(
            logRepository: logRepository,
            choreRepository: choreRepository,
            groupRepository: groupRepository
        )

        let chore = Chore(groupId: group.id, title: "Windows", weight: 5)
        try await choreRepository.save(chore)

        let futureDate = Date().addingTimeInterval(60 * 60 * 26)
        let draft = ChoreLogDraft(
            groupId: group.id,
            choreId: chore.id,
            performerId: adminId,
            createdAt: futureDate
        )

        do {
            _ = try await service.recordChore(draft: draft, actorId: adminId)
            XCTFail("Expected validation error")
        } catch let error as KajimiruError {
            if case let .validationFailed(reason) = error {
                XCTAssertEqual(reason, "Created date cannot be more than 24 hours in the future.")
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testUnauthorizedUserCannotRecord() async throws {
        let adminId = UUID()
        let viewerId = UUID()
        let group = Group(
            name: "Home",
            members: [
                GroupMembership(userId: adminId, role: .admin),
                GroupMembership(userId: viewerId, role: .viewer)
            ]
        )
        let groupRepository = InMemoryGroupRepository(groups: [group])
        let choreRepository = InMemoryChoreRepository()
        let logRepository = InMemoryChoreLogRepository()
        let service = ChoreLogService(
            logRepository: logRepository,
            choreRepository: choreRepository,
            groupRepository: groupRepository
        )

        let chore = Chore(groupId: group.id, title: "Trash", weight: 1)
        try await choreRepository.save(chore)

        let draft = ChoreLogDraft(
            groupId: group.id,
            choreId: chore.id,
            performerId: viewerId
        )

        do {
            _ = try await service.recordChore(draft: draft, actorId: viewerId)
            XCTFail("Expected unauthorized error")
        } catch let error as KajimiruError {
            XCTAssertEqual(error, .unauthorized)
        }
    }
}

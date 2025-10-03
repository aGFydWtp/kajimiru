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

        let logs = try await service.recordChore(draft: draft, createdBy: adminId)
        let stored = try await logRepository.listLogs(in: group.id, since: nil)

        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(stored.count, 1)
        let storedLog = try XCTUnwrap(stored.first)
        XCTAssertEqual(storedLog.id, logs[0].id)
        XCTAssertEqual(storedLog.memo, "Used new sponge")
        XCTAssertEqual(storedLog.weight, Double(chore.weight))
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

        let initialLogs = try await service.recordChore(
            draft: ChoreLogDraft(
                groupId: group.id,
                choreId: chore.id,
                performerId: adminId
            ),
            createdBy: adminId
        )
        let initialLog = initialLogs[0]

        let updated = try await service.updateLog(
            logId: initialLog.id,
            groupId: group.id,
            update: ChoreLogUpdate(performerId: newPerformer, memo: .some(" Updated ")),
            updatedBy: adminId
        )
        XCTAssertEqual(updated.memo, "Updated")
        XCTAssertEqual(updated.performerId, newPerformer)
        XCTAssertEqual(updated.weight, Double(chore.weight))
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
            _ = try await service.recordChore(draft: draft, createdBy: adminId)
            XCTFail("Expected validation error")
        } catch let error as KajimiruError {
            if case let .validationFailed(reason) = error {
                XCTAssertEqual(reason, "Created date cannot be more than 24 hours in the future.")
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testRecordChoreWithMultiplePerformers() async throws {
        let adminId = UUID()
        let performer1 = UUID()
        let performer2 = UUID()
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

        let chore = Chore(groupId: group.id, title: "Cleaning", weight: 3)
        try await choreRepository.save(chore)

        let draft = ChoreLogDraft(
            groupId: group.id,
            choreId: chore.id,
            performerIds: [performer1, performer2],
            memo: "Together"
        )

        let logs = try await service.recordChore(draft: draft, createdBy: adminId)
        let stored = try await logRepository.listLogs(in: group.id, since: nil)

        XCTAssertEqual(logs.count, 2)
        XCTAssertEqual(stored.count, 2)

        // Both logs should have same batchId and performerCount
        let batchId = logs[0].batchId
        XCTAssertEqual(logs[1].batchId, batchId, "Both logs should share the same batchId")
        XCTAssertEqual(logs[0].performerCount, 2)
        XCTAssertEqual(logs[1].performerCount, 2)

        // Weight should be evenly distributed
        XCTAssertEqual(logs[0].weight, 1.5, accuracy: 0.01)
        XCTAssertEqual(logs[1].weight, 1.5, accuracy: 0.01)

        // Both should have the same memo
        XCTAssertEqual(logs[0].memo, "Together")
        XCTAssertEqual(logs[1].memo, "Together")
    }
}

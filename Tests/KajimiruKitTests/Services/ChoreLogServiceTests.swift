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

        let chore = Chore(groupId: group.id, title: "Dishes", category: .cooking, estimatedMinutes: 15)
        try await choreRepository.save(chore)

        let draft = ChoreLogDraft(
            groupId: group.id,
            choreId: chore.id,
            performerId: performerId,
            startedAt: Date(),
            durationMinutes: 20,
            memo: "Used new sponge"
        )

        let log = try await service.recordChore(draft: draft, actorId: adminId)
        let stored = try await logRepository.listLogs(in: group.id, since: nil)

        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.id, log.id)
        XCTAssertEqual(stored.first?.durationMinutes, 20)
    }

    func testUpdateLogValidations() async throws {
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

        let chore = Chore(groupId: group.id, title: "Vacuum", category: .cleaning)
        try await choreRepository.save(chore)

        let initialLog = try await service.recordChore(
            draft: ChoreLogDraft(
                groupId: group.id,
                choreId: chore.id,
                performerId: adminId,
                startedAt: Date()
            ),
            actorId: adminId
        )

        do {
            _ = try await service.updateLog(
                logId: initialLog.id,
                groupId: group.id,
                actorId: adminId,
                update: ChoreLogUpdate(durationMinutes: .some(-5))
            )
            XCTFail("Expected validation error")
        } catch let error as KajimiruError {
            if case let .validationFailed(reason) = error {
                XCTAssertEqual(reason, "Duration must be positive when provided.")
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }

        let updated = try await service.updateLog(
            logId: initialLog.id,
            groupId: group.id,
            actorId: adminId,
            update: ChoreLogUpdate(memo: .some("Updated"))
        )
        XCTAssertEqual(updated.memo, "Updated")
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

        let chore = Chore(groupId: group.id, title: "Trash", category: .cleaning)
        try await choreRepository.save(chore)

        let draft = ChoreLogDraft(
            groupId: group.id,
            choreId: chore.id,
            performerId: viewerId,
            startedAt: Date()
        )

        do {
            _ = try await service.recordChore(draft: draft, actorId: viewerId)
            XCTFail("Expected unauthorized error")
        } catch let error as KajimiruError {
            XCTAssertEqual(error, .unauthorized)
        }
    }
}

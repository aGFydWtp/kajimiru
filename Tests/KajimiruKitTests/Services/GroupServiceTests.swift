import XCTest
@testable import KajimiruKit

final class GroupServiceTests: XCTestCase {
    func testCreateGroupAssignsOwnerAndMembers() async throws {
        let ownerId = UUID()
        let invitee = UUID()
        let draft = GroupDraft(
            name: "  Family Home  ",
            icon: "  house.fill  ",
            initialMembers: [GroupMemberInput(userId: invitee, role: .editor)]
        )
        let repository = InMemoryGroupRepository()
        let service = GroupService(groupRepository: repository)

        let group = try await service.createGroup(draft: draft, ownerId: ownerId)
        let stored = try await repository.fetchGroup(id: group.id)

        XCTAssertEqual(stored?.name, "Family Home")
        XCTAssertEqual(stored?.icon, "house.fill")
        XCTAssertEqual(stored?.members.count, 2)
        XCTAssertEqual(stored?.members.first(where: { $0.userId == ownerId })?.role, .admin)
        XCTAssertEqual(stored?.members.first(where: { $0.userId == invitee })?.role, .editor)
    }

    func testAddMemberRequiresAdminRole() async throws {
        let adminId = UUID()
        let editorId = UUID()
        let group = Group(
            name: "Office",
            members: [
                GroupMembership(userId: adminId, role: .admin),
                GroupMembership(userId: editorId, role: .editor)
            ]
        )
        let repository = InMemoryGroupRepository(groups: [group])
        let service = GroupService(groupRepository: repository)

        do {
            _ = try await service.addMember(
                groupId: group.id,
                actorId: editorId,
                member: GroupMemberInput(userId: UUID(), role: .viewer)
            )
            XCTFail("Expected unauthorized error")
        } catch let error as KajimiruError {
            XCTAssertEqual(error, .unauthorized)
        }

        let newUserId = UUID()
        let updated = try await service.addMember(
            groupId: group.id,
            actorId: adminId,
            member: GroupMemberInput(userId: newUserId, role: .viewer)
        )
        XCTAssertEqual(updated.members.count, 3)
        XCTAssertTrue(updated.members.contains(where: { $0.userId == newUserId && $0.role == .viewer }))
    }

    func testUpdateMemberRoleMaintainsAdminPresence() async throws {
        let ownerId = UUID()
        let group = Group(
            name: "Studio",
            members: [GroupMembership(userId: ownerId, role: .admin)]
        )
        let repository = InMemoryGroupRepository(groups: [group])
        let service = GroupService(groupRepository: repository)

        do {
            _ = try await service.updateMemberRole(
                groupId: group.id,
                actorId: ownerId,
                memberId: ownerId,
                role: .editor
            )
            XCTFail("Expected validation error")
        } catch let error as KajimiruError {
            if case let .validationFailed(reason) = error {
                XCTAssertEqual(reason, "Group must contain at least one admin.")
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }

        let secondAdmin = UUID()
        _ = try await service.addMember(
            groupId: group.id,
            actorId: ownerId,
            member: GroupMemberInput(userId: secondAdmin, role: .admin)
        )

        let updated = try await service.updateMemberRole(
            groupId: group.id,
            actorId: ownerId,
            memberId: ownerId,
            role: .editor
        )
        XCTAssertEqual(updated.members.first(where: { $0.userId == ownerId })?.role, .editor)
    }

    func testRemoveMemberPreventsRemovingLastAdmin() async throws {
        let adminId = UUID()
        let viewerId = UUID()
        let group = Group(
            name: "Household",
            members: [
                GroupMembership(userId: adminId, role: .admin),
                GroupMembership(userId: viewerId, role: .viewer)
            ]
        )
        let repository = InMemoryGroupRepository(groups: [group])
        let service = GroupService(groupRepository: repository)

        do {
            _ = try await service.removeMember(groupId: group.id, actorId: adminId, memberId: adminId)
            XCTFail("Expected validation error")
        } catch let error as KajimiruError {
            if case let .validationFailed(reason) = error {
                XCTAssertEqual(reason, "Group must contain at least one admin.")
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }

        let secondAdmin = UUID()
        _ = try await service.addMember(
            groupId: group.id,
            actorId: adminId,
            member: GroupMemberInput(userId: secondAdmin, role: .admin)
        )

        let updated = try await service.removeMember(groupId: group.id, actorId: adminId, memberId: adminId)
        XCTAssertEqual(updated.members.count, 2)
        XCTAssertFalse(updated.members.contains(where: { $0.userId == adminId }))
    }

    func testMemberCanLeaveGroupIfNotLastAdmin() async throws {
        let adminId = UUID()
        let editorId = UUID()
        let group = Group(
            name: "Shared",
            members: [
                GroupMembership(userId: adminId, role: .admin),
                GroupMembership(userId: editorId, role: .editor)
            ]
        )
        let repository = InMemoryGroupRepository(groups: [group])
        let service = GroupService(groupRepository: repository)

        let updated = try await service.removeMember(groupId: group.id, actorId: editorId, memberId: editorId)
        XCTAssertEqual(updated.members.count, 1)
        XCTAssertFalse(updated.members.contains(where: { $0.userId == editorId }))

        do {
            _ = try await service.removeMember(groupId: updated.id, actorId: adminId, memberId: adminId)
            XCTFail("Expected validation error")
        } catch let error as KajimiruError {
            if case let .validationFailed(reason) = error {
                XCTAssertEqual(reason, "Group must contain at least one admin.")
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }
}

import XCTest
@testable import KajimiruKit

final class GroupServiceTests: XCTestCase {
    func testCreateGroupTrimsNameAndIcon() async throws {
        let testUserId = UUID()
        let groupRepository = InMemoryGroupRepository()
        let memberRepository = InMemoryMemberRepository()
        let inviteRepository = InMemoryGroupInviteRepository()
        let service = GroupService(groupRepository: groupRepository, memberRepository: memberRepository, inviteRepository: inviteRepository)

        let draft = GroupDraft(
            name: "  My Family  ",
            icon: "  house.fill  "
        )

        let group = try await service.createGroup(draft: draft, createdBy: testUserId)
        let stored = try await groupRepository.fetchGroup(id: group.id)

        XCTAssertEqual(stored?.name, "My Family")
        XCTAssertEqual(stored?.icon, "house.fill")
        XCTAssertEqual(stored?.members.count, 0)
        XCTAssertEqual(stored?.createdBy, testUserId)
    }

    func testCreateGroupRejectsEmptyName() async throws {
        let testUserId = UUID()
        let groupRepository = InMemoryGroupRepository()
        let memberRepository = InMemoryMemberRepository()
        let inviteRepository = InMemoryGroupInviteRepository()
        let service = GroupService(groupRepository: groupRepository, memberRepository: memberRepository, inviteRepository: inviteRepository)

        let draft = GroupDraft(name: "   ", icon: nil)

        do {
            _ = try await service.createGroup(draft: draft, createdBy: testUserId)
            XCTFail("Expected validation error")
        } catch let error as KajimiruError {
            if case let .validationFailed(reason) = error {
                XCTAssertEqual(reason, "Group name must not be empty.")
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testUpdateGroupMetadata() async throws {
        let testUserId = UUID()
        let group = Group(
            name: "Original Name",
            icon: "old.icon",
            members: [],
            createdBy: testUserId,
            updatedBy: testUserId
        )
        let groupRepository = InMemoryGroupRepository(groups: [group])
        let memberRepository = InMemoryMemberRepository()
        let inviteRepository = InMemoryGroupInviteRepository()
        let service = GroupService(groupRepository: groupRepository, memberRepository: memberRepository, inviteRepository: inviteRepository)

        let updated = try await service.updateGroup(
            groupId: group.id,
            name: "  New Name  ",
            icon: Optional<String?>.some(nil),
            updatedBy: testUserId
        )

        XCTAssertEqual(updated.name, "New Name")
        XCTAssertNil(updated.icon)
        XCTAssertEqual(updated.updatedBy, testUserId)
        XCTAssertGreaterThan(updated.updatedAt, group.updatedAt)
    }

    func testAddMemberToGroup() async throws {
        let testUserId = UUID()
        let group = Group(
            name: "Test Group",
            members: [],
            createdBy: testUserId,
            updatedBy: testUserId
        )
        let groupRepository = InMemoryGroupRepository(groups: [group])
        let memberRepository = InMemoryMemberRepository()
        let inviteRepository = InMemoryGroupInviteRepository()
        let service = GroupService(groupRepository: groupRepository, memberRepository: memberRepository, inviteRepository: inviteRepository)

        let memberDraft = MemberDraft(
            displayName: "  John Doe  ",
            userId: UUID()
        )

        let member = try await service.addMember(
            groupId: group.id,
            draft: memberDraft,
            createdBy: testUserId
        )

        XCTAssertEqual(member.displayName, "John Doe")
        XCTAssertEqual(member.groupId, group.id)
        XCTAssertEqual(member.role, MemberRole.member)
        XCTAssertEqual(member.createdBy, testUserId)

        // Verify group's member list was updated
        let updatedGroup = try await groupRepository.fetchGroup(id: group.id)
        XCTAssertEqual(updatedGroup?.members.count, 1)
        XCTAssertEqual(updatedGroup?.members.first?.id, member.id)

        // Verify member can be listed
        let members = try await service.listMembers(in: group.id)
        XCTAssertEqual(members.count, 1)
        XCTAssertEqual(members.first?.id, member.id)
    }

    func testAddMemberRejectsEmptyDisplayName() async throws {
        let testUserId = UUID()
        let group = Group(
            name: "Test Group",
            members: [],
            createdBy: testUserId,
            updatedBy: testUserId
        )
        let groupRepository = InMemoryGroupRepository(groups: [group])
        let memberRepository = InMemoryMemberRepository()
        let inviteRepository = InMemoryGroupInviteRepository()
        let service = GroupService(groupRepository: groupRepository, memberRepository: memberRepository, inviteRepository: inviteRepository)

        let memberDraft = MemberDraft(displayName: "   ", userId: nil)

        do {
            _ = try await service.addMember(
                groupId: group.id,
                draft: memberDraft,
                createdBy: testUserId
            )
            XCTFail("Expected validation error")
        } catch let error as KajimiruError {
            if case let .validationFailed(reason) = error {
                XCTAssertEqual(reason, "Member display name must not be empty.")
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testUpdateMemberDisplayName() async throws {
        let testUserId = UUID()
        let member = Member(
            displayName: "Original Name",
            groupId: UUID(),
            role: .member,
            createdBy: testUserId,
            updatedBy: testUserId
        )
        let groupRepository = InMemoryGroupRepository()
        let memberRepository = InMemoryMemberRepository(members: [member])
        let inviteRepository = InMemoryGroupInviteRepository()
        let service = GroupService(groupRepository: groupRepository, memberRepository: memberRepository, inviteRepository: inviteRepository)

        let updated = try await service.updateMember(
            memberId: member.id,
            displayName: "New Name",
            updatedBy: testUserId
        )

        XCTAssertEqual(updated.displayName, "New Name")
        XCTAssertEqual(updated.updatedBy, testUserId)
        XCTAssertGreaterThan(updated.updatedAt, member.updatedAt)
    }

    func testDeleteMemberSoftDeletes() async throws {
        let testUserId = UUID()
        let group = Group(
            name: "Test Group",
            members: [],
            createdBy: testUserId,
            updatedBy: testUserId
        )
        let member = Member(
            displayName: "John Doe",
            groupId: group.id,
            role: .member,
            createdBy: testUserId,
            updatedBy: testUserId
        )

        let groupRepository = InMemoryGroupRepository(groups: [group])
        let memberRepository = InMemoryMemberRepository(members: [member])
        let inviteRepository = InMemoryGroupInviteRepository()
        let service = GroupService(groupRepository: groupRepository, memberRepository: memberRepository, inviteRepository: inviteRepository)

        // Add member to group's member list
        var updatedGroup = group
        updatedGroup = updatedGroup.updating(members: [member], updatedBy: testUserId)
        try await groupRepository.save(updatedGroup)

        try await service.deleteMember(
            groupId: group.id,
            memberId: member.id,
            deletedBy: testUserId
        )

        let storedMember = try await memberRepository.fetchMember(id: member.id)
        XCTAssertNotNil(storedMember?.deletedAt)
        XCTAssertEqual(storedMember?.deletedBy, testUserId)

        // Verify group's member list was updated with soft-deleted member
        let groupAfterDelete = try await groupRepository.fetchGroup(id: group.id)
        XCTAssertEqual(groupAfterDelete?.members.count, 1)
        XCTAssertNotNil(groupAfterDelete?.members.first?.deletedAt)

        // Verify member is excluded from list when not including deleted
        let activeMembers = try await service.listMembers(in: group.id, includeDeleted: false)
        XCTAssertEqual(activeMembers.count, 0)

        // Verify member is included when including deleted
        let allMembers = try await service.listMembers(in: group.id, includeDeleted: true)
        XCTAssertEqual(allMembers.count, 1)
    }

    func testLinkMemberToFirebaseAuth() async throws {
        let testUserId = UUID()
        let newUserId = UUID()
        let firebaseUid = "test-firebase-uid"
        let groupId = UUID()

        // Create an unlinked member (no firebaseUid)
        let member = Member(
            displayName: "Unlinked User",
            groupId: groupId,
            role: .member,
            createdBy: testUserId,
            updatedBy: testUserId
        )

        let groupRepository = InMemoryGroupRepository()
        let memberRepository = InMemoryMemberRepository(members: [member])
        let inviteRepository = InMemoryGroupInviteRepository()
        let service = GroupService(groupRepository: groupRepository, memberRepository: memberRepository, inviteRepository: inviteRepository)

        // Link the member to Firebase Auth
        let linkedMember = try await service.linkMemberToFirebaseAuth(
            memberId: member.id,
            groupId: groupId,
            firebaseUid: firebaseUid,
            userId: newUserId,
            updatedBy: newUserId
        )

        // Verify the member was linked
        XCTAssertEqual(linkedMember.id, member.id)
        XCTAssertEqual(linkedMember.firebaseUid, firebaseUid)
        XCTAssertEqual(linkedMember.userId, newUserId)
        XCTAssertEqual(linkedMember.displayName, member.displayName)
        XCTAssertEqual(linkedMember.updatedBy, newUserId)
        XCTAssertGreaterThan(linkedMember.updatedAt, member.updatedAt)

        // Verify the linked member is stored
        let storedMember = try await memberRepository.fetchMember(id: member.id)
        XCTAssertEqual(storedMember?.firebaseUid, firebaseUid)
        XCTAssertEqual(storedMember?.userId, newUserId)
    }

    func testLinkMemberToFirebaseAuthRejectsAlreadyLinked() async throws {
        let testUserId = UUID()
        let existingFirebaseUid = "existing-firebase-uid"
        let groupId = UUID()

        // Create a member already linked to Firebase Auth
        let member = Member(
            userId: UUID(),
            firebaseUid: existingFirebaseUid,
            displayName: "Already Linked User",
            groupId: groupId,
            role: .member,
            createdBy: testUserId,
            updatedBy: testUserId
        )

        let groupRepository = InMemoryGroupRepository()
        let memberRepository = InMemoryMemberRepository(members: [member])
        let inviteRepository = InMemoryGroupInviteRepository()
        let service = GroupService(groupRepository: groupRepository, memberRepository: memberRepository, inviteRepository: inviteRepository)

        // Try to link the already-linked member
        do {
            _ = try await service.linkMemberToFirebaseAuth(
                memberId: member.id,
                groupId: groupId,
                firebaseUid: "new-firebase-uid",
                userId: UUID(),
                updatedBy: testUserId
            )
            XCTFail("Expected validation error")
        } catch let error as KajimiruError {
            if case let .validationFailed(reason) = error {
                XCTAssertEqual(reason, "このメンバーは既に認証されています")
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testLinkMemberToFirebaseAuthNotFound() async throws {
        let testUserId = UUID()
        let nonExistentMemberId = UUID()
        let groupId = UUID()

        let groupRepository = InMemoryGroupRepository()
        let memberRepository = InMemoryMemberRepository()
        let inviteRepository = InMemoryGroupInviteRepository()
        let service = GroupService(groupRepository: groupRepository, memberRepository: memberRepository, inviteRepository: inviteRepository)

        // Try to link a non-existent member
        do {
            _ = try await service.linkMemberToFirebaseAuth(
                memberId: nonExistentMemberId,
                groupId: groupId,
                firebaseUid: "firebase-uid",
                userId: UUID(),
                updatedBy: testUserId
            )
            XCTFail("Expected not found error")
        } catch let error as KajimiruError {
            if case .notFound = error {
                // Expected
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }
}

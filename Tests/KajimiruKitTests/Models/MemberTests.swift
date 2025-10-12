import XCTest
@testable import KajimiruKit

final class MemberTests: XCTestCase {
    func testUpdatingDisplayName() {
        let testUserId = "test-user-id"
        let member = Member(
            displayName: "Original Name",
            groupId: UUID(),
            role: .member,
            createdBy: testUserId,
            updatedBy: testUserId
        )

        let updated = member.updating(
            displayName: "New Name",
            updatedBy: testUserId
        )

        XCTAssertEqual(updated.id, member.id)
        XCTAssertEqual(updated.displayName, "New Name")
        XCTAssertEqual(updated.updatedBy, testUserId)
        XCTAssertGreaterThan(updated.updatedAt, member.updatedAt)

        // Verify other fields remain unchanged
        XCTAssertEqual(updated.groupId, member.groupId)
        XCTAssertEqual(updated.role, member.role)
        XCTAssertEqual(updated.userId, member.userId)
    }

    func testUpdatingAvatarURL() {
        let testUserId = "test-user-id"
        let member = Member(
            displayName: "Test User",
            avatarURL: nil,
            groupId: UUID(),
            role: .member,
            createdBy: testUserId,
            updatedBy: testUserId
        )

        let newAvatarURL = URL(string: "https://example.com/avatar.jpg")!
        let updated = member.updating(
            avatarURL: newAvatarURL,
            updatedBy: testUserId
        )

        XCTAssertEqual(updated.avatarURL, newAvatarURL)
        XCTAssertEqual(updated.displayName, member.displayName)
    }

    func testUpdatingUserId() {
        let testUserId = "test-user-id"
        let member = Member(
            userId: nil,
            displayName: "Unlinked User",
            groupId: UUID(),
            role: .member,
            createdBy: testUserId,
            updatedBy: testUserId
        )

        let newUserId = "new-firebase-uid"

        let linked = member.updating(
            userId: newUserId,
            updatedBy: newUserId
        )

        // Verify linking fields are updated
        XCTAssertEqual(linked.userId, newUserId)
        XCTAssertEqual(linked.updatedBy, newUserId)
        XCTAssertGreaterThanOrEqual(linked.updatedAt, member.updatedAt)

        // Verify other fields remain unchanged
        XCTAssertEqual(linked.id, member.id)
        XCTAssertEqual(linked.displayName, member.displayName)
        XCTAssertEqual(linked.groupId, member.groupId)
        XCTAssertEqual(linked.role, member.role)
        XCTAssertEqual(linked.avatarURL, member.avatarURL)
        XCTAssertEqual(linked.createdAt, member.createdAt)
        XCTAssertEqual(linked.createdBy, member.createdBy)
        XCTAssertNil(linked.deletedAt)
        XCTAssertNil(linked.deletedBy)
    }

    func testSoftDeleting() {
        let testUserId = "test-user-id"
        let member = Member(
            displayName: "Test User",
            groupId: UUID(),
            role: .member,
            createdBy: testUserId,
            updatedBy: testUserId
        )

        XCTAssertFalse(member.isDeleted)

        let deleted = member.softDeleting(deletedBy: testUserId)

        XCTAssertTrue(deleted.isDeleted)
        XCTAssertNotNil(deleted.deletedAt)
        XCTAssertEqual(deleted.deletedBy, testUserId)

        // Verify other fields remain unchanged
        XCTAssertEqual(deleted.id, member.id)
        XCTAssertEqual(deleted.displayName, member.displayName)
        XCTAssertEqual(deleted.groupId, member.groupId)
    }

    func testMemberIsDeletedProperty() {
        let testUserId = "test-user-id"

        // Test active member
        let activeMember = Member(
            displayName: "Active User",
            groupId: UUID(),
            role: .member,
            createdBy: testUserId,
            updatedBy: testUserId
        )
        XCTAssertFalse(activeMember.isDeleted)

        // Test deleted member
        let deletedMember = Member(
            displayName: "Deleted User",
            groupId: UUID(),
            role: .member,
            createdBy: testUserId,
            updatedBy: testUserId,
            deletedAt: Date(),
            deletedBy: testUserId
        )
        XCTAssertTrue(deletedMember.isDeleted)
    }

    func testMemberCodable() throws {
        let testUserId = "test-user-id"
        let member = Member(
            userId: "firebase-uid-123",
            displayName: "Test User",
            avatarURL: URL(string: "https://example.com/avatar.jpg"),
            groupId: UUID(),
            role: .admin,
            createdBy: testUserId,
            updatedBy: testUserId
        )

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(member)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Member.self, from: data)

        // Verify all fields match
        XCTAssertEqual(decoded.id, member.id)
        XCTAssertEqual(decoded.userId, member.userId)
        XCTAssertEqual(decoded.displayName, member.displayName)
        XCTAssertEqual(decoded.avatarURL, member.avatarURL)
        XCTAssertEqual(decoded.groupId, member.groupId)
        XCTAssertEqual(decoded.role, member.role)
        XCTAssertEqual(decoded.createdBy, member.createdBy)
        XCTAssertEqual(decoded.updatedBy, member.updatedBy)
    }

    func testMemberWithNullableFields() throws {
        let testUserId = "test-user-id"
        let member = Member(
            userId: nil,
            displayName: "Unlinked User",
            avatarURL: nil,
            groupId: UUID(),
            role: .member,
            createdBy: testUserId,
            updatedBy: testUserId
        )

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(member)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Member.self, from: data)

        // Verify nullable fields are nil
        XCTAssertNil(decoded.userId)
        XCTAssertNil(decoded.avatarURL)
        XCTAssertNil(decoded.deletedAt)
        XCTAssertNil(decoded.deletedBy)

        // Verify non-nullable fields
        XCTAssertEqual(decoded.id, member.id)
        XCTAssertEqual(decoded.displayName, member.displayName)
        XCTAssertEqual(decoded.groupId, member.groupId)
    }
}

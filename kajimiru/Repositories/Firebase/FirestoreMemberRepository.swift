import Foundation
import FirebaseFirestore
import KajimiruKit

/// Firestore implementation of MemberRepository
actor FirestoreMemberRepository: MemberRepository {
    private let db = Firestore.firestore()

    private func membersCollection(groupId: UUID) -> CollectionReference {
        db.collection("groups").document(groupId.uuidString).collection("members")
    }

    func listMembers(in groupId: UUID, includeDeleted: Bool) async throws -> [Member] {
        let query: Query = membersCollection(groupId: groupId)
        let snapshot = try await query.getDocuments()

        let members = snapshot.documents.compactMap { doc -> Member? in
            guard let member = try? doc.data(as: Member.self) else {
                return nil
            }

            // Filter deleted members if needed
            if !includeDeleted && member.isDeleted {
                return nil
            }

            return member
        }

        return members
    }

    func fetchMember(id: UUID) async throws -> Member? {
        // Need to search across all groups - this is inefficient
        // In practice, you'd maintain a groupId context
        // For now, throw an error indicating this method needs groupId
        throw NSError(domain: "FirestoreMemberRepository", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "fetchMember requires groupId context. Use listMembers instead."
        ])
    }

    func save(_ member: Member) async throws {
        let docRef = membersCollection(groupId: member.groupId).document(member.id.uuidString)

        // Convert member to dictionary to explicitly handle null values
        var data: [String: Any] = [
            "id": member.id.uuidString,
            "displayName": member.displayName,
            "groupId": member.groupId.uuidString,
            "role": member.role.rawValue,
            "createdAt": Timestamp(date: member.createdAt),
            "createdBy": member.createdBy,
            "updatedAt": Timestamp(date: member.updatedAt),
            "updatedBy": member.updatedBy
        ]

        // Optional fields - use NSNull for nil values to ensure field exists in Firestore
        data["userId"] = member.userId ?? NSNull()
        data["avatarURL"] = member.avatarURL?.absoluteString ?? NSNull()
        data["deletedAt"] = member.deletedAt.map { Timestamp(date: $0) } ?? NSNull()
        data["deletedBy"] = member.deletedBy ?? NSNull()

        try await docRef.setData(data)
    }

    func softDeleteMember(id: UUID, in groupId: UUID, deletedBy: String) async throws {
        let docRef = membersCollection(groupId: groupId).document(id.uuidString)

        try await docRef.updateData([
            "isDeleted": true,
            "deletedAt": Timestamp(date: Date()),
            "deletedBy": deletedBy
        ])
    }

    /// List all groups that a user belongs to by their Firebase UID
    func listGroupsForUser(firebaseUid: String) async throws -> [UUID] {
        var groupIds: [UUID] = []
        let groupsSnapshot = try await db.collection("groups").getDocuments()
        for groupDoc in groupsSnapshot.documents {
            let groupId = UUID(uuidString: groupDoc.documentID)!
            let memberDocs = try await db.collection("groups")
                .document(groupId.uuidString)
                .collection("members")
                .whereField("userId", isEqualTo: firebaseUid)
                .getDocuments()

            for doc in memberDocs.documents {
                if doc.exists {
                    if let member = try? doc.data(as: Member.self) {
                        if member.deletedAt == nil {
                            groupIds.append(groupId)
                        }
                    }
                }
            }
        }

        return groupIds
    }
}

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
        // For members with firebaseUid (linked to Firebase Auth), use firebaseUid as document ID
        // For members without firebaseUid (non-authenticated members), use member.id
        let docId: String
        if let firebaseUid = member.firebaseUid {
            docId = firebaseUid
        } else {
            docId = member.id.uuidString
        }

        let docRef = membersCollection(groupId: member.groupId).document(docId)
        try docRef.setData(from: member)
    }

    func softDeleteMember(id: UUID, in groupId: UUID, deletedBy: UUID) async throws {
        let docRef = membersCollection(groupId: groupId).document(id.uuidString)

        try await docRef.updateData([
            "isDeleted": true,
            "deletedAt": Timestamp(date: Date()),
            "deletedBy": deletedBy.uuidString
        ])
    }

    /// List all groups that a user belongs to by their Firebase UID
    func listGroupsForUser(firebaseUid: String) async throws -> [UUID] {
        // Strategy: Search for member documents where:
        // 1. Document ID matches firebaseUid (new members)
        // 2. Or traverse all groups to find members (fallback for old data)

        var groupIds: [UUID] = []

        // First, try to find all groups
        let groupsSnapshot = try await db.collection("groups").getDocuments()

        for groupDoc in groupsSnapshot.documents {
            guard let groupId = UUID(uuidString: groupDoc.documentID) else {
                continue
            }

            // Check if this group has a member with matching firebaseUid
            let memberDoc = try await db.collection("groups")
                .document(groupDoc.documentID)
                .collection("members")
                .document(firebaseUid)
                .getDocument()

            if memberDoc.exists {
                if let member = try? memberDoc.data(as: Member.self) {
                    if member.deletedAt == nil {
                        groupIds.append(groupId)
                    }
                }
            }
        }

        return groupIds
    }
}

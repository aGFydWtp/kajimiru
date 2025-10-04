import Foundation
import FirebaseFirestore
import KajimiruKit

/// Firestore implementation of GroupInviteRepository
actor FirestoreGroupInviteRepository: GroupInviteRepository {
    private let db = Firestore.firestore()

    private var invitesCollection: CollectionReference {
        db.collection("groupInvites")
    }

    func fetchInvite(code: String) async throws -> GroupInvite? {
        let snapshot = try await invitesCollection
            .whereField("code", isEqualTo: code)
            .whereField("isActive", isEqualTo: true)
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first else {
            return nil
        }

        return try document.data(as: GroupInvite.self)
    }

    func listInvites(for groupId: UUID) async throws -> [GroupInvite] {
        let snapshot = try await invitesCollection
            .whereField("groupId", isEqualTo: groupId.uuidString)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: GroupInvite.self)
        }
    }

    func save(_ invite: GroupInvite) async throws {
        try invitesCollection.document(invite.id.uuidString).setData(from: invite)
    }

    func deleteInvite(id: UUID) async throws {
        try await invitesCollection.document(id.uuidString).delete()
    }
}

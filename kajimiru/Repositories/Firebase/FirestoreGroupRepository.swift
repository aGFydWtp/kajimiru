import Foundation
import FirebaseFirestore
import KajimiruKit

/// Firestore implementation of GroupRepository
actor FirestoreGroupRepository: GroupRepository {
    private let db = Firestore.firestore()

    private var groupsCollection: CollectionReference {
        db.collection("groups")
    }

    func fetchGroup(id: UUID) async throws -> Group? {
        let document = try await groupsCollection.document(id.uuidString).getDocument()

        guard document.exists else {
            return nil
        }

        return try document.data(as: Group.self)
    }

    func save(_ group: Group) async throws {
        try groupsCollection.document(group.id.uuidString).setData(from: group)
    }
}

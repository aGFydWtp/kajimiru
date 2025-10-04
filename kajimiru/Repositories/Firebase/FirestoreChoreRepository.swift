import Foundation
import FirebaseFirestore
import KajimiruKit

/// Firestore implementation of ChoreRepository
actor FirestoreChoreRepository: ChoreRepository, FirestoreChoreRepositoryProtocol {
    private let db = Firestore.firestore()

    private func choresCollection(groupId: UUID) -> CollectionReference {
        db.collection("groups").document(groupId.uuidString).collection("chores")
    }

    func listChores(in groupId: UUID, includeDeleted: Bool) async throws -> [Chore] {
        let query: Query = choresCollection(groupId: groupId)
        let snapshot = try await query.getDocuments()

        let chores = snapshot.documents.compactMap { doc -> Chore? in
            guard let chore = try? doc.data(as: Chore.self) else {
                return nil
            }

            let isDeleted = chore.deletedAt != nil

            if !includeDeleted && isDeleted {
                return nil
            }

            return chore
        }

        return chores
    }

    func fetchChore(id: UUID) async throws -> Chore? {
        // Firestore chores are stored as subcollections under groups
        // Without groupId, we cannot efficiently query
        // Caller should use fetchChore(id:in:) instead
        throw NSError(domain: "FirestoreChoreRepository", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "fetchChore requires groupId context. Use fetchChore(id:in:) or listChores."
        ])
    }

    // Fetch a chore by ID within a specific group
    func fetchChore(id: UUID, in groupId: UUID) async throws -> Chore? {
        let docRef = choresCollection(groupId: groupId).document(id.uuidString)
        let snapshot = try await docRef.getDocument()
        return try snapshot.data(as: Chore.self)
    }

    func save(_ chore: Chore) async throws {
        let docRef = choresCollection(groupId: chore.groupId).document(chore.id.uuidString)
        try docRef.setData(from: chore)
    }
}

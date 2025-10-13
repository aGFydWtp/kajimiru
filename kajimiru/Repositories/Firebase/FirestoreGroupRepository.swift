import Foundation
import FirebaseFirestore
import KajimiruKit

/// Firestore implementation of GroupRepository
actor FirestoreGroupRepository: GroupRepository {
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

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

    func deleteGroup(id: UUID) async throws {
        try await groupsCollection.document(id.uuidString).delete()
    }

    /// Start listening to real-time updates for a specific group
    func observeGroup(
        id: UUID,
        onChange: @escaping @Sendable (Group?) -> Void
    ) {
        listener?.remove()
        listener = groupsCollection.document(id.uuidString).addSnapshotListener { snapshot, error in
            guard let snapshot = snapshot else {
                print("Error fetching group: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            if !snapshot.exists {
                // Group was deleted
                onChange(nil)
                return
            }

            guard let group = try? snapshot.data(as: Group.self) else {
                print("Failed to decode group document: \(snapshot.documentID)")
                return
            }

            onChange(group)
        }
    }

    /// Stop listening to real-time updates
    func stopObserving() {
        listener?.remove()
        listener = nil
    }
}

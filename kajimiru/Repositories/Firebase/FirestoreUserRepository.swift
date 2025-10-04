import Foundation
import FirebaseFirestore
import KajimiruKit

/// Firestore implementation of UserRepository
actor FirestoreUserRepository: UserRepository {
    private let db = Firestore.firestore()

    private var usersCollection: CollectionReference {
        db.collection("users")
    }

    func fetchUsers(ids: [UUID]) async throws -> [User] {
        guard !ids.isEmpty else {
            return []
        }

        // Firestore has a limit of 10 items for 'in' queries
        // If more than 10 users, split into multiple queries
        let chunks = ids.chunked(into: 10)
        var allUsers: [User] = []

        for chunk in chunks {
            // Query by firebaseUid field instead of document ID
            let stringIds = chunk.map { $0.uuidString }
            let snapshot = try await usersCollection
                .whereField("firebaseUid", in: stringIds)
                .getDocuments()

            let users = try snapshot.documents.compactMap { try $0.data(as: User.self) }
            allUsers.append(contentsOf: users)
        }

        return allUsers
    }

    // Fetch user by Firebase UID (for authentication flow)
    func fetchUserByFirebaseUid(_ firebaseUid: String) async throws -> User? {
        let doc = try await usersCollection.document(firebaseUid).getDocument()
        return try doc.data(as: User.self)
    }

    func save(_ user: User) async throws {
        // Use Firebase UID as document ID for security rules
        try usersCollection.document(user.firebaseUid).setData(from: user)
    }
}

// MARK: - Array Extension for Chunking

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

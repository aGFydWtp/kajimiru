import Foundation
import FirebaseFirestore
import KajimiruKit

/// Firestore implementation of ChoreLogRepository
actor FirestoreChoreLogRepository: ChoreLogRepository {
    private let db = Firestore.firestore()

    private func choreLogsCollection(groupId: UUID) -> CollectionReference {
        db.collection("groups").document(groupId.uuidString).collection("choreLogs")
    }

    func listLogs(in groupId: UUID, since date: Date?) async throws -> [ChoreLog] {
        var query: Query = choreLogsCollection(groupId: groupId)

        // Apply date filter if provided
        if let sinceDate = date {
            query = query.whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: sinceDate))
        }

        // Order by creation date descending
        query = query.order(by: "createdAt", descending: true)

        let snapshot = try await query.getDocuments()

        let logs = snapshot.documents.compactMap { doc -> ChoreLog? in
            try? doc.data(as: ChoreLog.self)
        }

        return logs
    }

    func save(_ log: ChoreLog) async throws {
        let docRef = choreLogsCollection(groupId: log.groupId).document(log.id.uuidString)
        try docRef.setData(from: log)
    }

    func deleteLog(id: UUID, in groupId: UUID) async throws {
        let docRef = choreLogsCollection(groupId: groupId).document(id.uuidString)
        try await docRef.delete()
    }
}

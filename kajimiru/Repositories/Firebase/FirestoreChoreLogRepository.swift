import Foundation
import FirebaseFirestore
import KajimiruKit

/// Firestore implementation of ChoreLogRepository
actor FirestoreChoreLogRepository: ChoreLogRepository {
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

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

    /// Start listening to real-time updates for chore logs in a group
    func observeLogs(
        in groupId: UUID,
        since date: Date?,
        onChange: @escaping @Sendable ([ChoreLog]) -> Void
    ) {
        var query: Query = db.collection("groups")
            .document(groupId.uuidString)
            .collection("choreLogs")

        if let sinceDate = date {
            query = query.whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: sinceDate))
        }

        query = query.order(by: "createdAt", descending: true)

        listener?.remove()
        listener = query.addSnapshotListener { snapshot, error in
            guard let snapshot = snapshot else {
                print("Error fetching chore logs: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            let logs = snapshot.documents.compactMap { doc -> ChoreLog? in
                guard let log = try? doc.data(as: ChoreLog.self) else {
                    print("Failed to decode chore log document: \(doc.documentID)")
                    return nil
                }
                return log
            }

            onChange(logs)
        }
    }

    /// Stop listening to real-time updates
    func stopObserving() {
        listener?.remove()
        listener = nil
    }
}

import XCTest
import FirebaseCore
import FirebaseFirestore
@testable import KajimiruKit

/// Integration tests for Firestore emulator
final class FirestoreEmulatorTests: XCTestCase {

    override class func setUp() {
        super.setUp()

        // Initialize Firebase only once
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        // Configure Firestore to use emulator
        let settings = Firestore.firestore().settings
        settings.host = "127.0.0.1:8081"
        settings.cacheSettings = MemoryCacheSettings()
        settings.isSSLEnabled = false
        Firestore.firestore().settings = settings

        print("🔧 Firestore configured to use emulator at \(settings.host)")
    }

    override func setUp() async throws {
        try await super.setUp()

        // Clear test data before each test
        let db = Firestore.firestore()
        let collections = ["groups", "chores", "choreLogs", "users", "members"]

        for collectionName in collections {
            let snapshot = try await db.collection(collectionName).getDocuments()
            for document in snapshot.documents {
                try await document.reference.delete()
            }
        }
    }

    func testEmulatorConnection() async throws {
        let db = Firestore.firestore()
        let testDoc = db.collection("test").document("connection")

        // Test write
        try await testDoc.setData(["status": "connected", "timestamp": FieldValue.serverTimestamp()])

        // Test read
        let snapshot = try await testDoc.getDocument()
        XCTAssertTrue(snapshot.exists, "Document should exist")
        XCTAssertEqual(snapshot.data()?["status"] as? String, "connected")

        print("✅ Successfully connected to Firestore emulator")
    }

    func testGroupRepository() async throws {
        // This test will verify the actual FirestoreGroupRepository works with the emulator
        // You'll need to import and test the actual repository implementation

        let db = Firestore.firestore()
        let groupsCollection = db.collection("groups")

        let testGroup = Group(
            id: UUID(),
            name: "Test Family",
            createdAt: Date(),
            updatedAt: Date()
        )

        // Save group
        try groupsCollection.document(testGroup.id.uuidString).setData(from: testGroup)

        // Fetch group
        let document = try await groupsCollection.document(testGroup.id.uuidString).getDocument()
        let fetchedGroup = try document.data(as: Group.self)

        XCTAssertEqual(fetchedGroup.id, testGroup.id)
        XCTAssertEqual(fetchedGroup.name, testGroup.name)

        print("✅ Group repository test passed")
    }
}

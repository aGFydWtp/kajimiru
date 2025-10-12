import Foundation

/// Represents an application user who can belong to one or more groups.
/// Note: The document ID in Firestore is the Firebase Authentication UID.
public struct User: Identifiable, Codable, Hashable, Sendable {
    public let id: String  // Firebase Authentication UID - used as Firestore document ID
    public var displayName: String
    public var email: String?
    public var avatarURL: URL?
    public var currentGroupId: UUID?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,  // Firebase Authentication UID
        displayName: String,
        email: String? = nil,
        avatarURL: URL? = nil,
        currentGroupId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.avatarURL = avatarURL
        self.currentGroupId = currentGroupId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

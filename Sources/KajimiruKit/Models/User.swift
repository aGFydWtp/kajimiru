import Foundation

/// Represents an application user who can belong to one or more groups.
public struct User: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let firebaseUid: String  // Firebase Authentication UID
    public var displayName: String
    public var email: String?
    public var avatarURL: URL?
    public var currentGroupId: UUID?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        firebaseUid: String,
        displayName: String,
        email: String? = nil,
        avatarURL: URL? = nil,
        currentGroupId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.firebaseUid = firebaseUid
        self.displayName = displayName
        self.email = email
        self.avatarURL = avatarURL
        self.currentGroupId = currentGroupId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

import Foundation

/// Represents an application user who can belong to one or more groups.
public struct User: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var displayName: String
    public var email: String?
    public var avatarURL: URL?

    public init(id: UUID = UUID(), displayName: String, email: String? = nil, avatarURL: URL? = nil) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.avatarURL = avatarURL
    }
}

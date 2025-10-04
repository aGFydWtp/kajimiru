import Foundation

/// Represents an invitation code for joining a group
public struct GroupInvite: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let groupId: UUID
    public let code: String  // Short, shareable code (e.g., "ABC1-XYZ9")
    public var expiresAt: Date?
    public var maxUses: Int?  // nil = unlimited
    public var currentUses: Int
    public var isActive: Bool
    public var createdAt: Date
    public var createdBy: UUID

    public init(
        id: UUID = UUID(),
        groupId: UUID,
        code: String,
        expiresAt: Date? = nil,
        maxUses: Int? = nil,
        currentUses: Int = 0,
        isActive: Bool = true,
        createdAt: Date = Date(),
        createdBy: UUID
    ) {
        self.id = id
        self.groupId = groupId
        self.code = code
        self.expiresAt = expiresAt
        self.maxUses = maxUses
        self.currentUses = currentUses
        self.isActive = isActive
        self.createdAt = createdAt
        self.createdBy = createdBy
    }

    /// Check if the invite code is valid for use
    public var isValid: Bool {
        guard isActive else { return false }

        // Check expiration
        if let expiresAt = expiresAt, Date() > expiresAt {
            return false
        }

        // Check max uses
        if let maxUses = maxUses, currentUses >= maxUses {
            return false
        }

        return true
    }

    /// Returns a new invite with incremented use count
    public func incrementUses() -> GroupInvite {
        var copy = self
        copy.currentUses += 1
        return copy
    }

    /// Returns a new invite marked as inactive
    public func deactivate() -> GroupInvite {
        var copy = self
        copy.isActive = false
        return copy
    }

    /// Generate a random invite code in format "XXXX-YYYY" (8 characters + hyphen)
    public static func generateCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  // Exclude ambiguous chars
        let part1 = String((0..<4).map { _ in characters.randomElement()! })
        let part2 = String((0..<4).map { _ in characters.randomElement()! })
        return "\(part1)-\(part2)"
    }
}

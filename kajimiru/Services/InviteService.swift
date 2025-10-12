import Foundation
import FirebaseFunctions
import KajimiruKit

/// Service for managing group invitations using Cloud Functions
@MainActor
class InviteService: ObservableObject {

    private nonisolated let functions: Functions

    init() {
        self.functions = Functions.functions()
    }

    // MARK: - Data Types

    struct MemberInfo: Codable {
        let id: String
        let name: String
    }

    struct GetMembersResponse: Codable {
        let userConnectedMembers: [MemberInfo]
        let nonConnectedMembers: [MemberInfo]
    }

    struct AddMemberRequest: Codable {
        let code: String
        let newMember: NewMember

        struct NewMember: Codable {
            let id: String?  // nil = create new, non-nil = link existing
            let name: String
            let userId: String
            let firebaseUid: String
        }
    }

    struct AddMemberResponse: Codable {
        let success: Bool
        let memberId: String
        let groupId: String
    }

    // MARK: - Public Methods

    /// Get group members by invite code
    /// - Parameter code: The invite code
    /// - Returns: Members categorized by connection status
    nonisolated func getGroupMembers(byInviteCode code: String) async throws -> GetMembersResponse {
        let callable = functions.httpsCallable("getGroupMembersByInviteCode")

        do {
            let result = try await callable.call(["code": code])

            guard let data = result.data as? [String: Any] else {
                throw InviteError.invalidResponse
            }

            let jsonData = try JSONSerialization.data(withJSONObject: data)
            let response = try JSONDecoder().decode(GetMembersResponse.self, from: jsonData)

            return response
        } catch let error as NSError {
            throw mapFunctionsError(error)
        }
    }

    /// Add or link a member using invite code
    /// - Parameters:
    ///   - code: The invite code
    ///   - memberId: Optional existing member ID to link (nil = create new)
    ///   - memberName: Display name for the member
    ///   - userId: The user's UUID
    ///   - firebaseUid: The Firebase Auth UID
    /// - Returns: Response with success status, member ID, and group ID
    nonisolated func addMember(
        withInviteCode code: String,
        existingMemberId: UUID?,
        memberName: String,
        firebaseUid: String
    ) async throws -> AddMemberResponse {
        let callable = functions.httpsCallable("addGroupMemberByInviteCode")

        let request: [String: Any] = [
            "code": code,
            "newMember": [
                "id": existingMemberId?.uuidString as Any,
                "name": memberName,
                "firebaseUid": firebaseUid
            ]
        ]

        do {
            let result = try await callable.call(request)

            guard let data = result.data as? [String: Any] else {
                throw InviteError.invalidResponse
            }

            let jsonData = try JSONSerialization.data(withJSONObject: data)
            let response = try JSONDecoder().decode(AddMemberResponse.self, from: jsonData)

            return response
        } catch let error as NSError {
            throw mapFunctionsError(error)
        }
    }

    // MARK: - Error Mapping

    private nonisolated func mapFunctionsError(_ error: NSError) -> InviteError {
        guard error.domain == "com.firebase.functions" else {
            return .unknown(error.localizedDescription)
        }

        let code = FunctionsErrorCode(rawValue: error.code)
        let message = error.userInfo["message"] as? String ?? error.localizedDescription

        switch code {
        case .unauthenticated:
            return .unauthenticated
        case .notFound:
            return .inviteNotFound
        case .alreadyExists:
            return .alreadyMember
        case .failedPrecondition:
            return .invalidInvite(message)
        case .invalidArgument:
            return .invalidArgument(message)
        case .permissionDenied:
            return .permissionDenied
        default:
            return .unknown(message)
        }
    }
}

// MARK: - Errors

enum InviteError: LocalizedError {
    case unauthenticated
    case inviteNotFound
    case alreadyMember
    case invalidInvite(String)
    case invalidArgument(String)
    case permissionDenied
    case invalidResponse
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            return "認証が必要です"
        case .inviteNotFound:
            return "招待コードが見つかりません"
        case .alreadyMember:
            return "既にこのグループのメンバーです"
        case .invalidInvite(let message):
            return message
        case .invalidArgument(let message):
            return message
        case .permissionDenied:
            return "権限がありません"
        case .invalidResponse:
            return "サーバーからの応答が不正です"
        case .unknown(let message):
            return "エラーが発生しました: \(message)"
        }
    }
}

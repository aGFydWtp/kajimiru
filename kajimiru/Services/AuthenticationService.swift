import Foundation
import FirebaseAuth
import GoogleSignIn
import SwiftUI

/// Authentication service managing user sign-in/sign-out with Firebase and Google Sign-In
@MainActor
class AuthenticationService: ObservableObject {

    @Published var currentUser: FirebaseAuth.User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        setupAuthStateListener()
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Auth State Monitoring

    private func setupAuthStateListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
            }
        }
    }

    // MARK: - Google Sign-In

    func signInWithGoogle() async throws {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw AuthenticationError.noRootViewController
        }

        isLoading = true
        errorMessage = nil

        do {
            // Get Google Sign-In result
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthenticationError.missingIDToken
            }

            let accessToken = result.user.accessToken.tokenString

            // Create Firebase credential
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )

            // Sign in to Firebase
            let authResult = try await Auth.auth().signIn(with: credential)

            // Update current user
            currentUser = authResult.user

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Sign Out

    func signOut() throws {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            currentUser = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Helper Properties

    var isAuthenticated: Bool {
        currentUser != nil
    }

    var userID: String? {
        currentUser?.uid
    }

    var userEmail: String? {
        currentUser?.email
    }

    var userDisplayName: String? {
        currentUser?.displayName
    }
}

// MARK: - Errors

enum AuthenticationError: LocalizedError {
    case noRootViewController
    case missingIDToken

    var errorDescription: String? {
        switch self {
        case .noRootViewController:
            return "ルートビューコントローラーが見つかりません"
        case .missingIDToken:
            return "Google Sign-InのIDトークンを取得できませんでした"
        }
    }
}

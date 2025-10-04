import SwiftUI

struct SignInView: View {
    @EnvironmentObject var authService: AuthenticationService

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App logo and title
            VStack(spacing: 16) {
                Image(systemName: "house.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)

                Text("Kajimiru")
                    .font(.largeTitle.weight(.bold))

                Text("家事を記録して、みんなで共有")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Sign in section
            VStack(spacing: 16) {
                if authService.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else {
                    googleSignInButton
                }

                if let errorMessage = authService.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }

            Spacer()
        }
        .padding()
    }

    private var googleSignInButton: some View {
        Button {
            Task {
                do {
                    try await authService.signInWithGoogle()
                } catch {
                    // Error already handled in AuthenticationService
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "g.circle.fill")
                    .font(.title2)

                Text("Googleでサインイン")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white)
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .padding(.horizontal, 32)
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthenticationService())
}

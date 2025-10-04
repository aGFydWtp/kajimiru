import SwiftUI

@main
struct KajimiruApp: App {
    @StateObject private var authService = AuthenticationService()
    @StateObject private var appState = AppState(useMockData: false)

    init() {
        // Initialize Firebase
        FirebaseConfig.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(appState)
                .task {
                    // Set auth service reference in app state
                    appState.setAuthService(authService)

                    // Check user status when authenticated
                    if authService.isAuthenticated {
                        await appState.checkUserStatus()
                    }
                }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var appState: AppState

    var body: some View {
        let _ = print("📱 ContentView: isAuth=\(authService.isAuthenticated), isLoading=\(appState.isLoading), needsGroupSelection=\(appState.needsGroupSelection), hasCompletedSetup=\(appState.hasCompletedSetup)")

        Group {
            if !authService.isAuthenticated {
                SignInView()
            } else if appState.isLoading {
                ProgressView("読み込み中...")
            } else if appState.needsGroupSelection {
                GroupSelectionView()
            } else if !appState.hasCompletedSetup {
                InitialSetupView()
            } else {
                MainTabView()
            }
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                Task {
                    await appState.checkUserStatus()
                }
            }
        }
    }
}

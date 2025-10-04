import Foundation
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn

/// Firebase configuration and initialization
enum FirebaseConfig {

    /// Initialize Firebase and Google Sign-In
    static func configure() {
        FirebaseApp.configure()

        // Configure Firestore to use emulator in debug builds
        #if DEBUG
        let settings = Firestore.firestore().settings
        settings.host = "127.0.0.1:8081"
        settings.cacheSettings = MemoryCacheSettings()
        settings.isSSLEnabled = false
        Firestore.firestore().settings = settings
        print("🔧 Firestore configured to use emulator at \(settings.host)")
        #endif

        // Google Sign-In client ID will be automatically loaded from GoogleService-Info.plist
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            fatalError("Failed to load Firebase client ID from GoogleService-Info.plist")
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
    }
}

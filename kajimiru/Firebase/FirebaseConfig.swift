import Foundation
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn

/// Firebase configuration and initialization
enum FirebaseConfig {

    /// Initialize Firebase and Google Sign-In
    static func configure(useEmulator: Bool = false) {
        FirebaseApp.configure()

        // Configure Firestore to use emulator only when explicitly requested
        if useEmulator {
            let settings = Firestore.firestore().settings
            settings.host = "127.0.0.1:8081"
            settings.cacheSettings = MemoryCacheSettings()
            settings.isSSLEnabled = false
            Firestore.firestore().settings = settings
            print("🔧 Firestore configured to use emulator at \(settings.host)")
        } else {
            print("🌐 Firestore configured to use production environment")
        }

        // Google Sign-In client ID will be automatically loaded from GoogleService-Info.plist
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            fatalError("Failed to load Firebase client ID from GoogleService-Info.plist")
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
    }
}

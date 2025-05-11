import SwiftUI
import FirebaseCore
import Firebase

@main
struct BandSyncApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
 
        FirebaseManager.shared.ensureInitialized()
        print("BandSyncApp: Firebase initialized during app startup")
    }

    var body: some Scene {
        WindowGroup {
            // Show SplashScreen initially
            SplashView()
                .environmentObject(AppState.shared)
                .onAppear {
                    print("SplashView: appeared")
                }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                print("BandSyncApp: App is active")
                FirebaseManager.shared.updateUserOnlineStatus(isOnline: true)

            case .background, .inactive:
                print("BandSyncApp: App moved to background/inactive")
                FirebaseManager.shared.updateUserOnlineStatus(isOnline: false)

            @unknown default:
                break
            }
        }
    }
}

extension FirebaseManager {
    func updateUserOnlineStatus(isOnline: Bool) {
        guard let userId = UserDefaults.standard.string(forKey: "userID") else {
            print("FirebaseManager: No user ID found for online status update")
            return
        }

        let userRef = Firestore.firestore().collection("users").document(userId)
        let data: [String: Any] = [
            "isOnline": isOnline,
            "lastSeen": FieldValue.serverTimestamp()
        ]

        userRef.updateData(data) { error in
            if let error = error {
                print("FirebaseManager: Failed to update online status: \(error.localizedDescription)")
            } else {
                print("FirebaseManager: Status updated to isOnline=\(isOnline)")
            }
        }
    }
}
extension UIApplication {
    func addTapGestureRecognizer() {
        guard let window = windows.first else { return }
        let tapGesture = UITapGestureRecognizer(target: window, action: #selector(UIView.endEditing))
        tapGesture.requiresExclusiveTouchType = false
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        window.addGestureRecognizer(tapGesture)
    }
}

extension UIApplication: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true 
    }
}

//
//  AppDelegate.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import UIKit
import Firebase
import FirebaseMessaging
import UserNotifications
import FirebaseDatabaseInternal

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("AppDelegate: initialization started")
        
        // Firebase initialization through manager
        print("AppDelegate: before Firebase initialization")
        FirebaseManager.shared.initialize()
        print("AppDelegate: after Firebase initialization")
        updateUserOnlineStatus(isOnline: true)
        // Notification setup
        UNUserNotificationCenter.current().delegate = self
        print("AppDelegate: notification delegate set")
        
        // Firebase Messaging setup
        Messaging.messaging().delegate = self
        print("AppDelegate: Messaging delegate set")
        
        // Request notification permission
        requestNotificationAuthorization()
        
        print("AppDelegate: initialization completed")
        return true
    }
    
    // Request notification permissions
    private func requestNotificationAuthorization() {
        print("AppDelegate: requesting notification permission")
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { granted, error in
                print("AppDelegate: notification permission \(granted ? "granted" : "denied")")
                if let error = error {
                    print("AppDelegate: permission request error: \(error)")
                }
            }
        )
        
        UIApplication.shared.registerForRemoteNotifications()
        print("AppDelegate: registration for remote notifications requested")
    }
    
    // Get FCM device token
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let token = fcmToken {
            print("AppDelegate: FCM token received: \(token)")
        } else {
            print("AppDelegate: failed to get FCM token")
        }
    }
    
    // Receive remote notifications when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("AppDelegate: notification received in foreground")
        // Show notification even if app is open
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("AppDelegate: notification tap received: \(userInfo)")
        
        completionHandler()
    }
    
    // Get device token for remote notifications
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("AppDelegate: device token for remote notifications received: \(token)")
        Messaging.messaging().apnsToken = deviceToken
    }
    
    // Handle remote notification registration error
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("AppDelegate: failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // Handle URL opening
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        print("AppDelegate: app opened via URL: \(url)")
        return true
    }

    
    // Handle app returning to active state
    func applicationWillEnterForeground(_ application: UIApplication) {
        print("AppDelegate: app returning to active state")
    }
 
    func applicationDidBecomeActive(_ application: UIApplication) {
        print("AppDelegate: App became active")
        updateUserOnlineStatus(isOnline: true)
    }

    func applicationWillResignActive(_ application: UIApplication) {
        print("AppDelegate: App will resign active")
        updateUserOnlineStatus(isOnline: false)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        print("AppDelegate: App entered background")
        updateUserOnlineStatus(isOnline: false)
    }
    func applicationWillTerminate(_ application: UIApplication) {
        print("AppDelegate: App will terminate")
        updateUserOnlineStatus(isOnline: false)
    }

   
}


extension AppDelegate {
    private func updateUserOnlineStatus(isOnline: Bool) {
        guard let userId = UserDefaults.standard.string(forKey: "userID") else {
            print("AppDelegate: No user ID in UserDefaults for online status update")
            return
        }

        let userRef = Firestore.firestore().collection("users").document(userId)
        let data: [String: Any] = [
            "isOnline": isOnline,
            "lastSeen": FieldValue.serverTimestamp()
        ]

        userRef.updateData(data) { error in
            if let error = error {
                print("AppDelegate: Failed to update Firestore user status: \(error.localizedDescription)")
            } else {
                print("AppDelegate: Firestore user status updated: isOnline=\(isOnline)")
            }
        }
    }

}

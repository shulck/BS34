// Обновленный метод в AppDelegate.swift

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
            // Сохраняем токен в UserDefaults для быстрого доступа
            UserDefaults.standard.set(token, forKey: "fcmToken")
            
            // Если пользователь уже авторизован, обновляем его профиль с новым токеном
            if let userId = Auth.auth().currentUser?.uid {
                updateUserFCMToken(userId: userId, token: token)
            }
        } else {
            print("AppDelegate: failed to get FCM token")
        }
    }
    
    // Обновление FCM токена пользователя в Firestore
    private func updateUserFCMToken(userId: String, token: String) {
        let userRef = Firestore.firestore().collection("users").document(userId)
        
        userRef.updateData([
            "fcmToken": token
        ]) { error in
            if let error = error {
                print("AppDelegate: Error updating FCM token: \(error.localizedDescription)")
            } else {
                print("AppDelegate: FCM token successfully updated for user \(userId)")
            }
        }
    }
    
    // Receive remote notifications when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("AppDelegate: notification received in foreground")
        
        // Получение данных уведомления
        let userInfo = notification.request.content.userInfo
        
        // Обработка уведомлений о задачах
        if let type = userInfo["type"] as? String, type == "task" {
            // Обновляем список задач, чтобы подсвечивать новые
            if let taskId = userInfo["taskId"] as? String {
                print("AppDelegate: received notification for task: \(taskId)")
                
                // Обновляем отображение задач
                NotificationCenter.default.post(
                    name: NSNotification.Name("TaskNotificationReceived"),
                    object: nil,
                    userInfo: ["taskId": taskId]
                )
            }
        }
        
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
        
        // Обработка действий с уведомлениями о задачах
        if let type = userInfo["type"] as? String, type == "task",
           let taskId = userInfo["taskId"] as? String,
           let action = userInfo["action"] as? String {
            
            // Отправляем уведомление для обработки в приложении
            NotificationCenter.default.post(
                name: NSNotification.Name("TaskNotificationTapped"),
                object: nil,
                userInfo: [
                    "taskId": taskId,
                    "action": action
                ]
            )
            
            // Переход к задаче при тапе на уведомление
            if action == "assignment" || action == "reminder" {
                // Здесь можно добавить логику для перехода к деталям задачи
                print("AppDelegate: should navigate to task details for taskId: \(taskId)")
            }
        }
        
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
        // Сброс счетчика уведомлений
        UIApplication.shared.applicationIconBadgeNumber = 0
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

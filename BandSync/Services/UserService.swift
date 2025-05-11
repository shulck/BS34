// Обновление в UserService.swift

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseMessaging

final class UserService: ObservableObject {
    static let shared = UserService()
    @Published var currentUser: UserModel?
    
    private let db = Firestore.firestore()
    
    init() {
        print("UserService: initialized")
    }
    
    func fetchCurrentUser(completion: @escaping (Bool) -> Void) {
        print("UserService: loading current user")
        
        // Make sure Firebase is initialized
        FirebaseManager.shared.ensureInitialized()
        
        guard let uid = Auth.auth().currentUser?.uid else {
            print("UserService: no current user")
            DispatchQueue.main.async {
                completion(false)
            }
            return
        }
        
        print("UserService: requesting user data from Firestore, uid: \(uid)")
        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            if let error = error {
                print("UserService: error loading user data: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists else {
                print("UserService: user document doesn't exist")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            if let data = snapshot.data() {
                print("UserService: user data received: \(data)")
                
                // Create UserModel directly from data without JSON serialization
                let user = UserModel(
                    id: data["id"] as? String ?? uid,
                    email: data["email"] as? String ?? "",
                    name: data["name"] as? String ?? "",
                    phone: data["phone"] as? String ?? "",
                    groupId: data["groupId"] as? String,
                    role: UserModel.UserRole(rawValue: data["role"] as? String ?? "Member") ?? .member,
                    isOnline: data["isOnline"] as? Bool,
                    lastSeen: (data["lastSeen"] as? Timestamp)?.dateValue(),
                    fcmToken: data["fcmToken"] as? String,
                    taskNotificationsEnabled: data["taskNotificationsEnabled"] as? Bool ?? true
                )
                
                DispatchQueue.main.async {
                    self?.currentUser = user
                    print("UserService: currentUser set")
                    
                    // Обновляем FCM токен, если он изменился
                    self?.updateFCMTokenIfNeeded(for: uid)
                    
                    completion(true)
                }
            } else {
                print("UserService: user data is missing")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    
    // Метод для обновления FCM токена, если он изменился
    private func updateFCMTokenIfNeeded(for userId: String) {
        if let storedToken = UserDefaults.standard.string(forKey: "fcmToken"),
           currentUser?.fcmToken != storedToken {
            // Токен изменился, обновляем в Firestore
            db.collection("users").document(userId).updateData([
                "fcmToken": storedToken
            ]) { error in
                if let error = error {
                    print("UserService: Error updating FCM token: \(error.localizedDescription)")
                } else {
                    print("UserService: FCM token updated successfully")
                    // Обновляем локальную модель пользователя
                    DispatchQueue.main.async {
                        var updatedUser = self.currentUser
                        updatedUser?.fcmToken = storedToken
                        self.currentUser = updatedUser
                    }
                }
            }
        }
    }
    
    // Обновление настроек уведомлений о задачах
    func updateTaskNotificationsSettings(enabled: Bool, completion: @escaping (Bool) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        db.collection("users").document(userId).updateData([
            "taskNotificationsEnabled": enabled
        ]) { [weak self] error in
            if let error = error {
                print("UserService: Error updating task notifications settings: \(error.localizedDescription)")
                completion(false)
            } else {
                // Обновляем локальную модель пользователя
                DispatchQueue.main.async {
                    var updatedUser = self?.currentUser
                    updatedUser?.taskNotificationsEnabled = enabled
                    self?.currentUser = updatedUser
                    completion(true)
                }
            }
        }
    }
    
    func updateUserGroup(groupId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("UserService: updating user group to \(groupId)")
        
        // Make sure Firebase is initialized
        FirebaseManager.shared.ensureInitialized()
        
        guard let uid = Auth.auth().currentUser?.uid else {
            print("UserService: no current user to update group")
            return
        }
        
        db.collection("users").document(uid).updateData([
            "groupId": groupId
        ]) { error in
            if let error = error {
                print("UserService: error updating group: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("UserService: group successfully updated")
                self.fetchCurrentUser { _ in }
                completion(.success(()))
            }
        }
    }
}

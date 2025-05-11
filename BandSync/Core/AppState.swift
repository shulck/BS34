//
//  AppState.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import Combine
import FirebaseAuth

final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isLoggedIn: Bool = false // Changed to false for security
    @Published var user: UserModel?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()

    private init() {
        print("AppState: initialization")
        
        // Make sure Firebase is initialized
        FirebaseManager.shared.ensureInitialized()
        
        print("AppState: checking authorization state")
        isLoggedIn = AuthService.shared.isUserLoggedIn()
        print("AppState: isLoggedIn set to \(isLoggedIn)")
        
        print("AppState: setting up subscription to currentUser")
        UserService.shared.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                print("AppState: received user update: \(user != nil ? "user exists" : "user doesn't exist")")
                self?.user = user
                
                // When user changes, load permissions
                if let groupId = user?.groupId {
                    print("AppState: user has groupId: \(groupId), loading permissions")
                    PermissionService.shared.fetchPermissions(for: groupId)
                } else {
                    print("AppState: user has no groupId")
                }
            }
            .store(in: &cancellables)
        print("AppState: initialization completed")
    }

    func logout() {
        print("AppState: starting logout")
        isLoading = true
        
        AuthService.shared.signOut { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success:
                    print("AppState: logout successful")
                    self.isLoggedIn = false
                    self.user = nil
                case .failure(let error):
                    print("AppState: error during logout: \(error.localizedDescription)")
                    self.errorMessage = "Error during logout: \(error.localizedDescription)"
                }
            }
        }
    }

    func loadUser() {
        print("AppState: starting user loading")
        isLoading = true
        
        UserService.shared.fetchCurrentUser { [weak self] success in
            guard let self = self else {
                print("AppState: self = nil during user loading")
                return
            }
            
            DispatchQueue.main.async {
                print("AppState: user loading completed, success: \(success)")
                self.isLoggedIn = success
                self.isLoading = false
                
                if success, let user = self.user {
                               UserDefaults.standard.set(user.id, forKey: "userID")
                               UserDefaults.standard.set(user.name, forKey: "userName")
                               UserDefaults.standard.set(user.email, forKey: "userEmail")
                               UserDefaults.standard.set(user.groupId, forKey: "userGroupID")
                               UserDefaults.standard.set(user.phone, forKey: "userPhone")
                               UserDefaults.standard.set(user.role.rawValue, forKey: "userRole")
                               
                               print("AppState: user data saved to UserDefaults")
                           } else {
                               self.errorMessage = "Failed to load user data"
                               print("AppState: failed to load user data")
                           }
            }
        }
    }

    func refreshAuthState() {
        print("AppState: refreshing authorization state")
        isLoading = true
        
        // Make sure Firebase is initialized
        FirebaseManager.shared.ensureInitialized()
        
        print("AppState: checking current user")
        if Auth.auth().currentUser != nil {
            print("AppState: user is authorized, loading data")
            loadUser()
        } else {
            print("AppState: user is not authorized")
            DispatchQueue.main.async {
                self.isLoggedIn = false
                self.user = nil
                self.isLoading = false
            }
        }
    }
    
    // Check access to module for current user
    func hasAccess(to moduleType: ModuleType) -> Bool {
        print("AppState: checking access to module \(moduleType.rawValue)")
        guard isLoggedIn, let userRole = user?.role else {
            print("AppState: access to module \(moduleType.rawValue) denied - not authorized or no role")
            return false
        }
        
        let hasAccess = PermissionService.shared.hasAccess(to: moduleType, role: userRole)
        print("AppState: access to module \(moduleType.rawValue) \(hasAccess ? "allowed" : "denied")")
        return hasAccess
    }
    
    // Check if user has edit permissions in the module
    func hasEditPermission(for moduleType: ModuleType) -> Bool {
        print("AppState: checking edit permissions for module \(moduleType.rawValue)")
        guard isLoggedIn, let userRole = user?.role else {
            print("AppState: edit access for module \(moduleType.rawValue) denied - not authorized or no role")
            return false
        }
        
        // Admins and managers have edit permissions
        let hasPermission = userRole == .admin || userRole == .manager
        print("AppState: edit access for module \(moduleType.rawValue) \(hasPermission ? "allowed" : "denied")")
        return hasPermission
    }
}

//
//  GroupViewModel.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  GroupViewModel.swift
//  BandSync
//
//  Created by Claude AI on 31.03.2025.
//

import Foundation
import Combine
import FirebaseFirestore

final class GroupViewModel: ObservableObject {
    @Published var groupName = ""
    @Published var groupCode = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var pendingMembers: [String] = []
    @Published var members: [String] = []
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    // Create a new group
    func createGroup(completion: @escaping (Result<String, Error>) -> Void) {
        guard let userId = AuthService.shared.currentUserUID(), !groupName.isEmpty else {
            errorMessage = "You must specify a group name"
            completion(.failure(NSError(domain: "EmptyGroupName", code: -1, userInfo: nil)))
            return
        }
        
        isLoading = true
        
        let groupCode = UUID().uuidString.prefix(6).uppercased()
        let newGroup = GroupModel(
            name: groupName,
            code: String(groupCode),
            members: [userId],
            pendingMembers: []
        )
        
        do {
            try db.collection("groups").addDocument(from: newGroup) { [weak self] error in
                guard let self = self else { return }
                
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error creating group: \(error.localizedDescription)"
                    completion(.failure(error))
                    return
                }
                
                self.successMessage = "Group successfully created!"
                
                // Get the ID of the created group
                self.db.collection("groups")
                    .whereField("code", isEqualTo: groupCode)
                    .getDocuments { snapshot, error in
                        if let error = error {
                            self.errorMessage = "Error getting group ID: \(error.localizedDescription)"
                            completion(.failure(error))
                            return
                        }
                        
                        if let groupId = snapshot?.documents.first?.documentID {
                            // Update user with group ID
                            UserService.shared.updateUserGroup(groupId: groupId) { result in
                                switch result {
                                case .success:
                                    // Also update user role to Admin
                                    self.db.collection("users").document(userId).updateData([
                                        "role": "Admin"
                                    ]) { error in
                                        if let error = error {
                                            self.errorMessage = "Error assigning administrator: \(error.localizedDescription)"
                                            completion(.failure(error))
                                        } else {
                                            completion(.success(groupId))
                                        }
                                    }
                                case .failure(let error):
                                    self.errorMessage = "Error updating user: \(error.localizedDescription)"
                                    completion(.failure(error))
                                }
                            }
                        } else {
                            self.errorMessage = "Could not find created group"
                            completion(.failure(NSError(domain: "GroupNotFound", code: -1, userInfo: nil)))
                        }
                    }
            }
        } catch {
            isLoading = false
            errorMessage = "Error creating group: \(error.localizedDescription)"
            completion(.failure(error))
        }
    }
    
    // Join an existing group by code
    func joinGroup(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = AuthService.shared.currentUserUID(), !groupCode.isEmpty else {
            errorMessage = "You must specify a group code"
            completion(.failure(NSError(domain: "EmptyGroupCode", code: -1, userInfo: nil)))
            return
        }
        
        isLoading = true
        
        db.collection("groups")
            .whereField("code", isEqualTo: groupCode)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error searching for group: \(error.localizedDescription)"
                    completion(.failure(error))
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    self.errorMessage = "Group with this code not found"
                    completion(.failure(NSError(domain: "GroupNotFound", code: -1, userInfo: nil)))
                    return
                }
                
                let groupId = document.documentID
                
                // Add user to pendingMembers
                self.db.collection("groups").document(groupId).updateData([
                    "pendingMembers": FieldValue.arrayUnion([userId])
                ]) { error in
                    if let error = error {
                        self.errorMessage = "Error joining group: \(error.localizedDescription)"
                        completion(.failure(error))
                    } else {
                        self.successMessage = "Join request sent. Waiting for confirmation."
                        

                    }
                }
            }
    }
    
    // Load group members
    func loadGroupMembers(groupId: String) {
        isLoading = true
        
        GroupService.shared.fetchGroup(by: groupId)
        
        // Subscribe to group updates
        GroupService.shared.$group
            .receive(on: DispatchQueue.main)
            .sink { [weak self] group in
                guard let self = self, let group = group else { return }
                
                self.isLoading = false
                self.members = group.members
                self.pendingMembers = group.pendingMembers
            }
            .store(in: &cancellables)
    }
}

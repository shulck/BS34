//
//  GroupService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 31.03.2025.
//

import Foundation
import FirebaseFirestore


final class GroupService: ObservableObject {
    static let shared = GroupService()

    @Published var group: GroupModel?
    @Published var groupMembers: [UserModel] = []
    @Published var pendingMembers: [UserModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    
    // Get group information by ID
    func fetchGroup(by id: String) {
        isLoading = true
        
        db.collection("groups").document(id).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                self.errorMessage = "Error loading group: \(error.localizedDescription)"
                self.isLoading = false
                return
            }
            
            if let data = try? snapshot?.data(as: GroupModel.self) {
                DispatchQueue.main.async {
                    self.group = data
                    self.fetchGroupMembers(groupId: id)
                    self.isLoading = false
                }
            } else {
                self.errorMessage = "Error converting group data"
                self.isLoading = false
            }
        }
    }

    // Get information about group users
    private func fetchGroupMembers(groupId: String) {
        guard let group = self.group else { return }
        
        // Clear existing data
        self.groupMembers = []
        self.pendingMembers = []
        
        // Get active members
        for memberId in group.members {
            db.collection("users").document(memberId).getDocument { [weak self] snapshot, error in
                if let userData = try? snapshot?.data(as: UserModel.self) {
                    DispatchQueue.main.async {
                        if !(self?.groupMembers.contains(where: { $0.id == userData.id }) ?? false) {
                            self?.groupMembers.append(userData)
                        }
                    }
                }
            }
        }
        
        // Get pending members
        for pendingId in group.pendingMembers {
            db.collection("users").document(pendingId).getDocument { [weak self] snapshot, error in
                if let userData = try? snapshot?.data(as: UserModel.self) {
                    DispatchQueue.main.async {
                        self?.pendingMembers.append(userData)
                    }
                }
            }
        }
    }

    func approveUser(userId: String) {
        guard let groupId = group?.id else { return }
        isLoading = true

        db.collection("groups").document(groupId).updateData([
            "pendingMembers": FieldValue.arrayRemove([userId]),
            "members": FieldValue.arrayUnion([userId])
        ]) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    self?.errorMessage = "Error approving user: \(error.localizedDescription)"
                } else {
                    UserService.shared.updateUserGroup(groupId: groupId) {_ in 
                        self?.fetchGroupMembers(groupId: groupId)
                        self?.db.collection("users").document(userId).updateData([
                            "groupId": groupId
                        ])
                    }
                    
                   
                }
            }
        }
    }


    // Reject user application
    func rejectUser(userId: String) {
        guard let groupId = group?.id else { return }
        isLoading = true
        
        db.collection("groups").document(groupId).updateData([
            "pendingMembers": FieldValue.arrayRemove([userId])
        ]) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Error rejecting user: \(error.localizedDescription)"
                } else {
                    // Update local data
                    if let pendingIndex = self?.pendingMembers.firstIndex(where: { $0.id == userId }) {
                        self?.pendingMembers.remove(at: pendingIndex)
                    }
                    
                    // Also need to clear groupId in user profile
                    self?.db.collection("users").document(userId).updateData([
                        "groupId": NSNull()
                    ])
                }
            }
        }
    }

    // Remove user from group
    func removeUser(userId: String) {
        guard let groupId = group?.id else { return }
        isLoading = true
        
        db.collection("groups").document(groupId).updateData([
            "members": FieldValue.arrayRemove([userId])
        ]) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Error removing user: \(error.localizedDescription)"
                } else {
                    // Update local data
                    if let memberIndex = self?.groupMembers.firstIndex(where: { $0.id == userId }) {
                        self?.groupMembers.remove(at: memberIndex)
                    }
                    
                    // Also need to clear groupId in user profile
                    self?.db.collection("users").document(userId).updateData([
                        "groupId": NSNull()
                    ])
                }
            }
        }
    }

    // Update group name
    func updateGroupName(_ newName: String) {
        guard let groupId = group?.id else { return }
        isLoading = true
        
        db.collection("groups").document(groupId).updateData([
            "name": newName
        ]) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Error updating name: \(error.localizedDescription)"
                } else {
                    // Update local data
                    self?.group?.name = newName
                }
            }
        }
    }

    // Generate new invitation code
    func regenerateCode() {
        guard let groupId = group?.id else { return }
        isLoading = true
        
        let newCode = UUID().uuidString.prefix(6).uppercased()

        db.collection("groups").document(groupId).updateData([
            "code": String(newCode)
        ]) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Error updating code: \(error.localizedDescription)"
                } else {
                    // Update local data
                    self?.group?.code = String(newCode)
                }
            }
        }
    }
    
    // Change user role
    func changeUserRole(userId: String, newRole: UserModel.UserRole) {
        // Проверка на пустой ID
        guard !userId.isEmpty else {
            errorMessage = "Ошибка: ID пользователя пустой"
            return
        }
        
        print("Changing role for user: \(userId)")
        isLoading = true
        
        db.collection("users").document(userId).updateData([
            "role": newRole.rawValue
        ]) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("Error changing role: \(error.localizedDescription)")
                    self?.errorMessage = "Ошибка изменения роли: \(error.localizedDescription)"
                } else {
                    print("Role updated successfully")
                    // Безопасное обновление локальных данных
                    if let self = self,
                       let memberIndex = self.groupMembers.firstIndex(where: { $0.id == userId }) {
                        var updatedMember = self.groupMembers[memberIndex]
                        updatedMember.role = newRole
                        self.groupMembers[memberIndex] = updatedMember
                    }
                }
            }
        }
    }
}

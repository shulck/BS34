//
//  GroupChatService.swift
//  BandSync
//
//  Created by Akash 's Mac M1 on 24/04/2025.
//



import Foundation
import FirebaseFirestore
import FirebaseDatabaseInternal
import FirebaseDatabase

final class GroupChatService: ObservableObject {
    static let shared = GroupChatService()
    private let firestore = Firestore.firestore()
    @Published var groupChats: [GroupChatModel] = []
    @Published var groupMessages: [Message] = []
    @Published var users: [String: UserModel] = [:]

    private let db = FirebaseDatabase.Database.database().reference()
    func fetchGroupMembers(completion: @escaping ([UserModel]) -> Void) {
        guard let groupId = AppState.shared.user?.groupId,
              let currentUserId = AppState.shared.user?.id else {
            completion([])
            return
        }
        
        firestore.collection("groups").document(groupId).getDocument { [weak self] snapshot, error in
            guard let data = snapshot?.data(), error == nil else {
                completion([])
                return
            }
            
            let memberIds = (data["members"] as? [String] ?? []).filter { $0 != currentUserId }
            
            let group = DispatchGroup()
            var users: [UserModel] = []
            
            for userId in memberIds {
                group.enter()
                self?.firestore.collection("users").document(userId).getDocument { document, _ in
                    defer { group.leave() }
                    
                    if let document = document, let userData = try? document.data(as: UserModel.self) {
                        users.append(userData)
                    }
                }
            }
            
            group.notify(queue: .main) {
                completion(users)
            }
        }
    }
    func fetchGroupChats() {
        db.child("groupchats").observeSingleEvent(of: .value) { [weak self] snapshot in
            print("📦 Snapshot.exists(): \(snapshot.exists())")
            print("📦 Snapshot.childrenCount: \(snapshot.childrenCount)")
            print("📦 Snapshot.value: \(snapshot.value ?? "nil")")

            guard let self = self else { return }
            var fetchedGroups: [GroupChatModel] = []

            guard let storedBandId = UserDefaults.standard.string(forKey: "userGroupID"),
                  let currentUserId = UserDefaults.standard.string(forKey: "userID") else {
                print("❌ Missing bandId or userID from UserDefaults")
                return
            }

            if !snapshot.exists() || snapshot.childrenCount == 0 {
                DispatchQueue.main.async {
                    self.groupChats = []
                }
                return
            }

            for case let child as DataSnapshot in snapshot.children {
                guard var dict = child.value as? [String: Any],
                      let bandId = dict["bandId"] as? String,
                      let members = dict["members"] as? [String],
                      bandId == storedBandId,
                      members.contains(currentUserId) else {
                    continue
                }

                dict["groupId"] = child.key

                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [])
                    let group = try JSONDecoder().decode(GroupChatModel.self, from: jsonData)
                    fetchedGroups.append(group)
                } catch {
                    print("❌ Failed to decode group: \(error)")
                }
            }

            DispatchQueue.main.async {
                self.groupChats = fetchedGroups.sorted {
                    ($0.lastMessageTime ?? 0) > ($1.lastMessageTime ?? 0)
                }
            }
        }
    }

    func deleteMessage(_ message: Message, in groupId: String) {
        Database.database().reference()
            .child("groupMessages")
            .child(groupId)
            .child(message.id ?? "")
            .removeValue()
    }


    func createGroup(groupName: String, selectedUserIds: Set<String>, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let creatorId = UserDefaults.standard.string(forKey: "userID"),
              let bandId = UserDefaults.standard.string(forKey: "userGroupID") else {
            completion(.failure(NSError(domain: "Missing UserDefaults info", code: 0)))
            return
        }

        let groupId = UUID().uuidString
        let members = Array(selectedUserIds.union([creatorId]))
        let timestamp = Date().timeIntervalSince1970

        let groupData: [String: Any] = [
            "bandId": bandId,
            "groupId": groupId,
            "adminId": creatorId,
            "members": members,
            "groupName": groupName,
            "lastMessage": "",
            "lastMessageSenderId": "",
            "lastMessageTime": timestamp
        ]

        let ref = Database.database().reference().child("groupchats").child(groupId)
        ref.setValue(groupData) { error, _ in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }


    func fetchGroupMessages(for groupId: String, completion: (() -> Void)? = nil) {
        db.child("groupMessages").child(groupId).observe(.value) { [weak self] snapshot in
            var messages: [Message] = []

            for case let child as DataSnapshot in snapshot.children {
                guard let data = child.value as? [String: Any] else { continue }
                let messageId = child.key

                // Required fields
                guard let chatId = data["chatId"] as? String,
                      let senderId = data["senderId"] as? String,
                      let text = data["text"] as? String else {
                    continue
                }

                // Optional fields
                let replyTo = data["replyTo"] as? String
                let isEdited = data["isEdited"] as? Bool ?? false
                let timestamp: Date
                if let time = data["timestamp"] as? TimeInterval {
                    timestamp = Date(timeIntervalSince1970: time)
                } else {
                    timestamp = Date()
                }

                let seenBy = data["seenBy"] as? [String] ?? []
                let deliveredTo = data["deliveredTo"] as? [String] ?? []

                // Construct message
                let message = Message(
                    id: messageId,
                    chatId: chatId,
                    senderId: senderId,
                    text: text,
                    timestamp: timestamp,
                    replyTo: replyTo,
                    seenBy: seenBy,
                    deliveredTo: deliveredTo,
                    isEdited: isEdited
                )

                messages.append(message)
            }

            DispatchQueue.main.async {
                self?.groupMessages = messages.sorted { $0.timestamp < $1.timestamp }
                completion?() 
            }
        }
    }


    func sendGroupMessage(_ message: Message, groupId: String) {
        let messageId = UUID().uuidString
        let messageDict = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(message))
        db.child("groupMessages").child(groupId).child(messageId).setValue(messageDict)
    }
  
    func loadGroupUsers(userIds: [String]) {
        let group = DispatchGroup()
        var tempUsers: [String: UserModel] = [:]

        userIds.forEach { userId in
            group.enter()
            Firestore.firestore().collection("users").document(userId).getDocument { snapshot, _ in
                if let user = try? snapshot?.data(as: UserModel.self) {
                    tempUsers[userId] = user
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.users = tempUsers
        }
    }
    func editMessage(_ message: Message, newText: String, in groupId: String) {
        guard let messageId = message.id else { return }

        var updateData: [String: Any] = [
            "text": newText,
            "isEdited": true
        ]

        // Only update optional fields if they exist (avoids writing null/NSNull)
        if let replyTo = message.replyTo {
            updateData["replyTo"] = replyTo
        }


        Database.database().reference()
            .child("groupMessages")
            .child(groupId)
            .child(messageId)
            .updateChildValues(updateData)
    }

    func updateGroupMembers(groupId: String, newMemberIds: [String], completion: @escaping (Bool) -> Void) {
          let groupRef = Database.database().reference().child("groupchats").child(groupId)
          groupRef.updateChildValues(["members": newMemberIds]) { error, _ in
              if let error = error {
                  print("❌ Failed to update members: \(error)")
                  completion(false)
              } else {
                  // Optional: Refresh the local data
                  self.fetchGroupChats()
                  completion(true)
              }
          }
      }


}

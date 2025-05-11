import Foundation
import FirebaseDatabase
import FirebaseFirestore
import FirebaseMessaging
import Combine
import Network

final class ChatService: ObservableObject {
    static let shared = ChatService()
    
    // MARK: - Published Properties
    @Published var isLoading: Bool = true
    @Published var chats: [Chat] = []
    @Published var messages: [Message] = []
    @Published var isOffline: Bool = false
    @Published var unreadMessagesCount: Int = 0
    
    // MARK: - Private Properties
    private let db = FirebaseDatabase.Database.database().reference()
    private let firestore = Firestore.firestore()
    private var messageHandle: DatabaseHandle?
    private var chatHandles: [String: DatabaseHandle] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var pendingMessages: [Message] = []
    private var networkMonitor = NWPathMonitor()
    private var userStatusObservers: [String: DatabaseHandle] = [:]
    
    // MARK: - Initialization
    
    init() {
        setupNetworkMonitoring()
        
        // Subscribe to app state changes
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.syncPendingMessages()
                self?.refreshUnreadCount()
            }
            .store(in: &cancellables)
    }
    
    deinit {
        cleanupAllObservers()
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let previousState = self?.isOffline ?? true
                let newState = path.status != .satisfied
                
                self?.isOffline = newState
                
                // If coming back online, sync pending messages
                if previousState && !newState {
                    self?.syncPendingMessages()
                }
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
    

    func fetchChats(for userId: String) {
        isLoading = true

        // Remove previous listener
        if let existingHandle = chatHandles[userId] {
            db.child("chats")
                .queryOrdered(byChild: "participants/\(userId)")
                .queryEqual(toValue: true)
                .removeObserver(withHandle: existingHandle)
        }

        let query = db.child("chats")
            .queryOrdered(byChild: "participants/\(userId)")
            .queryEqual(toValue: true)

        let handle = query.observe(.value) { [weak self] snapshot in
            guard let self = self else { return }

            var tempChats: [Chat] = []
            let group = DispatchGroup()

            guard snapshot.exists() else {
                DispatchQueue.main.async {
                    self.chats = []
                    self.isLoading = false
                }
                return
            }

            for case let child as DataSnapshot in snapshot.children {
                guard let chatDict = child.value as? [String: Any],
                      let participants = chatDict["participants"] as? [String: Bool],
                      participants[userId] == true else { continue }

                let typeString = chatDict["type"] as? String ?? "direct"
                let type = ChatType(rawValue: typeString) ?? .direct

                let lastMessage = chatDict["lastMessage"] as? String
                var lastMessageTime: Date? = nil
                if let timestamp = chatDict["lastMessageTime"] as? TimeInterval {
                    lastMessageTime = Date(timeIntervalSince1970: timestamp / 1000)
                }

                if type == .direct {
                    if let otherUserId = participants.keys.first(where: { $0 != userId }) {
                        group.enter()
                        self.fetchUserName(userId: otherUserId) { userName in
                            let chat = Chat(
                                id: child.key,
                                name: userName ?? "Chat",
                                type: .direct,
                                participants: participants,
                                lastMessage: lastMessage,
                                lastMessageTime: lastMessageTime
                            )
                            tempChats.append(chat)
                            group.leave()
                        }
                    }
                } else {
                    let name = chatDict["name"] as? String ?? "Group"
                    let chat = Chat(
                        id: child.key,
                        name: name,
                        type: .group,
                        participants: participants,
                        lastMessage: lastMessage,
                        lastMessageTime: lastMessageTime
                    )
                    tempChats.append(chat)
                }
            }

            group.notify(queue: .main) {
                self.chats = tempChats.sorted {
                    ($0.lastMessageTime ?? .distantPast) > ($1.lastMessageTime ?? .distantPast)
                }
                self.isLoading = false
                self.cacheChats(self.chats, for: userId)
                self.refreshUnreadCount()
            }
        }

        chatHandles[userId] = handle
    }


    func fetchMessages(for chatId: String, completion: (() -> Void)? = nil) {
        // Clear current messages
        messages = []
        
        // Check if we're offline
        if isOffline {
            loadCachedMessages(for: chatId)
            completion?()
            return
        }
        
        // Remove previous listener if any
        if let handle = messageHandle {
            db.child("messages").child(chatId).removeObserver(withHandle: handle)
        }
        
        // Set up real-time listening
        messageHandle = db.child("messages").child(chatId).observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            
            var msgs: [Message] = []
            
            for case let child as DataSnapshot in snapshot.children {
                if let data = child.value as? [String: Any] {
                    let messageId = child.key
                    
                    // Extract required fields
                    guard let chatId = data["chatId"] as? String,
                          let senderId = data["senderId"] as? String,
                          let text = data["text"] as? String else {
                        continue
                    }
                    
                    // Extract optional fields with defaults
                    let replyTo = data["replyTo"] as? String
                    let isEdited = data["isEdited"] as? Bool ?? false
                    
                    // Convert timestamp
                    var timestamp = Date()
                    if let messageTimestamp = data["timestamp"] as? TimeInterval {
                        timestamp = Date(timeIntervalSince1970: messageTimestamp / 1000)
                    }
                    
                    // Extract seen/delivered arrays
                    let seenBy = data["seenBy"] as? [String] ?? []
                    let deliveredTo = data["deliveredTo"] as? [String] ?? []
                    
                    // Create message
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
                    
                    msgs.append(message)
                }
            }
            
            // Sort messages by timestamp
            let sortedMessages = msgs.sorted { $0.timestamp < $1.timestamp }
            
            DispatchQueue.main.async {
                self.messages = sortedMessages
                
                // Cache messages for offline access
                self.cacheMessages(sortedMessages, for: chatId)
                
                // Mark current user's messages as delivered
                if let userId = AppState.shared.user?.id {
                    for message in sortedMessages where message.senderId != userId {
                        self.markMessageDelivered(chatId: chatId, messageId: message.id ?? "", userId: userId)
                    }
                }
                
                // Call completion handler after messages are loaded
                completion?()
            }
        }
    }
    

    
    func sendMessage(_ message: Message, participants: [String]) {
        // Check if we're offline
        if isOffline {
            pendingMessages.append(message)
            cacheMessage(message)
            return
        }
        
        // Send to Firebase
        sendMessageToFirebase(message, participants: participants)
    }
    
    private func sendMessageToFirebase(_ message: Message, participants: [String]) {
        let messageRef = db.child("messages").child(message.chatId).childByAutoId()
        var newMsg = message
        newMsg.id = messageRef.key
        
        // Create message data
        let messageData: [String: Any] = [
            "chatId": message.chatId,
            "senderId": message.senderId,
            "text": message.text,
            "timestamp": FirebaseDatabase.ServerValue.timestamp(),
            "seenBy": message.seenBy,
            "deliveredTo": message.deliveredTo,
            "isEdited": message.isEdited
        ]
        
        // Add replyTo if present
        var finalData = messageData
        if let replyTo = message.replyTo {
            finalData["replyTo"] = replyTo
        }
        
        messageRef.setValue(finalData) { [weak self] error, _ in
            if let error = error {
                print("Error sending message: \(error.localizedDescription)")
                // If error, add to pending messages for retry
                self?.pendingMessages.append(newMsg)
            }
        }
        
        // Update chat with last message
        updateChatWithLastMessage(message, participants: participants)
    }
    
    private func updateChatWithLastMessage(_ message: Message, participants: [String]) {
        // Convert participants to Firebase format
        let participantsDict = Dictionary(uniqueKeysWithValues: participants.map { ($0, true) })
        
        // Create chat updates
        let updates: [String: Any] = [
            "lastMessage": message.text,
            "lastMessageTime": FirebaseDatabase.ServerValue.timestamp(),
            "participants": participantsDict
        ]
        
        // Update or create chat entry
        let chatRef = db.child("chats").child(message.chatId)
        
        chatRef.observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self else { return }
            
            if snapshot.exists() {
                // Chat exists, update
                chatRef.updateChildValues(updates)
            } else {
                // Chat doesn't exist, create new
                var newChat = updates
                newChat["type"] = participants.count > 2 ? "group" : "direct"

                if participants.count == 2,
                   let currentUserId = AppState.shared.user?.id,
                   let otherUserId = participants.first(where: { $0 != currentUserId }) {
                    self.fetchUserName(userId: otherUserId) { name in
        
                        chatRef.setValue(newChat)
                    }
                } else {
                    // Group chat
                    newChat["name"] = "Group Chat"
                    chatRef.setValue(newChat)
                }
            }

        }
    }
    
    func editMessage(_ message: Message, newText: String) {
        guard let messageId = message.id else { return }
        
        // Check if we're offline
        if isOffline {
            // Store edit for later sync
            var updatedMessage = message
            updatedMessage.text = newText
            updatedMessage.isEdited = true
            
            // Find and update in pending messages
            if let index = pendingMessages.firstIndex(where: { $0.id == messageId }) {
                pendingMessages[index] = updatedMessage
            } else {
                pendingMessages.append(updatedMessage)
            }
            
            // Update cache
            updateCachedMessage(updatedMessage)
            return
        }
        
        let updatedValues: [String: Any] = [
            "text": newText,
            "isEdited": true
        ]
        
        db.child("messages").child(message.chatId).child(messageId).updateChildValues(updatedValues) { error, _ in
            if let error = error {
                print("Error editing message: \(error.localizedDescription)")
            }
        }
    }
    
    func deleteMessage(_ message: Message) {
        guard let id = message.id else { return }
        
        // Check if we're offline
        if isOffline {
            // Store delete operation for later sync
            pendingMessages.append(message)
            return
        }
        
        db.child("messages").child(message.chatId).child(id).removeValue { error, _ in
            if let error = error {
                print("Error deleting message: \(error.localizedDescription)")
            }
        }
    }
    
    func markMessageSeen(chatId: String, messageId: String, userId: String) {
        // Check if we're offline
        if isOffline {
            // We'll handle this when back online
            return
        }
        
        db.child("messages").child(chatId).child(messageId).child("seenBy").observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self else { return }
            
            var seenBy: [String] = []
            
            if let value = snapshot.value as? [String] {
                seenBy = value
            } else if snapshot.exists(), let data = snapshot.value {
                print("Unexpected data format for seenBy: \(data)")
            }
            
            if !seenBy.contains(userId) {
                seenBy.append(userId)
                self.db.child("messages").child(chatId).child(messageId).child("seenBy").setValue(seenBy)
            }
        }
    }
    
    func markMessageDelivered(chatId: String, messageId: String, userId: String) {
        // Check if we're offline
        if isOffline {
            // We'll handle this when back online
            return
        }
        
        db.child("messages").child(chatId).child(messageId).child("deliveredTo").observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self else { return }
            
            var delivered: [String] = []
            
            if let value = snapshot.value as? [String] {
                delivered = value
            } else if snapshot.exists(), let data = snapshot.value {
                print("Unexpected data format for deliveredTo: \(data)")
            }
            
            if !delivered.contains(userId) {
                delivered.append(userId)
                self.db.child("messages").child(chatId).child(messageId).child("deliveredTo").setValue(delivered)
            }
        }
    }
    
    // MARK: - User Status Methods
    
    func observeUserStatus(userId: String, completion: @escaping (Bool?, Date?) -> Void) {
        // Remove previous observer if any
        if let existingHandle = userStatusObservers[userId] {
            db.child("status").child(userId).removeObserver(withHandle: existingHandle)
        }
        
        let handle = db.child("status").child(userId).observe(.value) { snapshot in
            if let value = snapshot.value as? [String: Any] {
                let isOnline = value["isOnline"] as? Bool
                
                var lastSeen: Date? = nil
                if let lastSeenTimestamp = value["lastSeen"] as? TimeInterval {
                    lastSeen = Date(timeIntervalSince1970: lastSeenTimestamp / 1000)
                }
                
                DispatchQueue.main.async {
                    completion(isOnline, lastSeen)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil, nil)
                }
            }
        }
        
        userStatusObservers[userId] = handle
    }
    
    func fetchUserName(userId: String, completion: @escaping (String?) -> Void) {
        firestore.collection("users").document(userId).getDocument { document, error in
            if let error = error {
                print("Error fetching user: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            if let document = document, document.exists {
                let data = document.data()
                let name = data?["name"] as? String
                completion(name)
            } else {
                completion(nil)
            }
        }
    }
    
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
    
    // MARK: - Offline Support Methods
    
    private func syncPendingMessages() {
        guard !pendingMessages.isEmpty else { return }
        
        // Copy pending messages and clear the queue
        let messagesToSync = pendingMessages
        pendingMessages.removeAll()
        
        // Process each message
        for message in messagesToSync {
            // Get participants
            db.child("chats").child(message.chatId).child("participants").observeSingleEvent(of: .value) { [weak self] snapshot in
                if let participants = snapshot.value as? [String: Bool] {
                    let participantIds = Array(participants.keys)
                    self?.sendMessageToFirebase(message, participants: participantIds)
                }
            }
        }
    }
    
    // MARK: - Caching Methods
    
    private func cacheChats(_ chats: [Chat], for userId: String) {
        do {
            let data = try JSONEncoder().encode(chats)
            UserDefaults.standard.set(data, forKey: "cached_chats_\(userId)")
        } catch {
            print("Error caching chats: \(error.localizedDescription)")
        }
    }
    
    private func loadCachedChats(for userId: String) {
        guard let data = UserDefaults.standard.data(forKey: "cached_chats_\(userId)") else {
            isLoading = false
            return
        }
        
        do {
            let cachedChats = try JSONDecoder().decode([Chat].self, from: data)
            chats = cachedChats
            isLoading = false
        } catch {
            print("Error loading cached chats: \(error.localizedDescription)")
            isLoading = false
        }
    }
    
    private func cacheMessages(_ messages: [Message], for chatId: String) {
        do {
            let data = try JSONEncoder().encode(messages)
            UserDefaults.standard.set(data, forKey: "cached_messages_\(chatId)")
        } catch {
            print("Error caching messages: \(error.localizedDescription)")
        }
    }
    
    private func loadCachedMessages(for chatId: String) {
        guard let data = UserDefaults.standard.data(forKey: "cached_messages_\(chatId)") else {
            return
        }
        
        do {
            let cachedMessages = try JSONDecoder().decode([Message].self, from: data)
            self.messages = cachedMessages.sorted { $0.timestamp < $1.timestamp }
        } catch {
            print("Error loading cached messages: \(error.localizedDescription)")
        }
    }
    
    private func cacheMessage(_ message: Message) {
        loadCachedMessages(for: message.chatId)
        
        // Add the new message to the cached messages
        messages.append(message)
        
        // Save back to cache
        cacheMessages(messages, for: message.chatId)
    }
    
    private func updateCachedMessage(_ message: Message) {
        loadCachedMessages(for: message.chatId)
        
        // Find and replace the message
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index] = message
            
            // Save back to cache
            cacheMessages(messages, for: message.chatId)
        }
    }
    
    // MARK: - Unread Messages
    
    func refreshUnreadCount() {
        guard let currentUserId = AppState.shared.user?.id else {
            unreadMessagesCount = 0
            return
        }
        
        // Count messages across all chats that current user hasn't seen
        var count = 0
        
        for chat in chats {
            guard let chatId = chat.id else { continue }
            
            // Fetch messages for this chat
            db.child("messages").child(chatId).queryOrderedByKey().queryLimited(toLast: 20).observeSingleEvent(of: .value) { [weak self] snapshot in
                guard let strongSelf = self else { return }
                
                for case let messageSnapshot as DataSnapshot in snapshot.children {
                    if let messageDict = messageSnapshot.value as? [String: Any],
                       let senderId = messageDict["senderId"] as? String,
                       senderId != currentUserId,
                       let seenBy = messageDict["seenBy"] as? [String],
                       !seenBy.contains(currentUserId) {
                        count += 1
                    }
                }
                
                DispatchQueue.main.async {
                    strongSelf.unreadMessagesCount = count
                }
            }
        }
    }
    
    // MARK: - Cleanup Methods
    
    func stopListeningMessages(for chatId: String) {
        if let handle = messageHandle {
            db.child("messages").child(chatId).removeObserver(withHandle: handle)
            messageHandle = nil
        }
    }
    
    private func cleanupAllObservers() {
        // Clean up message observers
        if let handle = messageHandle {
            db.removeObserver(withHandle: handle)
        }
        
        // Clean up chat observers
        for (_, handle) in chatHandles {
            db.removeObserver(withHandle: handle)
        }
        
        // Clean up user status observers
        for (_, handle) in userStatusObservers {
            db.removeObserver(withHandle: handle)
        }
        
        // Stop network monitoring
        networkMonitor.cancel()
    }
}

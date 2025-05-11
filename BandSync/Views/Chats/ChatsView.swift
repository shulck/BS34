import SwiftUI
import FirebaseFirestore

let colorPalette: [Color] = [
    .blue, .green, .orange, .pink, .purple, .red, .yellow, .mint, .indigo, .cyan, .teal
]

func avatarColor(for name: String) -> Color {
    let hash = abs(name.hashValue)
    let index = hash % colorPalette.count
    return colorPalette[index]
}

struct ChatsView: View {
    @StateObject private var chatService = ChatService.shared
    @StateObject private var groupChatService = GroupChatService.shared
    @State private var showNewChat = false
    @State private var showCreateGroup = false
    @State private var searchText = ""
    @State private var isRefreshing = false
    @State private var selectedChatType: ChatType? = nil
    @State private var navigateToChat: Chat?
    @Environment(\.scenePhase) private var scenePhase
    
    // Computed properties
    var filteredChats: [Chat] {
        var result = chatService.chats
        
        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { chat in
                chat.name.lowercased().contains(searchText.lowercased()) ||
                (chat.lastMessage?.lowercased().contains(searchText.lowercased()) ?? false)
            }
        }
        
        if let type = selectedChatType {
            result = result.filter { $0.type == type }
        }
        
        return result.sorted {
            if let date1 = $0.lastMessageTime, let date2 = $1.lastMessageTime {
                return date1 > date2
            } else if $0.lastMessageTime != nil {
                return true
            } else if $1.lastMessageTime != nil {
                return false
            } else {
                return $0.name < $1.name
            }
        }
    }
    var filteredGroupChats: [GroupChatModel] {
        var result = groupChatService.groupChats

        if let currentUserId = UserDefaults.standard.string(forKey: "userID") {
            result = result.filter { chat in
                chat.members.contains(currentUserId)
            }
        }

        if !searchText.isEmpty {
            result = result.filter { chat in
                chat.groupName.lowercased().contains(searchText.lowercased()) ||
                (chat.lastMessage.lowercased().contains(searchText.lowercased()) ?? false)
            }
        }

        return result.sorted {
            if let date1 = $0.lastMessageTime, let date2 = $1.lastMessageTime {
                return date1 > date2
            } else if $0.lastMessageTime != nil {
                return true
            } else if $1.lastMessageTime != nil {
                return false
            } else {
                return $0.groupName < $1.groupName
            }
        }
    

      
        // Sort by last message time
        return result.sorted {
            if let date1 = $0.lastMessageTime, let date2 = $1.lastMessageTime {
                return date1 > date2
            } else if $0.lastMessageTime != nil {
                return true
            } else if $1.lastMessageTime != nil {
                return false
            } else {
                return $0.groupName < $1.groupName
            }
        }
    }
    
    

    private var privateChats: [Chat] {
        filteredChats.filter { $0.type == .direct }
    }

    private var groupChats: [GroupChatModel] {
        filteredGroupChats
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Chat type filter
                chatFilterBar
                
                // Chat list
                chatListView
            }
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showNewChat = true
                        } label: {
                            Label("New Message", systemImage: "square.and.pencil")
                        }
                        
                        Button {
                            showCreateGroup = true
                        } label: {
                            Label("New Group", systemImage: "person.3")
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
            .sheet(isPresented: $showNewChat) {
                GroupMembersView()
                    .onDisappear {
                        refreshChats()
                    }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search chats")
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    refreshChats()
                }
            }
            .onAppear {
                refreshChats()
                
                // Listen for notifications to navigate to specific chat
                NotificationCenter.default.addObserver(
                    forName: Notification.Name("NavigateToChatNotification"),
                    object: nil,
                    queue: .main
                ) { notification in
                    if let chat = notification.userInfo?["chat"] as? Chat {
                        navigateToChat = chat
                    }
                }
            }
            .background(
                // Navigation link that is programmatically triggered
                Group {
                    if let chat = navigateToChat {
                        NavigationLink(
                            destination: ChatDetailView(chat: chat),
                            isActive: Binding<Bool>(
                                get: { navigateToChat != nil },
                                set: { if !$0 { navigateToChat = nil } }
                            )
                        ) {
                            EmptyView()
                        }
                    }
                }
            )
            .sheet(isPresented: $showCreateGroup) {
                CreateGroupChatView() 
                    .onDisappear {
                        refreshChats()
                    }
            }
        }
    }

    private var chatFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterButton(
                    title: "All",
                    isSelected: selectedChatType == nil,
                    action: { selectedChatType = nil }
                )
                
                FilterButton(
                    title: "Direct",
                    isSelected: selectedChatType == .direct,
                    action: { selectedChatType = .direct }
                )
                
                FilterButton(
                    title: "Groups",
                    isSelected: selectedChatType == .group,
                    action: { selectedChatType = .group }
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color.gray.opacity(0.05))
    }

    
    private var chatListView: some View {
        List {
        
            if privateChats.isEmpty && groupChats.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)

                    Text("No Chats Available")
                        .font(.headline)
                        .foregroundColor(.gray)

                    Text("Start a new conversation or create a group to get started.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    Button(action: {
                        showNewChat = true
                    }) {
                        Label("New Chat", systemImage: "plus.circle")
                            .font(.system(size: 16, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            } else {
                // Show both if "All" is selected
                if selectedChatType == nil {
                    if !privateChats.isEmpty {
                        Section(header: Text("Direct Messages")) {
                            ForEach(privateChats) { chat in
                                EnhancedChatRow(chat: chat)
                            }
                        }
                    }
                    if !groupChats.isEmpty {
                        Section(header: Text("Group Chats")) {
                            ForEach(groupChats, id: \.self) { chat in
                                EnhancedGroupChatRow(chat: chat)
                            }
                        }
                    }
                } else if selectedChatType == .direct {
                    if !privateChats.isEmpty {
                        Section(header: Text("Direct Messages")) {
                            ForEach(privateChats) { chat in
                                EnhancedChatRow(chat: chat)
                            }
                        }
                    } else {
                        noChatsMessage(type: "Direct")
                    }
                } else if selectedChatType == .group {
                    if !groupChats.isEmpty {
                        Section(header: Text("Group Chats")) {
                            ForEach(groupChats, id: \.self) { chat in
                                EnhancedGroupChatRow(chat: chat)
                            }
                        }
                    } else {
                        noChatsMessage(type: "Group")
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }

    private func noChatsMessage(type: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: type == "Direct" ? "bubble.left.and.bubble.right.fill" : "person.3.fill")
                .font(.system(size: 50))
                .foregroundColor(.gray)

            Text("No \(type) Chats")
                .font(.headline)
                .foregroundColor(.gray)

            Text("Start a \(type.lowercased()) chat to see conversations here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Button(action: {
                showNewChat = true
            }) {
                Label("New Chat", systemImage: "plus.circle")
                    .font(.system(size: 16, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }


    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading chats...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            if !searchText.isEmpty {
                Text("No chats matching '\(searchText)'")
                    .font(.headline)
                    .foregroundColor(.gray)
            } else if selectedChatType != nil {
                Text("No \(selectedChatType == .direct ? "direct" : "group") chats")
                    .font(.headline)
                    .foregroundColor(.gray)
                
       
            } else {
                Text("Start a conversation")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                Text("Chat with band members or create a group chat")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Button(action: {
                    showNewChat = true
                }) {
                    Label("Start a new chat", systemImage: "plus.circle")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var chatsList: some View {
        List {
            if !privateChats.isEmpty {
                Section(header: Text("Direct Messages")) {
                    ForEach(privateChats) { chat in
                        EnhancedChatRow(chat: chat)
                    }
                }
            }
            
            
            if !groupChats.isEmpty {
                Section(header: Text("Group Chats")) {
                    ForEach(groupChats,id:\.self) { chat in
                        EnhancedGroupChatRow(chat: chat)
                    }
                }
            }

        }
        .listStyle(InsetGroupedListStyle())
    }
    
    // MARK: - Helper Methods
    
    private func refreshChats() {
        if let userId = AppState.shared.user?.id {
            chatService.fetchChats(for: userId)
            groupChatService.fetchGroupChats()
        }
    }

    private func refreshChatsAsync() async {
        isRefreshing = true
        if let userId = AppState.shared.user?.id {
            chatService.fetchChats(for: userId)
            groupChatService.fetchGroupChats()
        }
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isRefreshing = false
    }

}


struct EnhancedChatRow: View {
    let chat: Chat

    @State private var isOnline = false

    var body: some View {
        NavigationLink(destination: ChatDetailView(chat: chat)) {
            HStack(spacing: 12) {
                // Avatar with dynamic color
                ZStack {
                    Circle()
                        .fill(avatarColor(for: chat.name).opacity(0.2))
                        .frame(width: 50, height: 50)

                    Text(chatInitial)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(avatarColor(for: chat.name))

                    if chat.type == .direct && isOnline {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .position(x: 38, y: 38)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(chat.name)
                            .font(.headline)
                            .lineLimit(1)

                        Spacer()

                        if let time = chat.lastMessageTime {
                            Text(timeString(from: time))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    HStack {
                        if let lastMessage = chat.lastMessage {
                            Text(lastMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        } else {
                            Text("No messages yet")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .italic()
                        }

                        Spacer()
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .onAppear {
            checkUserStatus()
        }
    }

    private var chatInitial: String {
        String(chat.name.prefix(1)).uppercased()
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MM/dd/yy"
        }
        return formatter.string(from: date)
    }

    private func checkUserStatus() {
        if chat.type == .direct,
           let currentUserId = AppState.shared.user?.id,
           let otherUserId = chat.participants.keys.first(where: { $0 != currentUserId }) {
            ChatService.shared.observeUserStatus(userId: otherUserId) { online, _ in
                isOnline = online ?? false
            }
        }
    }
}


struct EnhancedGroupChatRow: View {
    let chat: GroupChatModel

    var body: some View {
        NavigationLink(destination: GroupChatView(groupChat: chat)) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(avatarColor(for: chat.groupName).opacity(0.2))
                        .frame(width: 50, height: 50)

                    Text(String(chat.groupName.prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(avatarColor(for: chat.groupName))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(chat.groupName)
                            .font(.headline)
                            .lineLimit(1)

                        Spacer()

                        if let time = chat.lastMessageTime {
                            Text(timeString(from: Date(timeIntervalSince1970: time)))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    HStack {
                        Text(chat.lastMessage ?? "No messages yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        Spacer()
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MM/dd/yy"
        }
        return formatter.string(from: date)
    }
}



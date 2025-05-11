//
//  GroupChatView.swift
//  BandSync
//
//  Created by Akash 's Mac M1 on 25/04/2025.
//

import SwiftUI
import FirebaseDatabase

struct GroupChatView: View {
    let groupChat: GroupChatModel
    @StateObject private var groupChatService = GroupChatService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var messageText = ""
    @State private var replyTo: Message?
    @State private var editMessage: Message?
    @State private var showDeleteAlert = false
    @State private var showDeleteGroupAlert = false
    @State private var messageToDelete: Message?
    @State private var showCopiedToast = false
    @State private var scrollTarget: String?
    @State private var showGroupInfo = false

    @State private var showAddMemberSheet = false
    @State private var availableMembers: [UserModel] = []
    @State private var selectedUserIds: Set<String> = []
    @State private var isAddingMembers = false
    @State private var didInitialLoad = false

    var body: some View {
        VStack(spacing: 0) {
            customHeader
            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(groupChatService.groupMessages) { message in
                            GroupMessageCellView(
                                message: message,
                                isOwnMessage: isOwnMessage(message),
                                originalMessageText: replyText(for: message),
                                onReply: { replyTo = message },
                                onEdit: {
                                    editMessage = message
                                    messageText = message.text
                                },
                                onDelete: {
                                    messageToDelete = message
                                    if let messageToDelete = messageToDelete {
                                        groupChatService.deleteMessage(messageToDelete, in: groupChat.groupId)
                                    }
                                },
                                onCopy: {
                                    copyMessage(message.text)
                                },
                                onJumpToMessage: { id in
                                    scrollTarget = id
                                }
                            )
                            .id(message.id!)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal)
                }
                .onAppear {
                    groupChatService.loadGroupUsers(userIds: groupChat.members)
                    groupChatService.fetchGroupMessages(for: groupChat.groupId) {
                        DispatchQueue.main.async {
                            if let lastMessageID = groupChatService.groupMessages.last?.id, !didInitialLoad {
                                proxy.scrollTo(lastMessageID, anchor: .bottom)
                                didInitialLoad = true
                            }
                        }
                    }
                }
                .onChange(of: groupChatService.groupMessages.count) { _ in
                    // Subsequent messages scroll smoothly
                    if let lastMessageID = groupChatService.groupMessages.last?.id, didInitialLoad {
                        withAnimation {
                            proxy.scrollTo(lastMessageID, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: scrollTarget) { id in
                    if let id = id {
                        withAnimation {
                            proxy.scrollTo(id, anchor: .top)
                        }
                        scrollTarget = nil
                    }
                }
            }


            Divider()
                .padding(.bottom,3)

            messageInput
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .onTapGesture {
            UIApplication.shared.endEditing()
        }

        .alert(isPresented: $showDeleteGroupAlert) {
            Alert(
                title: Text("Delete Group"),
                message: Text("Are you sure you want to delete this group? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    deleteGroup()
                },
                secondaryButton: .cancel()
            )
        }
        .overlay(
            VStack {
                if showCopiedToast {
                    ToastView(message: "Copied!")
                        .padding(.top, 50)
                }
                Spacer()
            }
            .animation(.easeInOut, value: showCopiedToast)
        )
        .sheet(isPresented: $showAddMemberSheet) {
            addMemberSheet
        }
        .background(
            NavigationLink(destination: GroupInfoView(groupChat: groupChat), isActive: $showGroupInfo) {
                EmptyView()
            }
        )
    }

    private var customHeader: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.blue)
            }

            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 36, height: 36)
                Text(String(groupChat.groupName.prefix(1)).uppercased())
                    .font(.subheadline)
                    .foregroundColor(.purple)
            }

            VStack(alignment: .leading) {
                Text(groupChat.groupName)
                    .font(.headline)
                Text("\(groupChat.members.count) members")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Spacer()

            Menu {
                if isGroupAdmin {
                    Button(action: { addMember() }) {
                        Label("Add Member", systemImage: "person.badge.plus")
                    }
                }

                Button(action: { showGroupInfo = true }) {
                    Label("Group Info", systemImage: "info.circle")
                }

                if isGroupAdmin {
                    Button(role: .destructive, action: {
                        showDeleteGroupAlert = true
                    }) {
                        Label("Delete Group", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .font(.title3)
                    .foregroundColor(.blue)
                    .padding(16)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    private var replyView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Replying to:")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(replyTo?.text ?? "")
                    .font(.subheadline)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: {
                replyTo = nil
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(8)
        .padding(.horizontal)
    }

    private var messageInput: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                // Reply Line (inside textfield area)
                if let replyingTo = replyTo {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Replying to:")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text(replyingTo.text)
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }

                        Spacer()

                        Button(action: {
                            replyTo = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    Divider()
                        .padding(.bottom,4)
                }

                // TextField
                TextField("Write a message here", text: $messageText, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(UIColor.systemGray5))
            .cornerRadius(20)

            Button(action: send) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20))
                    .foregroundColor(messageText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }


    private var addMemberSheet: some View {
        NavigationView {
            List {
                ForEach(availableMembers, id: \.id) { member in
                    HStack {
                        Text(member.name)
                            .opacity(groupChat.members.contains(member.id) ? 0.5 : 1.0)
                        Spacer()
                        if groupChat.members.contains(member.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.gray)
                        } else if selectedUserIds.contains(member.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !groupChat.members.contains(member.id) else { return }
                        if selectedUserIds.contains(member.id) {
                            selectedUserIds.remove(member.id)
                        } else {
                            selectedUserIds.insert(member.id)
                        }
                    }
                    .disabled(groupChat.members.contains(member.id))
                }
            }
            .navigationTitle("Add Members")
            .navigationBarItems(
                leading: Button("Cancel") {
                    showAddMemberSheet = false
                    selectedUserIds.removeAll()
                },
                trailing: Button(isAddingMembers ? "Adding..." : "Done") {
                    addSelectedMembers()
                }
                .disabled(selectedUserIds.isEmpty || isAddingMembers)
            )
        }
    }

    private func addSelectedMembers() {
        isAddingMembers = true
        var updatedMembers = groupChat.members
        updatedMembers.append(contentsOf: selectedUserIds)

        groupChatService.updateGroupMembers(groupId: groupChat.groupId, newMemberIds: updatedMembers) { success in
            isAddingMembers = false
            if success {
                showAddMemberSheet = false
                selectedUserIds.removeAll()
            }
        }
    }

    private func send() {
        guard let userId = AppState.shared.user?.id else { return }

        if let editing = editMessage {
        
            groupChatService.editMessage(editing, newText: messageText, in: groupChat.groupId)
            editMessage = nil
            messageText = ""
            return
        }

    
        let newMessage = Message(
            id: UUID().uuidString,
            chatId: groupChat.groupId,
            senderId: userId,
            text: messageText,
            timestamp: Date(),
            replyTo: replyTo?.id,
            seenBy: [userId],
            deliveredTo: [userId],
            isEdited: false
        )

        groupChatService.sendGroupMessage(newMessage, groupId: groupChat.groupId)

        messageText = ""
        replyTo = nil
    }

    private func copyMessage(_ text: String) {
        UIPasteboard.general.string = text
        showCopiedToast = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopiedToast = false
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    private func isOwnMessage(_ message: Message) -> Bool {
        AppState.shared.user?.id == message.senderId
    }

    private func replyText(for message: Message) -> String? {
        message.replyTo.flatMap { replyId in
            groupChatService.groupMessages.first(where: { $0.id == replyId })?.text
        }
    }

    private func addMember() {
        groupChatService.fetchGroupMembers { users in
            self.availableMembers = users
            showAddMemberSheet = true
        }
    }

    private func deleteGroup() {
        Database.database().reference()
            .child("groupchats")
            .child(groupChat.groupId)
            .removeValue { error, _ in
                if let error = error {
                    print("❌ Failed to delete group: \(error.localizedDescription)")
                } else {
                    dismiss()
                }
            }
    }

    private var isGroupAdmin: Bool {
        AppState.shared.user?.id == groupChat.adminId
    }
}

struct GroupMessageCellView: View {
    let message: Message
    let isOwnMessage: Bool
    let originalMessageText: String?
    var onReply: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onCopy: () -> Void
    var onJumpToMessage: (_ messageId: String) -> Void
    @ObservedObject private var groupChatService = GroupChatService.shared

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !isOwnMessage {
                Circle()
                    .fill(avatarColor(for: senderName).opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(initial)
                            .font(.caption)
                            .foregroundColor(avatarColor(for: senderName))
                    )

            } else {
                Spacer()
            }

            VStack(alignment: isOwnMessage ? .trailing : .leading, spacing: 4) {
                // Reply Preview
                if let replyText = originalMessageText, let replyToId = message.replyTo {
                    Button(action: {
                        onJumpToMessage(replyToId)
                    }) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(groupChatService.users[message.replyTo ?? ""]?.name ?? "Reply")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(replyText)
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }

                // Message Bubble with sender name if not own
                VStack(alignment: .leading, spacing: 2) {
                    if !isOwnMessage {
                        Text(senderName)
                            .font(.caption2)
                            .foregroundColor(.red)
                    }

                    Text(message.text)
                        .foregroundColor(isOwnMessage ? .white : .black)

                 
                }
                .padding(12)
                .background(isOwnMessage ? Color.blue : Color(UIColor.systemGray4))
               
                .frame(alignment: isOwnMessage ? .trailing : .leading)
                .background(
                    // 🧼 Force background to match bubble color on long press
                    (isOwnMessage ? Color.blue : Color(UIColor.systemGray4))
                        .contentShape(Rectangle())
                )
                .cornerRadius(10)
                .contextMenu {
                    Button(action: onReply) {
                        Label("Reply", systemImage: "arrowshape.turn.up.left")
                    }
                    Button(action: onCopy) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    if isOwnMessage {
                        Button(action: onEdit) {
                            Label("Edit", systemImage: "square.and.pencil")
                        }
                        Button(role: .destructive, action: onDelete) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                HStack(spacing:2){
                
                    
                    Text(formatTimestamp(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.top, 2)
                        .padding(.horizontal, 6)
                    if message.isEdited == true {
                        Text("edited")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }

//            if isOwnMessage {
//                Spacer().frame(width: 8)
//            }
        }

        .padding(.top, 6)
    }

    private var senderName: String {
        groupChatService.users[message.senderId]?.name ?? "Unknown"
    }

    private var initial: String {
        String(senderName.prefix(1)).uppercased()
    }

    private func formatTimestamp(_ timestamp: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: timestamp)
    }
}

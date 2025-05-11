//
//  ChatDetailView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI
import FirebaseDatabase
import FirebaseFirestore
import UIKit

struct ChatDetailView: View {
    let chat: Chat
    @StateObject private var chatService = ChatService.shared
    @State private var messageText = ""
    @State private var replyTo: Message?
    @State private var editMessage: Message?
    @State private var showDeleteAlert = false
    @State private var messageToDelete: Message?
    @State private var otherUser: UserModel?
    @State private var showEmojiPicker = false
    @State private var isOnline: Bool? = false
    @State private var lastSeen: Date?
    @State private var showCopiedToast = false
    @State private var lastSeenMessageID: String?
    @State private var didInitialLoad = false

    @Environment(\.dismiss) private var dismiss
    private var receiverId: String? {
        guard chat.type == .direct,
              let myId = AppState.shared.user?.id else { return nil }
        return chat.participants.keys.first(where: { $0 != myId })
    }

    var body: some View {
        VStack(spacing: 0) {

            HStack(spacing: 12) {
                Button(action: {
                  dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.blue)
                }

                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Text(initial(for: otherUser?.name ?? chat.name))
                        .font(.subheadline)
                        .foregroundColor(.purple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(otherUser?.name ?? chat.name)
                        .font(.headline)
                        .lineLimit(1)

                    if let isOnline = otherUser?.isOnline, isOnline {
                        Text("Online")
                            .font(.caption2)
                            .foregroundColor(.green)
                    } else if let lastSeen = otherUser?.lastSeen {
                        Text("Last seen: \(relativeDateString(from: lastSeen))")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(chatService.messages) { message in
                            MessageCellView(
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
                                    showDeleteAlert = true
                                },
                                onEmojiTap: { showEmojiPicker.toggle() },
                                onCopy: { copyMessage(message.text) }
                            )
                            .id(message.id ?? UUID().uuidString)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal)
                }
                .onAppear {
                    loadOtherUser()
                    chatService.fetchMessages(for: chat.id ?? "") {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            if !didInitialLoad, let lastMessageID = chatService.messages.last?.id {
                                proxy.scrollTo(lastMessageID, anchor: .bottom)
                                didInitialLoad = true
                            }
                        }
                    }
                }
                .onChange(of: chatService.messages.count) { _ in
                    if didInitialLoad, let lastMessageID = chatService.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastMessageID, anchor: .bottom)
                        }
                    }
                }
            }




            Divider()
                .padding(.bottom,3)

            VStack(spacing: 4) {
                if let replyingTo = replyTo,
                   let original = chatService.messages.first(where: { $0.id == replyingTo.id }) {

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Replying to:")
                                .font(.caption2)
                                .foregroundColor(.gray)

                            Text(original.text)
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
                    .padding(.horizontal, 14)
                }

                HStack(alignment: .bottom, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Write a message", text: $messageText, axis: .vertical)
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

            if showEmojiPicker {
                EmojiPicker { emoji in
                    messageText.append(emoji)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            if let userId = AppState.shared.user?.id {
                chatService.fetchChats(for: userId)
            }
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
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("Delete Message"),
                message: Text("Are you sure you want to delete this message?"),
                primaryButton: .destructive(Text("Delete")) {
                    if let messageToDelete = messageToDelete {
                        chatService.deleteMessage(messageToDelete)
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
    }

    private func initial(for name: String) -> String {
        String(name.prefix(1)).uppercased()
    }

    private func send() {
        guard let userId = AppState.shared.user?.id,
              let chatId = chat.id else { return }

        if let editing = editMessage {
                        chatService.editMessage(editing, newText: messageText)
            messageText = ""
            replyTo = nil

       
            return
        }

        let newMessage = Message(
            chatId: chatId,
            senderId: userId,
            text: messageText,
            timestamp: Date(),
            replyTo: replyTo?.id,
            seenBy: [userId],
            deliveredTo: [userId],
            isEdited: false
        )

        let participants = Array(chat.participants.keys)
        messageText = ""
        replyTo = nil
        chatService.sendMessage(newMessage, participants: participants)

    
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

    private func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func loadOtherUser() {
        if chat.type == .direct,
           let currentUserId = AppState.shared.user?.id {
            if let otherId = chat.participants.keys.first(where: { $0 != currentUserId }) {
                Firestore.firestore().collection("users").document(otherId).getDocument { snapshot, _ in
                    if let user = try? snapshot?.data(as: UserModel.self) {
                        self.otherUser = user
                    }
                    chatService.observeUserStatus(userId: otherId) { online, seen in
                        isOnline = online
                        lastSeen = seen
                    }
                }
            }
        }
    }

    private func isOwnMessage(_ message: Message) -> Bool {
        AppState.shared.user?.id == message.senderId
    }

    private func replyText(for message: Message) -> String? {
        message.replyTo.flatMap { replyId in
            chatService.messages.first(where: { $0.id == replyId })?.text
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = false) {
        if animated {
            withAnimation {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

}


struct MessageCellView: View {
    let message: Message
    let isOwnMessage: Bool
    let originalMessageText: String?
    var onReply: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onEmojiTap: () -> Void
    var onCopy: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !isOwnMessage {
                EmptyView()
            } else {
                Spacer()
            }

            VStack(alignment: isOwnMessage ? .trailing : .leading, spacing: 4) {
                if let replyText = originalMessageText {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reply")
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

                VStack(alignment: .leading, spacing: 2) {
                    Text(message.text)
                        .foregroundColor(isOwnMessage ? .white : dynamicTextColor())
                }
                .padding(12)
                .background(isOwnMessage ? Color.blue : dynamicBubbleColor())
                .frame(alignment: isOwnMessage ? .trailing : .leading)
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

                HStack(spacing: 2) {
                    Text(formatTimestamp(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.top, 2)
                        .padding(.horizontal, 6)
                    if message.isEdited {
                        Text("edited")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }

            if isOwnMessage {
                Spacer().frame(width: 4)
            }
        }
        .padding(.top, 6)
    }

    private func dynamicBubbleColor() -> Color {
        if UITraitCollection.current.userInterfaceStyle == .dark {
            return Color(UIColor.systemGray5)
        } else {
            return Color(UIColor.systemGray4)
        }
    }

    private func dynamicTextColor() -> Color {
        if UITraitCollection.current.userInterfaceStyle == .dark {
            return Color.white
        } else {
            return Color.black 
        }
    }

    private func formatTimestamp(_ timestamp: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: timestamp)
    }
}



struct EmojiPicker: View {
    let onEmojiTap: (String) -> Void

    let emojis = ["😀", "😂", "😍", "🥺", "😢", "😎", "😊", "😜"]

    var body: some View {
        HStack {
            ForEach(emojis, id: \.self) { emoji in
                Text(emoji)
                    .font(.largeTitle)
                    .onTapGesture {
                        onEmojiTap(emoji)
                    }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }
}

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = false) {
    if animated {
        withAnimation {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    } else {
        proxy.scrollTo("bottom", anchor: .bottom)
    }
}


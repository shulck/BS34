//
//  GroupMembersView.swift
//  BandSync
//
//  Created by Akash 's Mac M1 on 20/04/2025.
//

import SwiftUI

struct GroupMembersView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var members: [UserModel] = []
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView("Loading members...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        Spacer()
                    }
                } else if members.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.3.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.gray.opacity(0.4))
                        Text("No group members yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(members, id: \.id) { user in
                                NavigationLink(destination: ChatDetailView(chat: Chat.between(
                                    currentUserId: AppState.shared.user!.id,
                                    and: user.id,
                                    userName: user.name))
                                ) {
                                    MemberCardView(user: user)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Group Members")
            .onAppear {
                ChatService.shared.fetchGroupMembers { users in
                    withAnimation {
                        self.members = users
                        self.isLoading = false
                    }
                }
            }
        }
    }
}

struct MemberCardView: View {
    var user: UserModel

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(user.name.prefix(1))
                        .font(.headline)
                        .foregroundColor(.blue)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.headline)
                Text(user.role.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    GroupMembersView()
}

extension Chat {
    static func between(currentUserId: String, and otherUserId: String, userName: String) -> Chat {
        let chatId = [currentUserId, otherUserId].sorted().joined(separator: "_")
        return Chat(
            id: chatId,
            name: userName,
            type: .direct, 
            participants: [currentUserId: true, otherUserId: true],
            lastMessage: nil,
            lastMessageTime: nil
        )
    }
}

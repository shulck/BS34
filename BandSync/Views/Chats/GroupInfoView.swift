//
//  GroupInfoView.swift
//  BandSync
//
//  Created by Akash 's Mac M1 on 30/04/2025.
//

import SwiftUI

struct GroupInfoView: View {
    let groupChat: GroupChatModel
    @ObservedObject private var groupChatService = GroupChatService.shared

    var body: some View {
        VStack(spacing: 24) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 80, height: 80)
                Text(String(groupChat.groupName.prefix(1)).uppercased())
                    .font(.largeTitle)
                    .foregroundColor(.purple)
            }
            .padding(.top, 40)

            // Name + Member Count
            VStack(spacing: 4) {
                Text(groupChat.groupName)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("\(groupChat.members.count) members")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Divider().padding(.horizontal)

            // Members
            List {
                ForEach(groupChat.members, id: \.self) { userId in
                    if let user = groupChatService.users[userId] {
                        HStack {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 36, height: 36)
                                .overlay(Text(String(user.name.prefix(1)).uppercased()).foregroundColor(.blue))

                            Text(user.name)
                                .font(.body)

                            Spacer()

                            if user.id == groupChat.adminId {
                                Text("Admin")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Group Info")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            groupChatService.loadGroupUsers(userIds: groupChat.members)
        }
    }
}

//
//  CreateGroupChatView.swift
//  BandSync
//
//  Created by Akash 's Mac M1 on 23/04/2025.
//

import SwiftUI

struct CreateGroupChatView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var groupService = GroupChatService.shared
    @State private var groupName = ""
    @State private var selectedUsers: Set<String> = []
    @State private var allUsers: [UserModel] = []
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Group Name")
                        .font(.headline)
                        .foregroundColor(.primary)

                    TextField("Enter group name", text: $groupName)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        .autocapitalization(.words)
                        .textInputAutocapitalization(.words)
                        .foregroundColor(.primary)

                    Text("Add Members")
                        .font(.headline)
                        .foregroundColor(.primary)

                    if allUsers.isEmpty {
                        ProgressView("Loading users...")
                            .padding(.vertical)
                    }
                }
                .padding(.horizontal)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(allUsers) { user in
                            VStack(spacing: 0) {
                                Button(action: {
                                    toggleSelection(for: user.id)
                                }) {
                                    HStack {
                                        Text(user.name)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if selectedUsers.contains(user.id) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal)
                                    .contentShape(Rectangle())
                                }

                                Divider()
                                    .background(Color(UIColor.separator))
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                HStack {
                    Spacer()
                    Button(action: createGroup) {
                        Text(isCreating ? "Creating..." : "Create Group Chat")
                            .fontWeight(.semibold)
                            .padding()
                            .padding(.horizontal,50)
                            .background(Color(UIColor.label))
                            .foregroundColor(Color(UIColor.systemBackground))
                            .cornerRadius(12)
                            .opacity((groupName.isEmpty || selectedUsers.isEmpty || isCreating) ? 0.5 : 1)
                    }
                    .disabled(groupName.isEmpty || selectedUsers.isEmpty || isCreating)
                    Spacer()
                }
                .padding([.horizontal, .bottom])
            }
            .navigationTitle("New Group Chat")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onTapGesture {
                hideKeyboard()
            }
            .onAppear {
                fetchAllUsers()
            }
        }
    }

    private func fetchAllUsers() {
        groupService.fetchGroupMembers { users in
            self.allUsers = users
        }
    }

    private func toggleSelection(for userId: String) {
        if selectedUsers.contains(userId) {
            selectedUsers.remove(userId)
        } else {
            selectedUsers.insert(userId)
        }
    }

    private func createGroup() {
        isCreating = true
        errorMessage = nil

        groupService.createGroup(groupName: groupName, selectedUserIds: selectedUsers) { result in
            isCreating = false
            switch result {
            case .success:
                dismiss()
            case .failure(let error):
                errorMessage = "Failed to create group: \(error.localizedDescription)"
                print(errorMessage)
            }
        }
    }
}


// Hide keyboard on tap
#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

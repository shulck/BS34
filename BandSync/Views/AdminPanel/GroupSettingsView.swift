//
//  GroupSettingsView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 31.03.2025.
//

import SwiftUI

struct GroupSettingsView: View {
    @StateObject private var groupService = GroupService.shared
    @State private var newName = ""
    @State private var showConfirmation = false
    @State private var showSuccessAlert = false
    
    var body: some View {
        Form {
            // Group name
            Section(header: Text("Group name")) {
                TextField("Group name", text: $newName)
                    .autocapitalization(.words)
                
                Button("Update name") {
                    groupService.updateGroupName(newName)
                    showSuccessAlert = true
                }
                .disabled(newName.isEmpty || groupService.isLoading)
            }
            
            // Invitation code
            if let group = groupService.group {
                Section(header: Text("Invitation code")) {
                    HStack {
                        Text(group.code)
                            .font(.system(.title3, design: .monospaced))
                            .bold()
                        
                        Spacer()
                        
                        Button {
                            UIPasteboard.general.string = group.code
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                    
                    Button("Generate new code") {
                        showConfirmation = true
                    }
                    .foregroundColor(.blue)
                }
            }
            
            // Group members (brief information)
            Section(header: Text("Members")) {
                NavigationLink(destination: UsersListView()) {
                    HStack {
                        Text("Manage members")
                        Spacer()
                        Text("\(groupService.groupMembers.count)")
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // Module management (functionality for enabling/disabling modules can be added here)
            Section(header: Text("Available modules")) {
                Text("Module management will be available in the next update.")
                    .foregroundColor(.gray)
            }
            
            // Display errors
            if let error = groupService.errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
            
            // Loading indicator
            if groupService.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Group settings")
        .onAppear {
            if let gid = AppState.shared.user?.groupId {
                groupService.fetchGroup(by: gid)
                newName = groupService.group?.name ?? ""
            }
        }
        .onChange(of: groupService.group) { newGroup in
            if let name = newGroup?.name {
                newName = name
            }
        }
        .alert("Generate new code?", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Generate") {
                groupService.regenerateCode()
                showSuccessAlert = true
            }
        } message: {
            Text("The old code will no longer be valid. All members who haven't joined yet will need to use the new code.")
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Changes saved successfully.")
        }
    }
}

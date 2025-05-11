//
//  AdminPanelView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 31.03.2025.
//

import SwiftUI

struct AdminPanelView: View {
    @StateObject private var groupService = GroupService.shared
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Group management")) {
                    // Group settings
                    NavigationLink(destination: GroupSettingsView()) {
                        Label("Group settings", systemImage: "gearshape")
                    }
                    
                    // Member management
                    NavigationLink(destination: UsersListView()) {
                        Label("Group members", systemImage: "person.3")
                    }
                    
                    // Permission management
                    NavigationLink(destination: PermissionsView()) {
                        Label("Permissions", systemImage: "lock.shield")
                    }
                    
                    // Module management
                    NavigationLink(destination: ModuleManagementView()) {
                        Label("App modules", systemImage: "square.grid.2x2")
                    }
                }
                
                Section(header: Text("Statistics")) {
                    // App usage statistics
                    Label("Number of members: \(groupService.groupMembers.count)", systemImage: "person.2")
                    
                    if let group = groupService.group {
                        Label("Group name: \(group.name)", systemImage: "music.mic")
                        
                        // Invitation code with copy option
                        HStack {
                            Label("Invitation code: \(group.code)", systemImage: "qrcode")
                            Spacer()
                            Button {
                                UIPasteboard.general.string = group.code
                                alertMessage = "Code copied to clipboard"
                                showAlert = true
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                Section(header: Text("Additional")) {
                    Button(action: {
                        // Function for testing notifications
                        alertMessage = "Notifications will be implemented in the next update"
                        showAlert = true
                    }) {
                        Label("Test notifications", systemImage: "bell")
                    }
                    
                    Button(action: {
                        // Data export function
                        alertMessage = "Data export will be implemented in the next update"
                        showAlert = true
                    }) {
                        Label("Export group data", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .navigationTitle("Admin panel")
            .onAppear {
                if let groupId = AppState.shared.user?.groupId {
                    groupService.fetchGroup(by: groupId)
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Information"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .refreshable {
                if let groupId = AppState.shared.user?.groupId {
                    groupService.fetchGroup(by: groupId)
                }
            }
        }
    }
}

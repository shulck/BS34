//
//  ModuleManagementView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  ModuleManagementView.swift
//  BandSync
//
//  Created by Claude AI on 31.03.2025.
//

import SwiftUI

struct ModuleManagementView: View {
    @StateObject private var permissionService = PermissionService.shared
    @State private var modules = ModuleType.allCases
    @State private var enabledModules: Set<ModuleType> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    var body: some View {
        List {
            Section(header: Text("Available modules")) {
                Text("Enable or disable modules that will be available to group members.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            ForEach(modules) { module in
                HStack {
                    Image(systemName: module.icon)
                        .foregroundColor(.blue)
                    
                    Text(module.displayName)
                    
                    Spacer()
                    
                    if module == .admin {
                        Text("Always enabled")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        Toggle("", isOn: Binding(
                            get: { enabledModules.contains(module) },
                            set: { newValue in
                                if newValue {
                                    enabledModules.insert(module)
                                } else {
                                    enabledModules.remove(module)
                                }
                            }
                        ))
                    }
                }
            }
            
            Section {
                Button("Save changes") {
                    saveChanges()
                }
                .disabled(isLoading)
            }
            
            // Success or error messages
            if let success = successMessage {
                Section {
                    Text(success)
                        .foregroundColor(.green)
                }
            }
            
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
            
            // Loading indicator
            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Module management")
        .onAppear {
            loadModuleSettings()
        }
    }
    
    // Load current module settings
    private func loadModuleSettings() {
        isLoading = true
        successMessage = nil
        errorMessage = nil
        
        if let groupId = AppState.shared.user?.groupId {
            permissionService.fetchPermissions(for: groupId)
            
            // Use delay to give time for permissions to load
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Initialize list of enabled modules
                enabledModules = Set(permissionService.permissions?.modules
                    .filter { !$0.roleAccess.isEmpty }
                    .map { $0.moduleId } ?? [])
                
                // Admin is always enabled
                enabledModules.insert(.admin)
                
                isLoading = false
            }
        } else {
            isLoading = false
            errorMessage = "Could not determine group"
        }
    }
    
    // Save changes
    private func saveChanges() {
        guard let permissionId = permissionService.permissions?.id else {
            errorMessage = "Could not find permission settings"
            return
        }
        
        isLoading = true
        successMessage = nil
        errorMessage = nil
        
        // For each module except Admin
        for module in modules where module != .admin {
            // Determine which roles should have access
            let roles: [UserModel.UserRole]
            
            if enabledModules.contains(module) {
                // If module is enabled, use current role settings or defaults
                roles = permissionService.getRolesWithAccess(to: module)
                
                // If no roles, set default access settings
                if roles.isEmpty {
                    switch module {
                    case .finances, .merchandise, .contacts:
                        // Finances, merch and contacts require management rights
                        permissionService.updateModulePermission(
                            moduleId: module,
                            roles: [.admin, .manager]
                        )
                    case .calendar, .setlists, .tasks, .chats:
                        // Basic modules available to all
                        permissionService.updateModulePermission(
                            moduleId: module,
                            roles: [.admin, .manager, .musician, .member]
                        )
                    default:
                        break
                    }
                }
            } else {
                // If module is disabled, set empty role list
                permissionService.updateModulePermission(
                    moduleId: module,
                    roles: []
                )
            }
        }
        
        // Delay to complete all update operations
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isLoading = false
            successMessage = "Module settings successfully updated"
        }
    }
}
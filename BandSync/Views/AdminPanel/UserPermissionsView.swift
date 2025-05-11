import SwiftUI

struct UserPermissionsView: View {
    let userId: String
    let userName: String
    @StateObject private var permissionService = PermissionService.shared
    @StateObject private var groupService = GroupService.shared
    @State private var selectedModules: Set<ModuleType> = []
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Персональный доступ")) {
                    Text("Предоставьте доступ к модулям для \(userName) независимо от роли")
                        .font(.footnote)
                }
                
                Section(header: Text("Модули")) {
                    ForEach(ModuleType.allCases) { module in
                        Button {
                            toggleModule(module)
                        } label: {
                            HStack {
                                Image(systemName: module.icon)
                                    .foregroundColor(.blue)
                                Text(module.displayName)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedModules.contains(module) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                if let user = groupService.groupMembers.first(where: { $0.id == userId }) {
                    Section(header: Text("Доступно по роли (\(user.role.rawValue))")) {
                        let roleModules = permissionService.getAccessibleModules(for: user.role)
                        ForEach(roleModules) { module in
                            HStack {
                                Image(systemName: module.icon)
                                    .foregroundColor(.gray)
                                Text(module.displayName)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("По умолчанию")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                if permissionService.isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Персональный доступ")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        savePersonalPermissions()
                    }
                }
            }
            .onAppear {
                loadUserPermissions()
            }
        }
    }
    
    // Загрузка текущих разрешений
    private func loadUserPermissions() {
        if let userPermission = permissionService.permissions?.userPermissions.first(where: { $0.userId == userId }) {
            selectedModules = Set(userPermission.modules)
        }
    }
    
    // Переключение модуля
    private func toggleModule(_ module: ModuleType) {
        if selectedModules.contains(module) {
            selectedModules.remove(module)
        } else {
            selectedModules.insert(module)
        }
    }
    
    // Сохранение настроек
    private func savePersonalPermissions() {
        permissionService.updateUserPermissions(
            userId: userId,
            modules: Array(selectedModules)
        )
        dismiss()
    }
}
//
//  UsersListView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 31.03.2025.
//

import SwiftUI

struct UsersListView: View {
    @StateObject private var groupService = GroupService.shared
    @StateObject private var permissionService = PermissionService.shared // Добавляем для проверки разрешений
    @State private var selectedUserId = ""
    @State private var selectedUser: UserModel? = nil
    @State private var selectedUserName = "" // Добавляем переменную, если её еще нет
    @State private var showingRoleView = false
    @State private var showingPersonalAccessView = false
    @State private var showingPermissionDetails = false // Для отображения детальной информации
    
    var body: some View {
        List {
            if groupService.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else {
                // Group members
                if !groupService.groupMembers.isEmpty {
                    Section(header: Text("Members")) {
                        ForEach(groupService.groupMembers) { user in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(user.name)
                                        .font(.headline)
                                    Text(user.email)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text("Role: \(user.role.rawValue)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    // Добавляем более информативный индикатор персональных разрешений
                                    if permissionService.hasAnyPersonalAccess(userId: user.id) {
                                        Button {
                                            selectedUserId = user.id
                                            selectedUserName = user.name
                                            showingPermissionDetails = true
                                        } label: {
                                            HStack {
                                                Image(systemName: "key.fill")
                                                    .foregroundColor(.blue)
                                                    .font(.caption)
                                                
                                                let modules = permissionService.getPersonalAccessModules(userId: user.id)
                                                Text("Персональный доступ (\(modules.count))")
                                                    .font(.caption)
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                // Action buttons
                                if user.id != AppState.shared.user?.id {
                                    Menu {
                                        Button("Change role") {
                                            selectedUserId = user.id
                                            selectedUser = user
                                            showingRoleView = true
                                        }
                                        
                                        Button("Personal access") {
                                            selectedUserId = user.id
                                            selectedUserName = user.name
                                            showingPersonalAccessView = true
                                        }
                                        
                                        Button("Remove from group", role: .destructive) {
                                            groupService.removeUser(userId: user.id)
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Pending approvals
                if !groupService.pendingMembers.isEmpty {
                    Section(header: Text("Awaiting approval")) {
                        ForEach(groupService.pendingMembers) { user in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(user.name)
                                        .font(.headline)
                                    Text(user.email)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                // Accept/reject buttons
                                Button {
                                    groupService.approveUser(userId: user.id)
                                } label: {
                                    Text("Accept")
                                        .foregroundColor(.green)
                                }
                                
                                Button {
                                    groupService.rejectUser(userId: user.id)
                                } label: {
                                    Text("Decline")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
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
                            groupService.regenerateCode()
                        }
                    }
                }
            }
            
            if let error = groupService.errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Group members")
        .onAppear {
            if let gid = AppState.shared.user?.groupId {
                groupService.fetchGroup(by: gid)
                permissionService.fetchPermissions(for: gid)
            }
        }
        .sheet(isPresented: $showingRoleView) {
            if !selectedUserId.isEmpty, let user = selectedUser {
                RoleSelectionView(userId: selectedUserId, userName: user.name)
            }
        }
        .sheet(isPresented: $showingPersonalAccessView) {
            UserPermissionsView(userId: selectedUserId, userName: selectedUserName)
        }
        .sheet(isPresented: $showingPermissionDetails) {
            PersonalPermissionsDetailView(userId: selectedUserId, userName: selectedUserName)
        }
        .refreshable {
            if let gid = AppState.shared.user?.groupId {
                groupService.fetchGroup(by: gid)
            }
        }
    }
}

// Role selection view
struct RoleSelectionView: View {
    let userId: String
    let userName: String // Добавим имя для наглядности
    @StateObject private var groupService = GroupService.shared
    @State private var selectedRole: UserModel.UserRole = .member
    @Environment(\.dismiss) var dismiss
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Выберите роль для \(userName)")) {
                    ForEach(UserModel.UserRole.allCases, id: \.self) { role in
                        Button {
                            selectedRole = role
                        } label: {
                            HStack {
                                Text(role.rawValue)
                                Spacer()
                                if selectedRole == role {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                // Добавим кнопку сохранения вместо автоматического закрытия
                Section {
                    Button("Сохранить") {
                        if !userId.isEmpty {
                            groupService.changeUserRole(userId: userId, newRole: selectedRole)
                            dismiss()
                        } else {
                            errorMessage = "Невозможно изменить роль: ID пользователя пустой"
                        }
                    }
                    .disabled(userId.isEmpty)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.blue)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                if groupService.isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
                
                if let error = groupService.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Изменение роли")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            print("RoleSelectionView appeared with userId: \(userId)")
            // Try to find the user's current role
            if let user = groupService.groupMembers.first(where: { $0.id == userId }) {
                selectedRole = user.role
            }
        }
    }
}

// Представление для отображения деталей персональных разрешений
struct PersonalPermissionsDetailView: View {
    let userId: String
    let userName: String
    @StateObject private var permissionService = PermissionService.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Персональные разрешения")) {
                    Text("Модули, доступные для \(userName) независимо от роли")
                        .font(.footnote)
                }
                
                Section(header: Text("Разрешенные модули")) {
                    let modules = permissionService.getPersonalAccessModules(userId: userId)
                    
                    if modules.isEmpty {
                        Text("Нет персональных разрешений")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(modules) { module in
                            HStack {
                                // Иконка модуля (если есть свойство icon)
                                Image(systemName: moduleIcon(for: module))
                                    .foregroundColor(.blue)
                                // Название модуля
                                Text(moduleDisplayName(for: module))
                            }
                        }
                    }
                }
                
                Section {
                    Button("Изменить разрешения") {
                        dismiss()
                        // Примечание: Этот код можно расширить для перехода к редактированию,
                        // например, через делегата или глобальное состояние
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Доступ пользователя")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // Вспомогательные функции для отображения информации о модулях
    private func moduleDisplayName(for module: ModuleType) -> String {
        switch module {
        case .admin:
            return "Административная панель"
        case .calendar:
            return "Календарь"
        case .setlists:
            return "Сетлисты"
        case .finances:
            return "Финансы"
        case .tasks:
            return "Задачи"
        case .chats:
            return "Чаты"
        case .merchandise:
            return "Мерчендайз"
        case .contacts:
            return "Контакты"
        }
    }
    
    private func moduleIcon(for module: ModuleType) -> String {
        switch module {
        case .admin:
            return "gear"
        case .calendar:
            return "calendar"
        case .setlists:
            return "music.note.list"
        case .finances:
            return "dollarsign.circle"
        case .tasks:
            return "checklist"
        case .chats:
            return "message"
        case .merchandise:
            return "bag"
        case .contacts:
            return "person.crop.circle"
        }
    }
}

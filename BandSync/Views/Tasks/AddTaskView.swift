//
//  AddTaskView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var groupService = GroupService.shared
    @State private var title = ""
    @State private var description = ""
    @State private var assignedTo = ""
    @State private var dueDate = Date()
    @State private var priority: TaskPriority = .medium
    @State private var category: TaskCategory = .other
    @State private var showUserPicker = false
    @State private var selectedUser: UserModel?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var addReminder = false
    
    // For subtasks
    @State private var subtasks: [Subtask] = []
    @State private var newSubtaskTitle = ""
    
    // Available group members
    @State private var groupMembers: [UserModel] = []
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Information")) {
                    TextField("Task Title", text: $title)
                    
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date])
                    
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases) { priority in
                            HStack {
                                Circle()
                                    .fill(Color(hex: priority.color))
                                    .frame(width: 12, height: 12)
                                Text(priority.rawValue)
                            }
                            .tag(priority)
                        }
                    }
                    
                    Picker("Category", selection: $category) {
                        ForEach(TaskCategory.allCases) { category in
                            Label(category.rawValue, systemImage: category.iconName)
                                .tag(category)
                        }
                    }
                    
                    HStack {
                        Text("Assigned To")
                        Spacer()
                        
                        Button(action: {
                            // Убедимся, что список пользователей загружен перед открытием окна
                            if groupMembers.isEmpty {
                                loadGroupMembers()
                            }
                            showUserPicker = true
                        }) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text(selectedUser?.name ?? "Select User")
                                    .foregroundColor(selectedUser != nil ? .primary : .blue)
                            }
                        }
                        .disabled(isLoading)
                    }
                }
                
                Section(header: Text("Description")) {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                }
                
                Section(header: Text("Subtasks")) {
                    HStack {
                        TextField("Add Subtask", text: $newSubtaskTitle)
                        
                        Button(action: addSubtask) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .disabled(newSubtaskTitle.isEmpty)
                    }
                    
                    ForEach(subtasks) { subtask in
                        HStack {
                            Text(subtask.title)
                            Spacer()
                        }
                    }
                    .onDelete(perform: deleteSubtask)
                }
                
                Section(header: Text("Reminder")) {
                    Toggle("Add Reminder", isOn: $addReminder)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTask()
                    }
                    .disabled(title.isEmpty || selectedUser == nil || isLoading)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadGroupMembers()
            }
            .sheet(isPresented: $showUserPicker) {
                UserPickerView(selectedUser: $selectedUser, users: groupMembers)
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .padding()
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(8)
                }
            }
        }
    }
    
    private func loadGroupMembers() {
        if let groupId = AppState.shared.user?.groupId {
            isLoading = true
            
            // Загружаем список участников группы, если он еще не загружен
            if groupService.groupMembers.isEmpty {
                groupService.fetchGroup(by: groupId)
                
                // Добавляем задержку, чтобы убедиться, что данные успели загрузиться
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    // Копируем участников группы в локальное состояние
                    self.groupMembers = groupService.groupMembers
                    self.isLoading = false
                    
                    if self.groupMembers.isEmpty {
                        self.errorMessage = "Failed to load group members. Please try again."
                    }
                }
            } else {
                // Если список уже загружен, просто копируем его
                self.groupMembers = groupService.groupMembers
                self.isLoading = false
            }
        } else {
            self.errorMessage = "No group ID found"
            self.isLoading = false
        }
    }
    
    private func addSubtask() {
        guard !newSubtaskTitle.isEmpty else { return }
        
        let subtask = Subtask(title: newSubtaskTitle, completed: false)
        subtasks.append(subtask)
        newSubtaskTitle = ""
    }
    
    private func deleteSubtask(at offsets: IndexSet) {
        subtasks.remove(atOffsets: offsets)
    }
    
    private func saveTask() {
        guard let user = AppState.shared.user,
              let groupId = user.groupId,
              let selectedUser = selectedUser else {
            errorMessage = "Missing required information"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Create reminders
        var reminders: [Date]?
        if addReminder {
            let reminderDate = Calendar.current.date(byAdding: .day, value: -1, to: dueDate) ?? dueDate
            reminders = [reminderDate]
        }
        
        // Create task
        let task = TaskModel(
            title: title,
            description: description,
            assignedTo: selectedUser.id,
            dueDate: dueDate,
            groupId: groupId,
            priority: priority,
            category: category,
            attachments: nil,
            subtasks: subtasks.isEmpty ? nil : subtasks,
            reminders: reminders,
            createdBy: user.id
        )
        
        // Save task
        TaskService.shared.addTask(task) { success in
            isLoading = false
            
            if success {
                dismiss()
            } else {
                errorMessage = "Failed to save task. Please try again."
            }
        }
    }
}

// User picker view
struct UserPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedUser: UserModel?
    let users: [UserModel]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @StateObject private var groupService = GroupService.shared
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading users...")
                } else if let error = errorMessage {
                    VStack {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                        
                        Button("Retry") {
                            loadUsersIfNeeded()
                        }
                        .padding()
                    }
                } else if users.isEmpty {
                    VStack {
                        Text("No users found")
                            .foregroundColor(.gray)
                            .padding()
                        
                        if groupService.groupMembers.isEmpty {
                            Button("Load Group Members") {
                                loadGroupMembers()
                            }
                            .padding()
                        }
                    }
                } else {
                    List {
                        ForEach(users) { user in
                            Button(action: {
                                selectedUser = user
                                dismiss()
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(user.name)
                                            .font(.headline)
                                        
                                        Text(user.role.rawValue)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedUser?.id == user.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
            }
            .navigationTitle("Select User")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadUsersIfNeeded()
            }
        }
    }
    
    private func loadUsersIfNeeded() {
        // If users array is empty, try to use groupService members
        if users.isEmpty && groupService.groupMembers.isEmpty {
            loadGroupMembers()
        }
    }
    
    private func loadGroupMembers() {
        isLoading = true
        errorMessage = nil
        
        if let groupId = AppState.shared.user?.groupId {
            groupService.fetchGroup(by: groupId)
            
            // Добавляем задержку, чтобы убедиться, что данные успели загрузиться
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isLoading = false
                if groupService.groupMembers.isEmpty {
                    errorMessage = "Failed to load group members"
                }
            }
        } else {
            isLoading = false
            errorMessage = "No group ID found"
        }
    }
}

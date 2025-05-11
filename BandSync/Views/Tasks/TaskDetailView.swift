//
//  TaskDetailView.swift
//  BandSyncApp
//
//  Created by Oleksandr Kuziakin on 11.05.2025.
//


//
//  TaskDetailView.swift
//  BandSync
//
//  Created by Anton for BandSync
//

import SwiftUI

struct TaskDetailView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var taskService = TaskService.shared
    @State private var task: TaskModel
    @State private var isEditing = false
    @State private var showDeleteConfirmation = false
    @State private var newSubtaskTitle = ""
    @State private var selectedUser: UserModel?
    @State private var showPriorityPicker = false
    @State private var showCategoryPicker = false
    
    init(task: TaskModel) {
        _task = State(initialValue: task)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header with title and completion status
                    HStack {
                        if isEditing {
                            TextField("Task Title", text: $task.title)
                                .font(.title2)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        } else {
                            Text(task.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .strikethrough(task.completed)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation {
                                task.completed.toggle()
                                TaskService.shared.toggleCompletion(task)
                            }
                        }) {
                            Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundColor(task.completed ? .green : .gray)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Task information section
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Task Details")
                        
                        // Due date
                        DetailRow(icon: "calendar", title: "Due Date") {
                            if isEditing {
                                DatePicker("", selection: $task.dueDate, displayedComponents: [.date])
                                    .labelsHidden()
                            } else {
                                Text(formattedDate(task.dueDate))
                            }
                        }
                        
                        // Priority
                        DetailRow(icon: task.priority.iconName, title: "Priority", iconColor: Color(hex: task.priority.color)) {
                            if isEditing {
                                Menu {
                                    ForEach(TaskPriority.allCases) { priority in
                                        Button(priority.rawValue) {
                                            task.priority = priority
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(task.priority.rawValue)
                                            .foregroundColor(Color(hex: task.priority.color))
                                        Image(systemName: "chevron.down")
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            } else {
                                Text(task.priority.rawValue)
                                    .foregroundColor(Color(hex: task.priority.color))
                            }
                        }
                        
                        // Category
                        DetailRow(icon: task.category.iconName, title: "Category") {
                            if isEditing {
                                Menu {
                                    ForEach(TaskCategory.allCases) { category in
                                        Button(category.rawValue) {
                                            task.category = category
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(task.category.rawValue)
                                        Image(systemName: "chevron.down")
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            } else {
                                Text(task.category.rawValue)
                            }
                        }
                        
                        // Assigned to
                        DetailRow(icon: "person", title: "Assigned To") {
                            Text("User ID: \(task.assignedTo)")
                                .foregroundColor(.secondary)
                        }
                        
                        // Created by
                        DetailRow(icon: "person.fill", title: "Created By") {
                            Text("User ID: \(task.createdBy)")
                                .foregroundColor(.secondary)
                        }
                        
                        // Created & updated dates
                        DetailRow(icon: "clock", title: "Created") {
                            Text(formattedDateWithTime(task.createdAt))
                                .foregroundColor(.secondary)
                        }
                        
                        DetailRow(icon: "clock.arrow.circlepath", title: "Updated") {
                            Text(formattedDateWithTime(task.updatedAt))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Description section
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Description")
                        
                        if isEditing {
                            TextEditor(text: $task.description)
                                .frame(minHeight: 100)
                                .padding(10)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        } else {
                            if task.description.isEmpty {
                                Text("No description provided")
                                    .foregroundColor(.gray)
                                    .italic()
                            } else {
                                Text(task.description)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Subtasks section
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Subtasks")
                        
                        if isEditing {
                            HStack {
                                TextField("Add new subtask", text: $newSubtaskTitle)
                                    .padding(10)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                
                                Button(action: addSubtask) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.blue)
                                }
                                .disabled(newSubtaskTitle.isEmpty)
                            }
                        }
                        
                        if let subtasks = task.subtasks, !subtasks.isEmpty {
                            ForEach(Array(subtasks.enumerated()), id: \.element.id) { index, subtask in
                                HStack {
                                    Button(action: {
                                        toggleSubtask(at: index)
                                    }) {
                                        Image(systemName: subtask.completed ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(subtask.completed ? .green : .gray)
                                    }
                                    
                                    Text(subtask.title)
                                        .strikethrough(subtask.completed)
                                        .foregroundColor(subtask.completed ? .gray : .primary)
                                    
                                    Spacer()
                                    
                                    if isEditing {
                                        Button(action: {
                                            removeSubtask(at: index)
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        } else {
                            Text("No subtasks")
                                .foregroundColor(.gray)
                                .italic()
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Reminders section
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Reminders")
                        
                        if isEditing {
                            Button(action: addDefaultReminder) {
                                Label("Add reminder one day before", systemImage: "bell.badge.plus")
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        if let reminders = task.reminders, !reminders.isEmpty {
                            ForEach(Array(reminders.enumerated()), id: \.offset) { index, reminder in
                                HStack {
                                    Image(systemName: "bell")
                                        .foregroundColor(.orange)
                                    
                                    Text(formattedDateWithTime(reminder))
                                    
                                    Spacer()
                                    
                                    if isEditing {
                                        Button(action: {
                                            removeReminder(at: index)
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                            }
                        } else {
                            Text("No reminders set")
                                .foregroundColor(.gray)
                                .italic()
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditing {
                        Button("Save") {
                            saveTask()
                        }
                    } else {
                        Menu {
                            Button(action: {
                                isEditing = true
                            }) {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive, action: {
                                showDeleteConfirmation = true
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    if isEditing {
                        Button("Cancel") {
                            // Reload original task to discard changes
                            if let originalTask = taskService.tasks.first(where: { $0.id == task.id }) {
                                task = originalTask
                            }
                            isEditing = false
                        }
                    } else {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Delete Task", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    TaskService.shared.deleteTask(task) { success in
                        if success {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to delete this task? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
    }
    
    private func DetailRow<Content: View>(icon: String, title: String, iconColor: Color = .blue, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 20)
            
            Text(title + ":")
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            content()
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Helper Methods
    
    private func addSubtask() {
        guard !newSubtaskTitle.isEmpty else { return }
        
        let newSubtask = Subtask(title: newSubtaskTitle, completed: false)
        
        if task.subtasks == nil {
            task.subtasks = [newSubtask]
        } else {
            task.subtasks?.append(newSubtask)
        }
        
        newSubtaskTitle = ""
    }
    
    private func toggleSubtask(at index: Int) {
        guard var subtasks = task.subtasks, index < subtasks.count else { return }
        
        subtasks[index].completed.toggle()
        task.subtasks = subtasks
        
        if !isEditing {
            // Save immediately if not in edit mode
            TaskService.shared.updateTask(task) { _ in }
        }
    }
    
    private func removeSubtask(at index: Int) {
        guard var subtasks = task.subtasks, index < subtasks.count else { return }
        
        subtasks.remove(at: index)
        task.subtasks = subtasks
    }
    
    private func addDefaultReminder() {
        let reminder = Calendar.current.date(byAdding: .day, value: -1, to: task.dueDate) ?? task.dueDate
        
        if task.reminders == nil {
            task.reminders = [reminder]
        } else {
            task.reminders?.append(reminder)
        }
    }
    
    private func removeReminder(at index: Int) {
        guard var reminders = task.reminders, index < reminders.count else { return }
        
        reminders.remove(at: index)
        task.reminders = reminders
    }
    
    private func saveTask() {
        task.updatedAt = Date()
        
        TaskService.shared.updateTask(task) { success in
            if success {
                isEditing = false
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formattedDateWithTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
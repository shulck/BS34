//
//  TaskService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseFirestore
import Combine

final class TaskService: ObservableObject {
    static let shared = TaskService()

    @Published var tasks: [TaskModel] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var cacheService = CacheService.shared
    private var cancellables = Set<AnyCancellable>()

    // Fetch tasks for a specific group
    func fetchTasks(for groupId: String) {
        isLoading = true
        errorMessage = nil
        
        // First try to load from cache
        if let cachedTasks = cacheService.getCachedTasks(forGroupId: groupId) {
            self.tasks = cachedTasks
            self.isLoading = false
        }
        
        // Then fetch from Firestore
        db.collection("tasks")
            .whereField("groupId", isEqualTo: groupId)
            .order(by: "dueDate")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        self.errorMessage = "Error loading tasks: \(error.localizedDescription)"
                        return
                    }
                    
                    if let docs = snapshot?.documents {
                        var loadedTasks: [TaskModel] = []
                        
                        for doc in docs {
                            do {
                                let task = try doc.data(as: TaskModel.self)
                                loadedTasks.append(task)
                            } catch {
                                print("Error decoding task: \(error.localizedDescription)")
                            }
                        }
                        
                        self.tasks = loadedTasks
                        
                        // Cache tasks for offline use
                        self.cacheService.cacheTasks(loadedTasks, forGroupId: groupId)
                        
                        // Schedule notifications for upcoming tasks
                        self.scheduleTaskReminders(loadedTasks)
                    }
                }
            }
    }

    // Add a new task
    func addTask(_ task: TaskModel, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        
        do {
            var newTask = task
            newTask.updatedAt = Date()
            
            _ = try db.collection("tasks").addDocument(from: newTask) { [weak self] error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        self.errorMessage = "Error adding task: \(error.localizedDescription)"
                        completion(false)
                    } else {
                        // If task has reminders, schedule notifications
                        if let reminders = newTask.reminders, !reminders.isEmpty {
                            self.scheduleTaskReminders([newTask])
                        }
                        
                        completion(true)
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Error serializing task: \(error.localizedDescription)"
                completion(false)
            }
        }
    }

    // Toggle task completion status
    func toggleCompletion(_ task: TaskModel) {
        guard let id = task.id else { return }
        
        var updatedTask = task
        updatedTask.completed = !task.completed
        updatedTask.updatedAt = Date()
        
        updateTask(updatedTask) { _ in }
    }

    // Update an existing task
    func updateTask(_ task: TaskModel, completion: @escaping (Bool) -> Void) {
        guard let id = task.id else {
            completion(false)
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            var updatedTask = task
            updatedTask.updatedAt = Date()
            
            try db.collection("tasks").document(id).setData(from: updatedTask) { [weak self] error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        self.errorMessage = "Error updating task: \(error.localizedDescription)"
                        completion(false)
                    } else {
                        // Cancel existing notifications and schedule new ones
                        self.cancelTaskReminders(id)
                        if let reminders = updatedTask.reminders, !reminders.isEmpty {
                            self.scheduleTaskReminders([updatedTask])
                        }
                        
                        completion(true)
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Error serializing task: \(error.localizedDescription)"
                completion(false)
            }
        }
    }

    // Delete a task
    func deleteTask(_ task: TaskModel, completion: @escaping (Bool) -> Void = { _ in }) {
        guard let id = task.id else {
            completion(false)
            return
        }
        
        isLoading = true
        
        db.collection("tasks").document(id).delete { [weak self] error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error deleting task: \(error.localizedDescription)"
                    completion(false)
                } else {
                    // Cancel all notifications for this task
                    self.cancelTaskReminders(id)
                    
                    // Remove from local list
                    self.tasks.removeAll { $0.id == id }
                    
                    completion(true)
                }
            }
        }
    }
    
    // Schedule notifications for task reminders
    private func scheduleTaskReminders(_ tasks: [TaskModel]) {
        for task in tasks {
            guard let id = task.id, !task.completed else { continue }
            
            // Default reminder 1 day before due date if no custom reminders
            let reminders = task.reminders ?? [Calendar.current.date(byAdding: .day, value: -1, to: task.dueDate) ?? task.dueDate]
            
            for (index, reminder) in reminders.enumerated() {
                // Skip past reminders
                if reminder <= Date() { continue }
                
                let title = "Task Reminder"
                let body = "\(task.title) is due on \(formattedDate(task.dueDate))"
                let identifier = "task_reminder_\(id)_\(index)"
                
                NotificationManager.shared.scheduleLocalNotification(
                    title: title,
                    body: body,
                    date: reminder,
                    identifier: identifier,
                    userInfo: ["type": "task", "taskId": id]
                ) { _ in }
            }
        }
    }
    
    // Cancel notifications for a specific task
    private func cancelTaskReminders(_ taskId: String) {
        // We don't know how many reminders there might be, so we'll try to cancel several
        for i in 0..<10 {
            NotificationManager.shared.cancelNotification(withIdentifier: "task_reminder_\(taskId)_\(i)")
        }
    }
    
    // Helper method to format dates
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Filtering and Sorting Methods
    
    // Get pending (incomplete) tasks
    func getPendingTasks() -> [TaskModel] {
        return tasks.filter { !$0.completed }.sorted { $0.dueDate < $1.dueDate }
    }
    
    // Get completed tasks
    func getCompletedTasks() -> [TaskModel] {
        return tasks.filter { $0.completed }.sorted { $0.dueDate > $1.dueDate }
    }
    
    // Get tasks by priority
    func getTasks(withPriority priority: TaskPriority) -> [TaskModel] {
        return tasks.filter { $0.priority == priority }
    }
    
    // Get tasks by category
    func getTasks(withCategory category: TaskCategory) -> [TaskModel] {
        return tasks.filter { $0.category == category }
    }
    
    // Get tasks assigned to a specific user
    func getTasks(assignedTo userId: String) -> [TaskModel] {
        return tasks.filter { $0.assignedTo == userId }
    }
    
    // Get tasks created by a specific user
    func getTasks(createdBy userId: String) -> [TaskModel] {
        return tasks.filter { $0.createdBy == userId }
    }
    
    // Get tasks due soon (within next 7 days)
    func getTasksDueSoon() -> [TaskModel] {
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return tasks.filter { !$0.completed && $0.dueDate <= nextWeek && $0.dueDate >= Date() }
    }
    
    // Get overdue tasks
    func getOverdueTasks() -> [TaskModel] {
        return tasks.filter { !$0.completed && $0.dueDate < Date() }
    }
    
    // Search tasks by title or description
    func searchTasks(query: String) -> [TaskModel] {
        let lowercasedQuery = query.lowercased()
        return tasks.filter {
            $0.title.lowercased().contains(lowercasedQuery) ||
            $0.description.lowercased().contains(lowercasedQuery)
        }
    }
}

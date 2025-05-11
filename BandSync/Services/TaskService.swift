// Обновление функции addTask в TaskService.swift

import Foundation
import FirebaseFirestore
import Combine
import FirebaseMessaging

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

    // Add a new task with notification to assigned user
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
                        // Если задача имеет напоминания, запланировать уведомления
                        if let reminders = newTask.reminders, !reminders.isEmpty {
                            self.scheduleTaskReminders([newTask])
                        }
                        
                        // Отправить уведомление о назначении задачи
                        self.sendTaskAssignmentNotification(newTask)
                        
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

    // Send notification for task assignment
    func sendTaskAssignmentNotification(_ task: TaskModel) {
        guard let taskId = task.id else { return }
        
        // 1. Отправка локального уведомления, если задача назначена текущему пользователю
        if task.assignedTo == AppState.shared.user?.id {
            let title = "New Task Assigned"
            let body = "You've been assigned a new task: \(task.title)"
            let identifier = "task_assignment_\(taskId)"
            
            NotificationManager.shared.scheduleLocalNotification(
                title: title,
                body: body,
                date: Date(), // Немедленное уведомление
                identifier: identifier,
                userInfo: [
                    "type": "task",
                    "taskId": taskId,
                    "action": "assignment"
                ]
            ) { _ in }
        }
        
        // 2. Отправка push-уведомления через FCM
        sendRemoteNotification(for: task)
    }
    
    // Send push notification through Firebase Cloud Messaging
    private func sendRemoteNotification(for task: TaskModel) {
        // Получаем данные о пользователе, которому назначена задача
        db.collection("users").document(task.assignedTo).getDocument { snapshot, error in
            guard let snapshot = snapshot, let userData = snapshot.data(),
                  let fcmToken = userData["fcmToken"] as? String else {
                print("Failed to find FCM token for user: \(task.assignedTo)")
                return
            }
            
            // Получаем данные о пользователе, создавшем задачу
            self.db.collection("users").document(task.createdBy).getDocument { creatorSnapshot, creatorError in
                var creatorName = "Someone"
                
                if let creatorData = creatorSnapshot?.data(),
                   let name = creatorData["name"] as? String {
                    creatorName = name
                }
                
                // Создаем данные для уведомления
                let message = [
                    "token": fcmToken,
                    "notification": [
                        "title": "New Task Assignment",
                        "body": "\(creatorName) assigned you a task: \(task.title)"
                    ],
                    "data": [
                        "taskId": task.id ?? "",
                        "type": "task_assignment",
                        "priority": task.priority.rawValue,
                        "dueDate": "\(Int(task.dueDate.timeIntervalSince1970))"
                    ],
                    "apns": [
                        "payload": [
                            "aps": [
                                "sound": "default",
                                "badge": 1
                            ]
                        ]
                    ]
                ]
                
                // Вызов Cloud Function для отправки уведомления
                // Обратите внимание, что для этого нужна настроенная Cloud Function в Firebase
                let functions = Functions.functions()
                functions.httpsCallable("sendTaskNotification").call(message) { result, error in
                    if let error = error {
                        print("Error sending push notification: \(error)")
                    } else {
                        print("Push notification sent successfully")
                    }
                }
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
        
        // Если задача отмечена как выполненная, отправить уведомление создателю
        if updatedTask.completed && task.createdBy != AppState.shared.user?.id {
            sendTaskCompletionNotification(updatedTask)
        }
    }
    
    // Send notification about task completion
    private func sendTaskCompletionNotification(_ task: TaskModel) {
        guard let taskId = task.id else { return }
        
        // Получаем информацию о пользователе, выполнившем задачу
        let currentUserId = AppState.shared.user?.id ?? "Unknown user"
        
        db.collection("users").document(currentUserId).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            var userName = "Someone"
            if let userData = snapshot?.data(), let name = userData["name"] as? String {
                userName = name
            }
            
            // Отправка локального уведомления создателю задачи, если это текущий пользователь
            if task.createdBy == AppState.shared.user?.id {
                let title = "Task Completed"
                let body = "\(userName) completed the task: \(task.title)"
                let identifier = "task_completion_\(taskId)"
                
                NotificationManager.shared.scheduleLocalNotification(
                    title: title,
                    body: body,
                    date: Date(),
                    identifier: identifier,
                    userInfo: [
                        "type": "task",
                        "taskId": taskId,
                        "action": "completion"
                    ]
                ) { _ in }
            }
            
            // Отправка push-уведомления создателю задачи
            self.db.collection("users").document(task.createdBy).getDocument { creatorSnapshot, creatorError in
                guard let creatorData = creatorSnapshot?.data(),
                      let fcmToken = creatorData["fcmToken"] as? String else {
                    return
                }
                
                // Создаем данные для уведомления
                let message = [
                    "token": fcmToken,
                    "notification": [
                        "title": "Task Completed",
                        "body": "\(userName) completed the task: \(task.title)"
                    ],
                    "data": [
                        "taskId": task.id ?? "",
                        "type": "task_completion"
                    ],
                    "apns": [
                        "payload": [
                            "aps": [
                                "sound": "default"
                            ]
                        ]
                    ]
                ]
                
                // Вызов Cloud Function для отправки уведомления
                let functions = Functions.functions()
                functions.httpsCallable("sendTaskNotification").call(message) { result, error in
                    if let error = error {
                        print("Error sending completion notification: \(error)")
                    }
                }
            }
        }
    }

    // Update an existing task
    func updateTask(_ task: TaskModel, completion: @escaping (Bool) -> Void) {
        guard let id = task.id else {
            completion(false)
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Получаем оригинальную задачу для проверки изменений
        let originalTask = tasks.first(where: { $0.id == id })
        
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
                        
                        // Если задача была переназначена другому пользователю, отправить уведомление
                        if let originalTask = originalTask,
                           originalTask.assignedTo != updatedTask.assignedTo {
                            self.sendTaskAssignmentNotification(updatedTask)
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
                    userInfo: [
                        "type": "task",
                        "taskId": id,
                        "action": "reminder"
                    ]
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
        
        // Cancel assignment notification
        NotificationManager.shared.cancelNotification(withIdentifier: "task_assignment_\(taskId)")
        
        // Cancel completion notification
        NotificationManager.shared.cancelNotification(withIdentifier: "task_completion_\(taskId)")
    }
    
    // Helper method to format dates
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    // MARK: - Filtering and Sorting Methods
    
    // Получение задач, назначенных текущему пользователю
    func getMyTasks() -> [TaskModel] {
        guard let userId = AppState.shared.user?.id else { return [] }
        return tasks.filter { $0.assignedTo == userId }.sorted { $0.dueDate < $1.dueDate }
    }
    
    // Получение новых назначенных задач (за последние 24 часа)
    func getNewlyAssignedTasks() -> [TaskModel] {
        guard let userId = AppState.shared.user?.id else { return [] }
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        
        return tasks.filter {
            $0.assignedTo == userId &&
            $0.createdAt >= cutoffDate &&
            !$0.completed
        }
    }
    
    // Другие методы фильтрации и сортировки остаются без изменений...
}

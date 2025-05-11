import SwiftUI

struct TasksView: View {
    @StateObject private var taskService = TaskService.shared
    @State private var showAddTask = false
    @State private var searchText = ""
    @State private var filterMode: FilterMode = .all
    @State private var selectedCategory: TaskCategory? = nil
    @State private var selectedPriority: TaskPriority? = nil
    @State private var showingTaskDetail = false
    @State private var selectedTask: TaskModel? = nil
    @State private var newTaskIds = Set<String>() // Для отслеживания новых задач
    @State private var showMyTasksOnly = false
    
    enum FilterMode: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case overdue = "Overdue"
        case completed = "Completed"
        case dueSoon = "Due Soon"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $searchText, placeholder: "Search tasks")
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // My Tasks toggle
                HStack {
                    Toggle("My tasks only", isOn: $showMyTasksOnly)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    // Badge showing number of new tasks
                    HStack {
                        Text("New: ")
                            .font(.caption)
                        NotificationBadge(count: newTasksCount)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                // Filter categories
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(FilterMode.allCases, id: \.self) { mode in
                            FilterButton(
                                title: mode.rawValue,
                                isSelected: filterMode == mode,
                                action: {
                                    filterMode = mode
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                // Category & Priority filters
                HStack(spacing: 10) {
                    Menu {
                        Button("All Categories") {
                            selectedCategory = nil
                        }
                        
                        ForEach(TaskCategory.allCases) { category in
                            Button(category.rawValue) {
                                selectedCategory = category
                            }
                        }
                    } label: {
                        Label(
                            selectedCategory?.rawValue ?? "Category",
                            systemImage: selectedCategory?.iconName ?? "folder"
                        )
                        .foregroundColor(selectedCategory == nil ? .primary : .blue)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Menu {
                        Button("All Priorities") {
                            selectedPriority = nil
                        }
                        
                        ForEach(TaskPriority.allCases) { priority in
                            Button(priority.rawValue) {
                                selectedPriority = priority
                            }
                        }
                    } label: {
                        Label(
                            selectedPriority?.rawValue ?? "Priority",
                            systemImage: selectedPriority?.iconName ?? "flag"
                        )
                        .foregroundColor(selectedPriority == nil ? .primary : .blue)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                // Task list
                List {
                    ForEach(filteredTasks) { task in
                        // Используем модифицированный TaskRow с индикацией новых задач
                        TaskRowWithNotification(
                            task: task,
                            isNew: isNewTask(task),
                            toggleAction: {
                                TaskService.shared.toggleCompletion(task)
                            }
                        )
                        .onTapGesture {
                            selectedTask = task
                            showingTaskDetail = true
                            
                            // Убираем задачу из списка новых при просмотре
                            if let id = task.id, newTaskIds.contains(id) {
                                newTaskIds.remove(id)
                            }
                        }
                    }
                    
                    if filteredTasks.isEmpty {
                        Text("No tasks found")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showAddTask = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                loadTasks()
                setupNotificationObservers()
            }
            .onDisappear {
                removeNotificationObservers()
            }
            .sheet(isPresented: $showAddTask) {
                AddTaskView()
            }
            .sheet(isPresented: $showingTaskDetail) {
                if let task = selectedTask {
                    TaskDetailView(task: task)
                }
            }
        }
    }
    
    // Настройка наблюдателей за уведомлениями
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TaskNotificationReceived"),
            object: nil,
            queue: .main) { notification in
                if let taskId = notification.userInfo?["taskId"] as? String {
                    // Добавляем задачу в список новых
                    newTaskIds.insert(taskId)
                }
            }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TaskNotificationTapped"),
            object: nil,
            queue: .main) { notification in
                if let taskId = notification.userInfo?["taskId"] as? String {
                    // Находим и отображаем задачу
                    if let task = taskService.tasks.first(where: { $0.id == taskId }) {
                        selectedTask = task
                        showingTaskDetail = true
                        
                        // Убираем задачу из списка новых
                        newTaskIds.remove(taskId)
                    }
                }
            }
    }
    
    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    // Загрузка задач и инициализация списка новых
    private func loadTasks() {
        if let groupId = AppState.shared.user?.groupId {
            taskService.fetchTasks(for: groupId)
            
            // Добавляем все новые задачи в множество
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // Новые задачи - это задачи, созданные менее 24 часов назад
                let newlyCreatedTasks = taskService.getNewlyAssignedTasks()
                for task in newlyCreatedTasks {
                    if let id = task.id {
                        newTaskIds.insert(id)
                    }
                }
            }
        }
    }
    
    // Проверка, является ли задача новой
    private func isNewTask(_ task: TaskModel) -> Bool {
        if let id = task.id {
            return newTaskIds.contains(id)
        }
        return false
    }
    
    // Количество новых задач
    private var newTasksCount: Int {
        newTaskIds.count
    }
    
    // Filter tasks based on mode, category, priority, and search text
    private var filteredTasks: [TaskModel] {
        // Start with all tasks
        var tasks = taskService.tasks
        
        // Если включен фильтр "Только мои задачи"
        if showMyTasksOnly, let userId = AppState.shared.user?.id {
            tasks = tasks.filter { $0.assignedTo == userId }
        }
        
        // Apply filter mode
        switch filterMode {
        case .all:
            break // Keep all tasks
        case .pending:
            tasks = tasks.filter { !$0.completed }
        case .completed:
            tasks = tasks.filter { $0.completed }
        case .overdue:
            tasks = tasks.filter { !$0.completed && $0.dueDate < Date() }
        case .dueSoon:
            let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            tasks = tasks.filter { !$0.completed && $0.dueDate <= nextWeek && $0.dueDate >= Date() }
        }
        
        // Apply category filter
        if let category = selectedCategory {
            tasks = tasks.filter { $0.category == category }
        }
        
        // Apply priority filter
        if let priority = selectedPriority {
            tasks = tasks.filter { $0.priority == priority }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            tasks = tasks.filter {
                $0.title.lowercased().contains(searchText.lowercased()) ||
                $0.description.lowercased().contains(searchText.lowercased())
            }
        }
        
        // Sort by due date
        return tasks.sorted {
            if $0.completed == $1.completed {
                return $0.dueDate < $1.dueDate
            } else {
                return !$0.completed && $1.completed
            }
        }
    }
}

// Custom search bar component
struct SearchBar: View {
    @Binding var text: String
    var placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField(placeholder, text: $text)
                .foregroundColor(.primary)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

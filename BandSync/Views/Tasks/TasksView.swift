//
//  TasksView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

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
                        TaskRow(task: task)
                            .onTapGesture {
                                selectedTask = task
                                showingTaskDetail = true
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
                if let groupId = AppState.shared.user?.groupId {
                    taskService.fetchTasks(for: groupId)
                }
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
    
    // Filter tasks based on mode, category, priority, and search text
    private var filteredTasks: [TaskModel] {
        // Start with all tasks
        var tasks = taskService.tasks
        
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
    
    private func TaskRow(task: TaskModel) -> some View {
        HStack {
            Button(action: {
                TaskService.shared.toggleCompletion(task)
            }) {
                Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.completed ? .green : .gray)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                    .foregroundColor(task.completed ? .gray : .primary)
                    .strikethrough(task.completed)
                
                HStack {
                    // Due date
                    Text("Due: \(formattedDate(task.dueDate))")
                        .font(.caption)
                        .foregroundColor(isOverdue(task) ? .red : .gray)
                    
                    // Category
                    Label(task.category.rawValue, systemImage: task.category.iconName)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 5)
                }
            }
            
            Spacer()
            
            // Priority indicator
            Image(systemName: task.priority.iconName)
                .foregroundColor(Color(hex: task.priority.color))
                .font(.caption)
        }
        .swipeActions {
            Button(role: .destructive) {
                TaskService.shared.deleteTask(task)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    // Check if task is overdue
    private func isOverdue(_ task: TaskModel) -> Bool {
        return !task.completed && task.dueDate < Date()
    }
    
    // Format date
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
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

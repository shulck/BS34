//
//  NotificationBadge.swift
//  BandSyncApp
//
//  Created by Oleksandr Kuziakin on 11.05.2025.
//


import SwiftUI

struct NotificationBadge: View {
    let count: Int
    var color: Color = .red
    var size: CGFloat = 16
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
            
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: size * 0.7))
                    .foregroundColor(.white)
                    .fontWeight(.bold)
            }
        }
        .opacity(count > 0 ? 1 : 0)
    }
}

// Модифицированная версия для индикации новых задач
struct TaskNotificationIndicator: View {
    let task: TaskModel
    let isNew: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            if isNew {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
            
            // Индикатор приоритета
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: task.priority.color))
                .frame(width: isNew ? 24 : 30, height: 8)
        }
    }
}

// Модифицированный компонент для строки задачи с индикацией новых задач
struct TaskRowWithNotification: View {
    let task: TaskModel
    let isNew: Bool
    let toggleAction: () -> Void
    
    var body: some View {
        HStack {
            Button(action: toggleAction) {
                Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.completed ? .green : .gray)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(task.title)
                        .font(.headline)
                        .foregroundColor(task.completed ? .gray : .primary)
                        .strikethrough(task.completed)
                    
                    if isNew {
                        Text("New")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
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

// Расширение для обнаружения новых задач
extension TaskModel {
    var isNew: Bool {
        let timeInterval = Date().timeIntervalSince(createdAt)
        return timeInterval < 24 * 60 * 60 // 24 часа
    }
}
//
//  TaskNotificationSettingsView.swift
//  BandSyncApp
//
//  Created by Oleksandr Kuziakin on 11.05.2025.
//


import SwiftUI

struct TaskNotificationSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var userService = UserService.shared
    @State private var taskNotificationsEnabled: Bool = true
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Notifications")) {
                    Toggle("Receive notifications for assigned tasks", isOn: $taskNotificationsEnabled)
                        .onChange(of: taskNotificationsEnabled) { newValue in
                            updateSettings()
                        }
                        .disabled(isLoading)
                    
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    if let success = successMessage {
                        Text(success)
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    
                    Text("When enabled, you will receive notifications when tasks are assigned to you and for upcoming task deadlines.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Task Reminders")) {
                    Text("You will receive reminders for your tasks at these times:")
                        .font(.footnote)
                    
                    HStack {
                        Image(systemName: "bell")
                        Text("1 day before due date")
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        Image(systemName: "bell")
                        Text("On the due date")
                    }
                    .padding(.vertical, 4)
                    
                    Text("Task reminders help you stay on top of your responsibilities within the group.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Team Notifications")) {
                    Text("Your team members will be notified when you complete a task that was assigned to you.")
                        .font(.footnote)
                    
                    Text("This helps maintain transparency and lets everyone know when important tasks are completed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    sendTestNotification()
                }) {
                    HStack {
                        Image(systemName: "bell.badge")
                        Text("Send Test Notification")
                    }
                }
            }
            .navigationTitle("Task Notifications")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadSettings()
            }
        }
    }
    
    private func loadSettings() {
        if let enabled = userService.currentUser?.taskNotificationsEnabled {
            taskNotificationsEnabled = enabled
        }
    }
    
    private func updateSettings() {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        userService.updateTaskNotificationsSettings(enabled: taskNotificationsEnabled) { success in
            isLoading = false
            
            if success {
                successMessage = "Settings updated successfully"
            } else {
                errorMessage = "Failed to update settings"
                // Restore previous value
                if let enabled = userService.currentUser?.taskNotificationsEnabled {
                    taskNotificationsEnabled = enabled
                }
            }
        }
    }
    
    private func sendTestNotification() {
        let identifier = "test_task_notification_\(UUID().uuidString)"
        
        NotificationManager.shared.scheduleLocalNotification(
            title: "Test Task Notification",
            body: "This is a test notification for tasks. Your notification settings are working correctly!",
            date: Date().addingTimeInterval(5), // 5 seconds from now
            identifier: identifier,
            userInfo: ["type": "test_task"]
        ) { success in
            if success {
                successMessage = "Test notification sent. You should receive it shortly."
            } else {
                errorMessage = "Failed to send test notification"
            }
        }
    }
}
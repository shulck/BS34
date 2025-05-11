//
//  NotificationSettingsView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 02.04.2025.
//

import SwiftUI
import Foundation
import UserNotifications

struct NotificationSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var isLoading = false
    @State private var notificationsEnabled = false
    @State private var settings: NotificationManager.NotificationSettings
    @State private var showPermissionAlert = false
    @EnvironmentObject private var appState: AppState
    init() {
        // Initialize settings from the notification manager
        _settings = State(initialValue: NotificationManager.shared.getNotificationSettings())
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Enable notifications", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { newValue in
                            if newValue {
                                requestNotificationPermission()
                            }
                        }
                }
                
                if notificationsEnabled {
                    Section(header: Text("Notification Types")) {
                        Toggle("Events", isOn: $settings.eventNotificationsEnabled)
                        Toggle("Tasks", isOn: $settings.taskNotificationsEnabled)
                        Toggle("Messages", isOn: $settings.chatNotificationsEnabled)
                        Toggle("System", isOn: $settings.systemNotificationsEnabled)
                    }
                    
                    Section(header: Text("Event Reminders")) {
                        Text("Notifications will be sent:")
                        
                        Toggle("One day before event", isOn: Binding(
                            get: { settings.eventReminderIntervals.contains(24) },
                            set: { newValue in
                                if newValue {
                                    if !settings.eventReminderIntervals.contains(24) {
                                        settings.eventReminderIntervals.append(24)
                                    }
                                } else {
                                    settings.eventReminderIntervals.removeAll { $0 == 24 }
                                }
                            }
                        ))
                        
                        Toggle("Evening before (8:00 PM)", isOn: Binding(
                            get: { settings.eventReminderIntervals.contains(12) },
                            set: { newValue in
                                if newValue {
                                    if !settings.eventReminderIntervals.contains(12) {
                                        settings.eventReminderIntervals.append(12)
                                    }
                                } else {
                                    settings.eventReminderIntervals.removeAll { $0 == 12 }
                                }
                            }
                        ))
                        
                        Toggle("One hour before event", isOn: Binding(
                            get: { settings.eventReminderIntervals.contains(1) },
                            set: { newValue in
                                if newValue {
                                    if !settings.eventReminderIntervals.contains(1) {
                                        settings.eventReminderIntervals.append(1)
                                    }
                                } else {
                                    settings.eventReminderIntervals.removeAll { $0 == 1 }
                                }
                            }
                        ))
                        
                        // Additional notifications for personal events
                        Toggle("Additional notifications for personal events", isOn: $settings.personalEventExtraNotifications)
                            .padding(.top, 4)
                    }
                    
                    Section(header: Text("Task Reminders")) {
                        Text("Notifications will be sent:")
                        
                        Toggle("One day before deadline", isOn: Binding(
                            get: { settings.taskReminderIntervals.contains(24) },
                            set: { newValue in
                                if newValue {
                                    if !settings.taskReminderIntervals.contains(24) {
                                        settings.taskReminderIntervals.append(24)
                                    }
                                } else {
                                    settings.taskReminderIntervals.removeAll { $0 == 24 }
                                }
                            }
                        ))
                    }
                    
                    Section {
                        Button("Test Notifications") {
                            sendTestNotification()
                        }
                        Button("Log out")
                            {
                                appState.logout()
                        }
                            .foregroundStyle(.red)
                    
                    }
                   
                     
                }
            }
            .navigationTitle("Notifications")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSettings()
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                checkNotificationStatus()
            }
            .overlay(Group {
                if isLoading {
                    ProgressView()
                        .padding()
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(8)
                        .shadow(radius: 3)
                }
            })
            .alert(isPresented: $showPermissionAlert) {
                Alert(
                    title: Text("Permissions"),
                    message: Text("To receive notifications, permission must be granted in device settings."),
                    primaryButton: .default(Text("Settings"), action: {
                        openSettings()
                    }),
                    secondaryButton: .cancel(Text("Cancel"), action: {
                        notificationsEnabled = false
                    })
                )
            }
        }
    }
    
    // Check notification permission status
    private func checkNotificationStatus() {
        isLoading = true
        NotificationManager.shared.checkAuthorizationStatus { status in
            DispatchQueue.main.async {
                notificationsEnabled = status == .authorized
                isLoading = false
            }
        }
    }
    
    // Request notification permission
    private func requestNotificationPermission() {
        isLoading = true
        NotificationManager.shared.requestAuthorization { granted in
            DispatchQueue.main.async {
                notificationsEnabled = granted
                if !granted {
                    showPermissionAlert = true
                }
                isLoading = false
            }
        }
    }
    
    // Send a test notification
    private func sendTestNotification() {
        NotificationManager.shared.scheduleLocalNotification(
            title: "Test Notification",
            body: "This is a test notification to verify settings",
            date: Date().addingTimeInterval(5),
            identifier: "test_notification_\(UUID().uuidString)",
            userInfo: ["type": "test"]
        ) { success in
            if success {
                // Notification scheduled
            }
        }
    }
    
    // Open app settings
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    // Save settings
    private func saveSettings() {
        NotificationManager.shared.updateNotificationSettings(settings)
        dismiss()
    }
}

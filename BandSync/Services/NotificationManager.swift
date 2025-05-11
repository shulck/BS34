import Foundation
import UserNotifications
import FirebaseMessaging
import UIKit

final class NotificationManager {
    static let shared = NotificationManager()
    
    // Notification types
    enum NotificationType: String {
        case event = "event"
        case task = "task"
        case message = "message"
        case system = "system"
    }
    
    // Improved notification settings structure
    struct NotificationSettings: Codable {
        var eventNotificationsEnabled = true
        var taskNotificationsEnabled = true
        var chatNotificationsEnabled = true
        var systemNotificationsEnabled = true
        
        // Notification intervals for events (in hours)
        var eventReminderIntervals = [24, 1] // One day and one hour before
        
        // Additional intervals for events
        var eventReminderIntervalsExtended = [12] // Evening before
        
        // Notification intervals for tasks (in hours)
        var taskReminderIntervals = [24] // One day before
        
        // Additional settings
        var personalEventExtraNotifications = true
    }
    
    private var settings: NotificationSettings
    
    private init() {
        // Load settings or use default values
        if let savedSettings = UserDefaults.standard.data(forKey: "notificationSettings"),
           let decodedSettings = try? JSONDecoder().decode(NotificationSettings.self, from: savedSettings) {
            self.settings = decodedSettings
        } else {
            self.settings = NotificationSettings()
        }
    }
    // Cancel specific notification
    func cancelNotification(withIdentifier identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    // Improved event notification scheduling
    func scheduleEventNotification(event: Event) {
        guard settings.eventNotificationsEnabled else { return }
        
        // Check that event date is in the future
        guard event.date > Date() else { return }
        
        // Clear old notifications for this event
        if let eventId = event.id {
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: [
                    "event_day_before_\(eventId)",
                    "event_hour_before_\(eventId)",
                    "event_evening_before_\(eventId)"
                ]
            )
        }
        
        // Identifier for unique notification naming
        let notificationId = event.id ?? UUID().uuidString
        
        // Create basic information for notification
        let title = event.isPersonal ? "Personal event: \(event.title)" : event.title
        let userInfo: [String: Any] = [
            "type": NotificationType.event.rawValue,
            "eventId": event.id ?? "",
            "eventTitle": event.title,
            "eventDate": event.date.timeIntervalSince1970,
            "isPersonal": event.isPersonal
        ]
        
        // Add notification for one day before event
        if settings.eventReminderIntervals.contains(24) {
            if let notificationDate = Calendar.current.date(byAdding: .day, value: -1, to: event.date) {
                if notificationDate > Date() {
                    let body = "Tomorrow at \(formatTime(event.date)): \(event.title)"
                    let identifier = "event_day_before_\(notificationId)"
                    
                    scheduleLocalNotification(
                        title: "Event reminder",
                        body: body,
                        date: notificationDate,
                        identifier: identifier,
                        userInfo: userInfo
                    ) { _ in }
                }
            }
        }
        
        // Add notification for evening before (at 20:00)
        if settings.eventReminderIntervalsExtended.contains(12) {
            if let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: event.date) {
                var components = Calendar.current.dateComponents([.year, .month, .day], from: dayBefore)
                components.hour = 20
                components.minute = 0
                
                if let eveningNotificationDate = Calendar.current.date(from: components), eveningNotificationDate > Date() {
                    let tomorrow = Calendar.current.isDateInTomorrow(event.date) ? "Tomorrow" : formatDate(event.date)
                    let body = "\(tomorrow) at \(formatTime(event.date)): \(event.title)"
                    let identifier = "event_evening_before_\(notificationId)"
                    
                    scheduleLocalNotification(
                        title: "Event reminder",
                        body: body,
                        date: eveningNotificationDate,
                        identifier: identifier,
                        userInfo: userInfo
                    ) { _ in }
                }
            }
        }
        
        // Add notification for one hour before event
        if settings.eventReminderIntervals.contains(1) {
            if let notificationDate = Calendar.current.date(byAdding: .hour, value: -1, to: event.date) {
                if notificationDate > Date() {
                    let body = "Event in one hour: \(event.title)"
                    let identifier = "event_hour_before_\(notificationId)"
                    
                    scheduleLocalNotification(
                        title: "Upcoming event",
                        body: body,
                        date: notificationDate,
                        identifier: identifier,
                        userInfo: userInfo
                    ) { _ in }
                }
            }
        }
        
        // For personal events, add additional notification in the morning of the same day (at 8:00)
        if event.isPersonal && settings.personalEventExtraNotifications {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: event.date)
            components.hour = 8
            components.minute = 0
            
            if let morningNotificationDate = Calendar.current.date(from: components),
               morningNotificationDate > Date() && morningNotificationDate < event.date {
                let body = "Today at \(formatTime(event.date)): \(event.title)"
                let identifier = "event_morning_of_\(notificationId)"
                
                scheduleLocalNotification(
                    title: "Personal event today",
                    body: body,
                    date: morningNotificationDate,
                    identifier: identifier,
                    userInfo: userInfo
                ) { _ in }
            }
        }
    }
    
    // Existing methods (unchanged)
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { granted, error in
                if let error = error {
                    print("Error requesting notification permission: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                // Register for remote notifications
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                
                completion(granted)
            }
        )
    }
    
    func checkAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }
    
    func scheduleLocalNotification(
        title: String,
        body: String,
        date: Date,
        identifier: String,
        userInfo: [AnyHashable: Any] = [:],
        completion: @escaping (Bool) -> Void
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    // Helper functions for date formatting
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    // Other existing methods remain unchanged
    func getNotificationSettings() -> NotificationSettings {
        return settings
    }
    
    func updateNotificationSettings(_ newSettings: NotificationSettings) {
        settings = newSettings
        saveSettings()
    }
    
    private func saveSettings() {
        if let encodedData = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encodedData, forKey: "notificationSettings")
        }
    }
}

import Foundation

struct UserModel: Identifiable, Codable, Equatable {
    let id: String
    let email: String
    let name: String
    let phone: String
    let groupId: String?
    var role: UserRole
    var isOnline: Bool?
    var lastSeen: Date?
    var fcmToken: String? // Добавляем поле для хранения FCM токена
    var taskNotificationsEnabled: Bool = true // Добавляем настройку уведомлений о задачах

    enum UserRole: String, Codable, CaseIterable, Identifiable {
        case admin = "Admin"
        case manager = "Manager"
        case musician = "Musician"
        case member = "Member"
        
        var id: String { rawValue }
    }

    static func == (lhs: UserModel, rhs: UserModel) -> Bool {
        return lhs.id == rhs.id &&
               lhs.email == rhs.email &&
               lhs.name == rhs.name &&
               lhs.phone == rhs.phone &&
               lhs.groupId == rhs.groupId &&
               lhs.role == rhs.role &&
               lhs.isOnline == rhs.isOnline &&
               lhs.lastSeen == rhs.lastSeen
    }
}

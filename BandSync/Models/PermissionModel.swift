//
//  PermissionModel.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  PermissionModel.swift
//  BandSync
//
//  Created by Claude AI on 31.03.2025.
//

import Foundation
import FirebaseFirestore

struct PermissionModel: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var groupId: String
    var modules: [ModulePermission]
    var userPermissions: [UserPermission] = [] // Новое поле для персональных разрешений
    
    // Структура для хранения персональных разрешений
    struct UserPermission: Codable, Hashable {
        var userId: String
        var modules: [ModuleType]
    }
    
    struct ModulePermission: Codable, Hashable {
        var moduleId: ModuleType
        var roleAccess: [UserModel.UserRole]
        
        // Check if the role has access to the module
        func hasAccess(role: UserModel.UserRole) -> Bool {
            return roleAccess.contains(role)
        }
    }
}

// Application module types
enum ModuleType: String, Codable, CaseIterable, Identifiable {
    case calendar = "calendar"
    case setlists = "setlists"
    case finances = "finances"
    case merchandise = "merchandise"
    case tasks = "tasks"
    case chats = "chats"
    case contacts = "contacts"
    case admin = "admin"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .calendar: return "Calendar"
        case .setlists: return "Setlists"
        case .finances: return "Finances"
        case .merchandise: return "Merchandise"
        case .tasks: return "Tasks"
        case .chats: return "Chats"
        case .contacts: return "Contacts"
        case .admin: return "Admin Panel"
        }
    }
    
    var icon: String {
        switch self {
        case .calendar: return "calendar"
        case .setlists: return "music.note.list"
        case .finances: return "dollarsign.circle"
        case .merchandise: return "bag"
        case .tasks: return "checklist"
        case .chats: return "message"
        case .contacts: return "person.crop.circle"
        case .admin: return "person.3"
        }
    }
}

//
//  TaskModel.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseFirestore

struct TaskModel: Identifiable, Codable {
    @DocumentID var id: String?

    var title: String
    var description: String
    var assignedTo: String
    var dueDate: Date
    var completed: Bool
    var groupId: String
    
    // New fields
    var priority: TaskPriority
    var category: TaskCategory
    var attachments: [String]?
    var subtasks: [Subtask]?
    var reminders: [Date]?
    var createdBy: String
    var createdAt: Date
    var updatedAt: Date
    
    // Default initializer
    init(
        id: String? = nil,
        title: String,
        description: String,
        assignedTo: String,
        dueDate: Date,
        completed: Bool = false,
        groupId: String,
        priority: TaskPriority = .medium,
        category: TaskCategory = .other,
        attachments: [String]? = nil,
        subtasks: [Subtask]? = nil,
        reminders: [Date]? = nil,
        createdBy: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.assignedTo = assignedTo
        self.dueDate = dueDate
        self.completed = completed
        self.groupId = groupId
        self.priority = priority
        self.category = category
        self.attachments = attachments
        self.subtasks = subtasks
        self.reminders = reminders
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// Priority enum
enum TaskPriority: String, Codable, CaseIterable, Identifiable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .high: return "exclamationmark.3"
        case .medium: return "exclamationmark.2"
        case .low: return "exclamationmark"
        }
    }
    
    var color: String {
        switch self {
        case .high: return "FF3B30"    // Red
        case .medium: return "FF9500"  // Orange
        case .low: return "34C759"     // Green
        }
    }
}

// Category enum
enum TaskCategory: String, Codable, CaseIterable, Identifiable {
    case rehearsal = "Rehearsal"
    case concert = "Concert"
    case organization = "Organization"
    case equipment = "Equipment"
    case promotion = "Promotion"
    case recording = "Recording"
    case other = "Other"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .rehearsal: return "music.note.list"
        case .concert: return "music.mic"
        case .organization: return "calendar"
        case .equipment: return "guitars"
        case .promotion: return "megaphone"
        case .recording: return "waveform"
        case .other: return "ellipsis.circle"
        }
    }
}

// Subtask model
struct Subtask: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var title: String
    var completed: Bool
    
    static func == (lhs: Subtask, rhs: Subtask) -> Bool {
        return lhs.id == rhs.id &&
               lhs.title == rhs.title &&
               lhs.completed == rhs.completed
    }
}

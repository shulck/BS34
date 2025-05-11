import SwiftUI

// Extension for event type to add color coding
extension EventType {
    // Using colorHex instead of duplicate color property
    var color: String {
        return colorHex
    }
    
    // Get icon for event type
    var icon: String {
        switch self {
        case .concert: return "music.mic"
        case .festival: return "music.note.list"
        case .rehearsal: return "pianokeys"
        case .meeting: return "person.2"
        case .interview: return "quote.bubble"
        case .photoshoot: return "camera"
        case .personal: return "person.crop.circle"
        }
    }
    
    // Return Color object instead of String
    var uiColor: Color {
        Color(hex: colorHex)
    }
}

// Helper extension for Event with display-friendly getters
extension Event {
    var isUpcoming: Bool {
        return date > Date()
    }
    
    var isPast: Bool {
        return date < Date()
    }
    
    var isToday: Bool {
        return Calendar.current.isDateInToday(date)
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var typeColor: Color {
        return type.uiColor  // Fixed: using uiColor instead of color
    }
}

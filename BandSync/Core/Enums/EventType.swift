//
//  EventType.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation

enum EventType: String, Codable, CaseIterable {
    case concert = "Concert"
    case festival = "Festival"
    case rehearsal = "Rehearsal"
    case meeting = "Meeting"
    case interview = "Interview"
    case photoshoot = "Photoshoot"
    case personal = "Personal"
    
    // Color for event type
    var colorHex: String {
        switch self {
        case .concert: return "E63946"    // Red
        case .festival: return "FFB703"   // Orange
        case .rehearsal: return "2A9D8F"  // Turquoise
        case .meeting: return "457B9D"    // Blue
        case .interview: return "8338EC"  // Purple
        case .photoshoot: return "FF006E" // Pink
        case .personal: return "A8DADC"   // Light Blue
        }
    }
}

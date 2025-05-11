//
//  TimeFrame.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 10.05.2025.
//

import Foundation

enum TimeFrame: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case quarter = "Quarter"
    case year = "Year"
    case all = "All time"

    var id: String { self.rawValue }

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        case .all: return 3650 // ~10 years
        }
    }
    
    var description: String {
        switch self {
        case .week: return "Last 7 days"
        case .month: return "Last 30 days"
        case .quarter: return "Last 3 months"
        case .year: return "Last 12 months"
        case .all: return "All time"
        }
    }
}

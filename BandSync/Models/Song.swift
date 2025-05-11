//
//  Song.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseFirestore

struct Song: Identifiable, Codable, Equatable {
    var id = UUID().uuidString
    var title: String
    var durationMinutes: Int
    var durationSeconds: Int
    var bpm: Int
    var key: String?
    var startTime: Date?

    var totalSeconds: Int {
        return durationMinutes * 60 + durationSeconds
    }

    var formattedDuration: String {
        String(format: "%02d:%02d", durationMinutes, durationSeconds)
    }
    
    // Custom Codable implementation to ensure key is properly saved and retrieved
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case durationMinutes
        case durationSeconds
        case bpm
        case key
        case startTime
    }
    
    init(id: String = UUID().uuidString, title: String, durationMinutes: Int, durationSeconds: Int, bpm: Int, key: String? = nil, startTime: Date? = nil) {
        self.id = id
        self.title = title
        self.durationMinutes = durationMinutes
        self.durationSeconds = durationSeconds
        self.bpm = bpm
        self.key = key
        self.startTime = startTime
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        durationSeconds = try container.decode(Int.self, forKey: .durationSeconds)
        bpm = try container.decode(Int.self, forKey: .bpm)
        
        // Explicitly try to decode key, even if it's null
        key = try container.decodeIfPresent(String.self, forKey: .key)
        startTime = try container.decodeIfPresent(Date.self, forKey: .startTime)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(durationMinutes, forKey: .durationMinutes)
        try container.encode(durationSeconds, forKey: .durationSeconds)
        try container.encode(bpm, forKey: .bpm)
        
        // Make sure key is always included in JSON, even if nil
        try container.encodeIfPresent(key, forKey: .key)
        try container.encodeIfPresent(startTime, forKey: .startTime)
    }
}

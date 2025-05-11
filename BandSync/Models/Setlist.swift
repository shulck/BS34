//
//  Setlist.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseFirestore

struct Setlist: Identifiable, Codable, Hashable, Equatable {
    @DocumentID var id: String?

    var name: String
    var userId: String
    var groupId: String
    var isShared: Bool
    var songs: [Song]
    var concertDate: Date?

    var totalDuration: Int {
        songs.reduce(0) { $0 + $1.totalSeconds }
    }

    var formattedTotalDuration: String {
        let minutes = totalDuration / 60
        let seconds = totalDuration % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // Реализация Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Реализация Equatable
    static func == (lhs: Setlist, rhs: Setlist) -> Bool {
        lhs.id == rhs.id
    }
}




//
//  Message.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseFirestore

struct Message: Identifiable, Codable,Equatable {
    var id: String? = nil
    var chatId: String
    var senderId: String
    var text: String
    var timestamp: Date
    var replyTo: String?
    var seenBy: [String]
    var deliveredTo: [String]
    var isEdited: Bool
}

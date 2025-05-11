//
//  ChatType.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  Chat.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseFirestore

enum ChatType: String, Codable {
    case group
    case direct
}

struct Chat: Identifiable, Codable {
    var id: String?
    var name: String
    var type: ChatType
    var participants: [String: Bool]
    var lastMessage: String?
    var lastMessageTime: Date?
}

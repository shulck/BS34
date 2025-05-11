//
//  GroupChatModel.swift
//  BandSync
//
//  Created by Akash 's Mac M1 on 24/04/2025.
//

import Foundation
struct GroupChatModel: Codable,Hashable {
    let groupId: String
    let bandId: String
    let adminId: String
    let groupName: String
    let members: [String]
    let lastMessage: String
    let lastMessageSenderId: String
    let lastMessageTime: TimeInterval?
}

//
//  MerchSaleChannel.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  MerchSale.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseFirestore

enum MerchSaleChannel: String, Codable, CaseIterable, Identifiable {
    case concert = "Concert"
    case online = "Online"
    case store = "Store"
    case gift = "Gift"  // New channel for gifts
    case other = "Other"

    var id: String { rawValue }
}

struct MerchSale: Identifiable, Codable {
    @DocumentID var id: String?
    let itemId: String
    let size: String
    let quantity: Int
    let date: Date
    let channel: MerchSaleChannel
    let groupId: String

    enum CodingKeys: String, CodingKey {
        case id, itemId, size, quantity, date, channel, groupId
    }

    init(itemId: String, size: String, quantity: Int, date: Date = Date(), channel: MerchSaleChannel, groupId: String) {
        self.itemId = itemId
        self.size = size
        self.quantity = quantity
        self.date = date
        self.channel = channel
        self.groupId = groupId
    }
}

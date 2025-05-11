//
//  Contact.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  Contact.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseFirestore

struct Contact: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var email: String
    var phone: String
    var role: String  // "Musician", "Organizer", "Venue", etc.
    var groupId: String
    var eventTag: String?
    var eventType: String?
    
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case phone
        case role
        case groupId
        case eventTag
        case eventType
    }
}

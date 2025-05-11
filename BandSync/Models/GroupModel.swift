//
//  GroupModel.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  GroupModel.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseFirestore

struct GroupModel: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var name: String
    var code: String
    var members: [String]
    var pendingMembers: [String]
    
    // Implementation of Equatable for object comparison
    static func == (lhs: GroupModel, rhs: GroupModel) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.code == rhs.code &&
               lhs.members == rhs.members &&
               lhs.pendingMembers == rhs.pendingMembers
    }
}

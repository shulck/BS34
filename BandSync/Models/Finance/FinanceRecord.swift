// FinanceRecord.swift

import Foundation
import FirebaseFirestore
import SwiftUI

struct FinanceRecord: Identifiable, Codable, Equatable {
    var id: String
    var type: FinanceType
    var amount: Double
    var currency: String
    var category: String
    var details: String
    var date: Date
    var receiptUrl: String?
    var groupId: String

    init(id: String = UUID().uuidString,
         type: FinanceType,
         amount: Double,
         currency: String,
         category: String,
         details: String,
         date: Date,
         receiptUrl: String? = nil,
         groupId: String) {
        self.id = id
        self.type = type
        self.amount = amount
        self.currency = currency
        self.category = category
        self.details = details
        self.date = date
        self.receiptUrl = receiptUrl
        self.groupId = groupId
    }

    // Constructor to support FinanceCategory
    init(id: String = UUID().uuidString,
         type: FinanceType,
         amount: Double,
         currency: String,
         category: FinanceCategory,
         details: String,
         date: Date,
         receiptUrl: String? = nil,
         groupId: String) {
        self.id = id
        self.type = type
        self.amount = amount
        self.currency = currency
        self.category = category.rawValue
        self.details = details
        self.date = date
        self.receiptUrl = receiptUrl
        self.groupId = groupId
    }

    init?(from document: DocumentSnapshot) {
        guard let data = document.data(),
              let typeString = data["type"] as? String,
              let type = FinanceType(rawValue: typeString),
              let amount = data["amount"] as? Double,
              let currency = data["currency"] as? String,
              let category = data["category"] as? String,
              let details = data["details"] as? String,
              let timestamp = data["date"] as? Timestamp,
              let groupId = data["groupId"] as? String else {
            return nil
        }

        self.id = document.documentID
        self.type = type
        self.amount = amount
        self.currency = currency
        self.category = category
        self.details = details
        self.date = timestamp.dateValue()
        self.receiptUrl = data["receiptUrl"] as? String
        self.groupId = groupId
    }

    var asDict: [String: Any] {
        var dict: [String: Any] = [
            "type": type.rawValue,
            "amount": amount,
            "currency": currency,
            "category": category,
            "details": details,
            "date": Timestamp(date: date),
            "groupId": groupId
        ]

        if let receiptUrl = receiptUrl {
            dict["receiptUrl"] = receiptUrl
        }

        return dict
    }

    static func == (lhs: FinanceRecord, rhs: FinanceRecord) -> Bool {
        lhs.id == rhs.id
    }
    
    var isCached: Bool {
        // Check in OfflineFinanceManager if this record is currently cached
        return OfflineFinanceManager.shared.fetchCachedRecords().contains(where: { $0.id == self.id })
    }
}

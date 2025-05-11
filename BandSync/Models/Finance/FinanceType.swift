// FinanceType.swift

import Foundation

// MARK: - Operation type
enum FinanceType: String, Codable, CaseIterable, Identifiable {
    case income = "Income"
    case expense = "Expense"

    var id: String { rawValue }
}

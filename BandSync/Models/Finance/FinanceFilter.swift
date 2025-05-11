// FinanceFilter.swift

import Foundation

struct FinanceFilter {
    var startDate: Date?
    var endDate: Date?
    var minAmount: Double?
    var maxAmount: Double?
    var selectedTypes: [FinanceType] = []
    var selectedCategories: [FinanceCategory] = []

    enum SortOrder {
        case dateAscending
        case dateDescending
        case amountAscending
        case amountDescending
    }

    var sortOrder: SortOrder = .dateDescending

    var isActive: Bool {
        return startDate != nil || endDate != nil ||
               minAmount != nil || maxAmount != nil ||
               !selectedTypes.isEmpty || !selectedCategories.isEmpty
    }

    mutating func reset() {
        startDate = nil
        endDate = nil
        minAmount = nil
        maxAmount = nil
        selectedTypes = []
        selectedCategories = []
        sortOrder = .dateDescending
    }

    func apply(to records: [FinanceRecord]) -> [FinanceRecord] {
        let filtered = records.filter { record in
            guard selectedTypes.isEmpty || selectedTypes.contains(record.type) else { return false }
            guard selectedCategories.isEmpty || selectedCategories.contains(where: { $0.rawValue == record.category }) else { return false }
            if let start = startDate, record.date < start { return false }
            if let end = endDate, record.date > end { return false }
            if let min = minAmount, record.amount < min { return false }
            if let max = maxAmount, record.amount > max { return false }
            return true
        }

        switch sortOrder {
        case .dateAscending: return filtered.sorted { $0.date < $1.date }
        case .dateDescending: return filtered.sorted { $0.date > $1.date }
        case .amountAscending: return filtered.sorted { $0.amount < $1.amount }
        case .amountDescending: return filtered.sorted { $0.amount > $1.amount }
        }
    }
}

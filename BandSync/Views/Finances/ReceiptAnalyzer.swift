// ReceiptAnalyzer.swift

import Foundation
import NaturalLanguage
import Vision

class ReceiptAnalyzer {
    
    struct ReceiptData {
        var amount: Double?
        var date: Date?
        var merchantName: String?
        var category: String?
        var items: [String]
        
        init(amount: Double? = nil, date: Date? = nil, merchantName: String? = nil, category: String? = nil, items: [String] = []) {
            self.amount = amount
            self.date = date
            self.merchantName = merchantName
            self.category = category
            self.items = items
        }
    }
    
    static func analyze(text: String) -> ReceiptData {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let amount = extractAmount(from: lines)
        let date = extractDate(from: lines)
        let merchantName = extractMerchantName(from: lines)
        let items = extractItems(from: lines)
        let category = determineCategory(items: items, merchantName: merchantName)
        
        return ReceiptData(
            amount: amount,
            date: date,
            merchantName: merchantName,
            category: category,
            items: items
        )
    }
    
    private static func extractAmount(from lines: [String]) -> Double? {
        // Look for lines that may contain the total amount
        let possibleAmountLines = lines.filter { line in
            let lowercased = line.lowercased()
            return lowercased.contains("total") ||
                   lowercased.contains("amount") ||
                   lowercased.contains("sum") ||
                   lowercased.contains("due") ||
                   lowercased.contains("balance") ||
                   lowercased.contains("pay") ||
                   lowercased.contains("eur") ||
                   lowercased.contains("usd") ||
                   lowercased.contains("€") ||
                   lowercased.contains("$")
        }
        
        // Improved regex to extract amount values
        let amountRegex = try? NSRegularExpression(pattern: "\\d+[.,]\\d{2}|\\d+[.,]\\d{1}|\\d+", options: [])
        
        // Check potential amount lines first
        for line in possibleAmountLines {
            if let amount = extractAmountValue(from: line, using: amountRegex) {
                return amount
            }
        }
        
        // If not found in specific lines, check all lines from bottom
        for line in lines.reversed() {
            if let amount = extractAmountValue(from: line, using: amountRegex) {
                return amount
            }
        }
        
        return nil
    }
    
    private static func extractAmountValue(from line: String, using regex: NSRegularExpression?) -> Double? {
        guard let regex = regex else { return nil }
        
        let nsString = line as NSString
        let range = NSRange(location: 0, length: nsString.length)
        
        // Find all matches with regex
        let matches = regex.matches(in: line, options: [], range: range)
        
        // Try to prioritize amounts with currency symbols
        let eurMatches = matches.filter { match in
            let matchRange = NSRange(location: max(0, match.range.location - 1), length: min(nsString.length - match.range.location + 1, match.range.length + 1))
            let extendedString = nsString.substring(with: matchRange)
            return extendedString.contains("€") || extendedString.contains("EUR")
        }
        
        if let match = eurMatches.last {
            let matchedString = nsString.substring(with: match.range)
            let normalizedString = matchedString.replacingOccurrences(of: ",", with: ".")
            return Double(normalizedString)
        }
        
        // Look for values after "total" or "sum"
        let totalIndex = line.lowercased().range(of: "total")?.upperBound ?? line.lowercased().range(of: "sum")?.upperBound
        
        if let index = totalIndex, let match = matches.last,
           nsString.substring(with: match.range).contains(where: { $0.isNumber }) {
            let matchedString = nsString.substring(with: match.range)
            let normalizedString = matchedString.replacingOccurrences(of: ",", with: ".")
            return Double(normalizedString)
        }
        
        // Last resort: take the last number on the line (often the total)
        if let match = matches.last {
            let matchedString = nsString.substring(with: match.range)
            let normalizedString = matchedString.replacingOccurrences(of: ",", with: ".")
            return Double(normalizedString)
        }
        
        return nil
    }
    
    private static func extractDate(from lines: [String]) -> Date? {
        // Look for lines that may contain date
        let possibleDateLines = lines.filter { line in
            let lowercased = line.lowercased()
            return lowercased.contains("date") ||
                   lowercased.contains("time") ||
                   lowercased.contains("receipt") ||
                   lowercased.contains("transaction") ||
                   lowercased.contains("purchase")
        }
        
        // Date formats that might be in the receipt
        let dateFormatters: [DateFormatter] = [
            createDateFormatter(format: "MM/dd/yyyy"),
            createDateFormatter(format: "MM/dd/yy"),
            createDateFormatter(format: "dd/MM/yyyy"),
            createDateFormatter(format: "dd/MM/yy"),
            createDateFormatter(format: "yyyy-MM-dd"),
            createDateFormatter(format: "MM-dd-yyyy"),
            createDateFormatter(format: "dd-MM-yyyy"),
            createDateFormatter(format: "MM.dd.yyyy"),
            createDateFormatter(format: "dd.MM.yyyy"),
            createDateFormatter(format: "MMM dd, yyyy"),
            createDateFormatter(format: "MMMM dd, yyyy"),
            createDateFormatter(format: "MM/dd/yyyy HH:mm"),
            createDateFormatter(format: "MM/dd/yy HH:mm"),
            createDateFormatter(format: "dd.MM.yy")
        ]
        
        // Improved regex for dates
        let dateRegex = try? NSRegularExpression(pattern: "(\\d{1,2}[./-]\\d{1,2}[./-]\\d{2,4})|(\\d{4}[./-]\\d{1,2}[./-]\\d{1,2})", options: [])
        
        // First check specific lines
        for line in possibleDateLines {
            if let date = extractDateValue(from: line, using: dateRegex, formatters: dateFormatters) {
                return date
            }
        }
        
        // If not found, check all lines
        for line in lines {
            if let date = extractDateValue(from: line, using: dateRegex, formatters: dateFormatters) {
                return date
            }
        }
        
        // If all else fails, use today's date
        return Date()
    }
    
    private static func createDateFormatter(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }
    
    private static func extractDateValue(from line: String, using regex: NSRegularExpression?, formatters: [DateFormatter]) -> Date? {
        guard let regex = regex else { return nil }
        
        let nsString = line as NSString
        let range = NSRange(location: 0, length: nsString.length)
        
        // Find all matches with regex
        let matches = regex.matches(in: line, options: [], range: range)
        
        for match in matches {
            let matchedString = nsString.substring(with: match.range)
            
            // Try different formats
            for formatter in formatters {
                if let date = formatter.date(from: matchedString) {
                    return date
                }
            }
        }
        
        // Try to find today's or yesterday's date
        let today = Date()
        let calendar = Calendar.current
        
        // If receipt contains "today"
        if line.lowercased().contains("today") {
            return today
        }
        
        // If receipt contains "yesterday"
        if line.lowercased().contains("yesterday") {
            return calendar.date(byAdding: .day, value: -1, to: today)
        }
        
        return nil
    }
    
    private static func extractMerchantName(from lines: [String]) -> String? {
        // Usually merchant name is at the beginning of the receipt
        if !lines.isEmpty {
            // Take first few lines and look for the longest one
            let topLines = Array(lines.prefix(5))
            var merchantName: String?
            var maxLength = 0
            
            for line in topLines {
                // Ignore lines that look like date or address
                if line.contains("/") || line.contains("@") || line.contains("Tel:") ||
                   line.contains("Phone:") || line.contains("Address:") || line.contains("ID:") ||
                   line.lowercased().contains("receipt") ||
                   line.contains("www.") || line.contains("http") {
                    continue
                }
                
                if line.count > maxLength {
                    maxLength = line.count
                    merchantName = line
                }
            }
            
            return merchantName
        }
        
        return nil
    }
    
    private static func extractItems(from lines: [String]) -> [String] {
        var items: [String] = []
        var isItemSection = false
        
        // Markers for beginning and end of items section
        let startMarkers = ["item", "description", "product", "quantity", "qty", "price"]
        let endMarkers = ["total", "subtotal", "sub-total", "amount", "balance", "due", "sum", "tax", "vat"]
        
        for line in lines {
            let lowercasedLine = line.lowercased()
            
            // Check for start of items section
            if !isItemSection {
                let isStart = startMarkers.contains { lowercasedLine.contains($0) }
                if isStart {
                    isItemSection = true
                    continue
                }
            }
            
            // Check for end of items section
            if isItemSection {
                let isEnd = endMarkers.contains { lowercasedLine.contains($0) }
                if isEnd {
                    break
                }
                
                // Ignore lines with quantity, price etc.
                if lowercasedLine.contains("qty") || lowercasedLine.contains(" x ") ||
                   lowercasedLine.contains("$") || lowercasedLine.contains("€") ||
                   (lowercasedLine.contains("quantity") && lowercasedLine.contains("price")) {
                    continue
                }
                
                // Add line as item if it's not empty and long enough
                if !line.isEmpty && line.count > 3 {
                    items.append(line)
                }
            }
        }
        
        // If no items found through markers, try heuristic approach
        if items.isEmpty {
            // Look for lines that look like items (don't contain special words)
            let blockedWords = ["receipt", "store", "date", "time", "total", "amount",
                              "payment", "cashier", "thank", "you", "discount", "tax",
                              "id", "address", "number", "phone", "welcome", "order"]
            
            for line in lines {
                let lowercasedLine = line.lowercased()
                let containsBlockedWord = blockedWords.contains { lowercasedLine.contains($0) }
                
                if !containsBlockedWord && !line.isEmpty && line.count > 3 {
                    items.append(line)
                }
            }
        }
        
        return items
    }
    
    private static func determineCategory(items: [String], merchantName: String?) -> String? {
        // Map keywords to FinanceCategory values
        let categoryKeywords: [String: FinanceCategory] = [
            "restaurant": .food,
            "cafe": .food,
            "pizza": .food,
            "sushi": .food,
            "food": .food,
            "grocery": .food,
            "supermarket": .food,
            "bread": .food,
            "milk": .food,
            "coffee": .food,
            "burger": .food,
            
            "taxi": .logistics,
            "metro": .logistics,
            "bus": .logistics,
            "train": .logistics,
            "subway": .logistics,
            "ticket": .logistics,
            "transit": .logistics,
            "gas": .logistics,
            "fuel": .logistics,
            "parking": .logistics,
            "uber": .logistics,
            
            "hotel": .accommodation,
            "apartment": .accommodation,
            "room": .accommodation,
            "hostel": .accommodation,
            "lodging": .accommodation,
            "airbnb": .accommodation,
            
            "guitar": .gear,
            "equipment": .gear,
            "instrument": .gear,
            "mic": .gear,
            "microphone": .gear,
            "speaker": .gear,
            "amplifier": .gear,
            "cable": .gear,
            "strings": .gear,
            
            "ad": .promo,
            "promotion": .promo,
            "marketing": .promo,
            "flyer": .promo,
            "poster": .promo,
            "print": .promo,
            "design": .promo,
            "social": .promo
        ]
        
        // Count matches for each category
        var categoryMatches: [FinanceCategory: Int] = [:]
        
        // Check merchant name
        if let merchant = merchantName?.lowercased() {
            for (keyword, category) in categoryKeywords {
                if merchant.contains(keyword) {
                    categoryMatches[category, default: 0] += 3 // Merchant name has higher weight
                }
            }
        }
        
        // Check items
        for item in items {
            let lowercasedItem = item.lowercased()
            for (keyword, category) in categoryKeywords {
                if lowercasedItem.contains(keyword) {
                    categoryMatches[category, default: 0] += 1
                }
            }
        }
        
        // Find best matching category
        let sortedCategories = categoryMatches.sorted { $0.value > $1.value }
        return sortedCategories.first?.key.rawValue ?? "Other"
    }
}

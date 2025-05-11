//
//  ImportExportService.swift
//  BandSyncApp
//
//  Created by Oleksandr Kuziakin on 10.05.2025.
//


//
//  ImportExportService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 10.05.2025.
//

import Foundation
import UIKit

class ImportExportService {
    static let shared = ImportExportService()
    
    private init() {}
    
    // MARK: - Export functions
    
    func exportToCSV<T: Encodable>(items: [T], filename: String) -> Data? {
        var csvString = ""
        
        // Get property names (CSV headers)
        if let firstItem = items.first {
            let mirror = Mirror(reflecting: firstItem)
            let propertyNames = mirror.children.compactMap { $0.label }
            
            // Add headers
            csvString += propertyNames.joined(separator: ",") + "\n"
            
            // Add rows
            for item in items {
                let itemMirror = Mirror(reflecting: item)
                let rowValues = itemMirror.children.compactMap { child -> String? in
                    // Format values based on type
                    if let value = child.value as? String {
                        // Escape commas and quotes in strings
                        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
                    } else if let value = child.value as? Date {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                        return formatter.string(from: value)
                    } else {
                        return "\(child.value)"
                    }
                }
                
                csvString += rowValues.joined(separator: ",") + "\n"
            }
        }
        
        return csvString.data(using: .utf8)
    }
    
    func exportToPDF(content: String, title: String) -> Data {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            // Define drawing area
            let drawingRect = CGRect(x: 50, y: 50, width: pageWidth - 100, height: pageHeight - 100)
            
            // Title
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24)
            ]
            
            let titleSize = (title as NSString).size(withAttributes: titleAttributes)
            (title as NSString).draw(
                at: CGPoint(x: drawingRect.midX - titleSize.width / 2, y: drawingRect.minY),
                withAttributes: titleAttributes
            )
            
            // Content
            let contentAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12)
            ]
            
            (content as NSString).draw(
                in: CGRect(x: drawingRect.minX, y: drawingRect.minY + 50, width: drawingRect.width, height: drawingRect.height - 70),
                withAttributes: contentAttributes
            )
            
            // Footer
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.gray
            ]
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            
            let footer = "Generated on \(dateFormatter.string(from: Date()))"
            let footerSize = (footer as NSString).size(withAttributes: footerAttributes)
            
            (footer as NSString).draw(
                at: CGPoint(x: drawingRect.midX - footerSize.width / 2, y: drawingRect.maxY - 20),
                withAttributes: footerAttributes
            )
        }
        
        return data
    }
    
    func exportItemsToCSV(items: [MerchItem]) -> Data? {
        var csvString = "ID,Name,Description,Category,Subcategory,Price,Cost,S,M,L,XL,XXL,Total Stock,Low Stock Threshold,SKU\n"
        
        for item in items {
            let id = item.id ?? ""
            let name = escapeCsvValue(item.name)
            let description = escapeCsvValue(item.description)
            let category = item.category.rawValue
            let subcategory = item.subcategory?.rawValue ?? ""
            let price = String(format: "%.2f", item.price)
            let cost = item.cost != nil ? String(format: "%.2f", item.cost!) : ""
            let S = String(item.stock.S)
            let M = String(item.stock.M)
            let L = String(item.stock.L)
            let XL = String(item.stock.XL)
            let XXL = String(item.stock.XXL)
            let totalStock = String(item.totalStock)
            let threshold = String(item.lowStockThreshold)
            let sku = item.sku ?? ""
            
            let line = "\(id),\(name),\(description),\(category),\(subcategory),\(price),\(cost),\(S),\(M),\(L),\(XL),\(XXL),\(totalStock),\(threshold),\(sku)\n"
            csvString.append(line)
        }
        
        return csvString.data(using: .utf8)
    }
    
    func exportSalesToCSV(sales: [MerchSale], items: [MerchItem]) -> Data? {
        var csvString = "Date,Item ID,Item Name,Category,Size,Quantity,Price,Total,Channel\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for sale in sales {
            let itemName: String
            let category: String
            let price: String
            
            if let item = items.first(where: { $0.id == sale.itemId }) {
                itemName = escapeCsvValue(item.name)
                category = item.category.rawValue
                price = String(format: "%.2f", item.price)
            } else {
                itemName = "Unknown Item"
                category = "Unknown"
                price = "0.00"
            }
            
            let date = dateFormatter.string(from: sale.date)
            let total = sale.channel == .gift ? "Gift" : String(format: "%.2f", Double(sale.quantity) * Double(price)!)
            
            let line = "\(date),\(sale.itemId),\(itemName),\(category),\(sale.size),\(sale.quantity),\(price),\(total),\(sale.channel.rawValue)\n"
            csvString.append(line)
        }
        
        return csvString.data(using: .utf8)
    }
    
    private func escapeCsvValue(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
    
    // MARK: - Import functions
    
    func importItemsFromCSV(csv: String, groupId: String) -> [MerchItem]? {
        let lines = csv.components(separatedBy: .newlines)
        guard lines.count > 1 else { return nil }
        
        var headers: [String] = []
        var items: [MerchItem] = []
        
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty { continue }
            
            let values = parseCSVLine(trimmedLine)
            
            if index == 0 {
                // Header row
                headers = values
            } else {
                // Data row
                if let item = createItemFromCSV(values: values, headers: headers, groupId: groupId) {
                    items.append(item)
                }
            }
        }
        
        return items
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        var values: [String] = []
        var currentValue = ""
        var inQuotes = false
        
        for char in line {
            if char == "\"" {
                inQuotes = !inQuotes
            } else if char == "," && !inQuotes {
                values.append(currentValue)
                currentValue = ""
            } else {
                currentValue.append(char)
            }
        }
        
        values.append(currentValue)
        return values
    }
    
    private func createItemFromCSV(values: [String], headers: [String], groupId: String) -> MerchItem? {
        guard values.count >= 5 else { return nil }
        
        var data: [String: String] = [:]
        
        for (index, header) in headers.enumerated() {
            if index < values.count {
                data[header.lowercased()] = values[index]
            }
        }
        
        // Required fields
        guard let name = data["name"],
              let priceStr = data["price"],
              let price = Double(priceStr),
              let categoryStr = data["category"] else {
            return nil
        }
        
        // Parse category
        let category: MerchCategory
        if let parsedCategory = MerchCategory.allCases.first(where: { $0.rawValue.lowercased() == categoryStr.lowercased() }) {
            category = parsedCategory
        } else {
            category = .other
        }
        
        // Parse subcategory if available
        var subcategory: MerchSubcategory? = nil
        if let subcategoryStr = data["subcategory"] {
            subcategory = MerchSubcategory.allCases.first(where: { $0.rawValue.lowercased() == subcategoryStr.lowercased() })
        }
        
        // Stock
        var stock = MerchSizeStock()
        if let sStr = data["s"], let s = Int(sStr) { stock.S = s }
        if let mStr = data["m"], let m = Int(mStr) { stock.M = m }
        if let lStr = data["l"], let l = Int(lStr) { stock.L = l }
        if let xlStr = data["xl"], let xl = Int(xlStr) { stock.XL = xl }
        if let xxlStr = data["xxl"], let xxl = Int(xxlStr) { stock.XXL = xxl }
        
        // Optional fields
        let description = data["description"] ?? ""
        let sku = data["sku"] ?? ""
        let cost = data["cost"].flatMap { Double($0) }
        let threshold = data["threshold"].flatMap { Int($0) } ?? category.suggestedLowStockThreshold
        
        return MerchItem(
            name: name,
            description: description,
            price: price,
            category: category,
            subcategory: subcategory,
            stock: stock,
            groupId: groupId,
            lowStockThreshold: threshold,
            sku: sku.isEmpty ? nil : sku,
            cost: cost
        )
    }
}
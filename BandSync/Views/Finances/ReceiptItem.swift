//
//  ReceiptItem.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 02.04.2025.
//


import Foundation

/// Модель для представления элемента (товара/услуги) из чека
struct ReceiptItem: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var quantity: Double
    var price: Double
    var totalPrice: Double
    
    init(name: String, quantity: Double = 1.0, price: Double = 0.0, totalPrice: Double? = nil) {
        self.name = name
        self.quantity = quantity
        self.price = price
        self.totalPrice = totalPrice ?? (price * quantity)
    }
    
    static func == (lhs: ReceiptItem, rhs: ReceiptItem) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Расширение для анализа чеков
extension ReceiptAnalyzer {
    /// Преобразование строк товаров в структурированные объекты ReceiptItem
    static func extractReceiptItems(from lines: [String]) -> [ReceiptItem] {
        var receiptItems: [ReceiptItem] = []
        
        // Ищем строки, которые могут содержать товары с ценой
        let itemRegex = try? NSRegularExpression(pattern: "(.*?)\\s+([0-9]+[.,]?[0-9]*)\\s*[xX]?\\s*([0-9]+[.,]?[0-9]*)?\\s*([0-9]+[.,]?[0-9]*)", options: [])
        
        for line in lines {
            if let regex = itemRegex,
               let match = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.count)) {
                
                let nsLine = line as NSString
                
                // Название товара обычно находится в первой группе
                let nameRange = match.range(at: 1)
                let name = nameRange.location != NSNotFound ? nsLine.substring(with: nameRange).trimmingCharacters(in: .whitespacesAndNewlines) : ""
                
                // Остальные группы могут содержать количество, цену за единицу и общую сумму
                var quantity: Double = 1.0
                var price: Double = 0.0
                var totalPrice: Double = 0.0
                
                // Пытаемся выделить цифры из соответствующих групп
                if match.numberOfRanges > 2 {
                    let group2Range = match.range(at: 2)
                    if group2Range.location != NSNotFound {
                        let valueStr = nsLine.substring(with: group2Range).replacingOccurrences(of: ",", with: ".")
                        if let value = Double(valueStr) {
                            totalPrice = value  // По умолчанию предполагаем, что это общая сумма
                        }
                    }
                }
                
                if match.numberOfRanges > 3 {
                    let group3Range = match.range(at: 3)
                    if group3Range.location != NSNotFound {
                        let valueStr = nsLine.substring(with: group3Range).replacingOccurrences(of: ",", with: ".")
                        if let value = Double(valueStr) {
                            quantity = value
                        }
                    }
                }
                
                if match.numberOfRanges > 4 {
                    let group4Range = match.range(at: 4)
                    if group4Range.location != NSNotFound {
                        let valueStr = nsLine.substring(with: group4Range).replacingOccurrences(of: ",", with: ".")
                        if let value = Double(valueStr) {
                            price = totalPrice  // Предыдущее значение, вероятно, было ценой за единицу
                            totalPrice = value  // А это общая сумма
                        }
                    }
                }
                
                // Если есть хотя бы название товара, добавляем элемент
                if !name.isEmpty {
                    let item = ReceiptItem(name: name, quantity: quantity, price: price, totalPrice: totalPrice)
                    receiptItems.append(item)
                }
            } else {
                // Если регулярное выражение не сработало, но строка может содержать товар, добавляем ее как есть
                let words = line.components(separatedBy: " ")
                if words.count >= 1 && !line.contains("total") && !line.contains("subtotal") {
                    let item = ReceiptItem(name: line)
                    receiptItems.append(item)
                }
            }
        }
        
        return receiptItems
    }
}
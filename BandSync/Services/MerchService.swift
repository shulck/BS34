//
//  MerchService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseFirestore
import UIKit

final class MerchService: ObservableObject {
    static let shared = MerchService()

    @Published var items: [MerchItem] = []
    @Published var sales: [MerchSale] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var lowStockItems: [MerchItem] = []

    private let db = Firestore.firestore()
    private let cacheManager = CacheManager.shared
    private var merchItemsListener: ListenerRegistration?
    private var editingItemId: String?

    init() {
        // Получаем groupId из AppState
        if let groupId = AppState.shared.user?.groupId {
            fetchItems(for: groupId)
            fetchSales(for: groupId)
        }
        
        // Подписываемся на обновления товаров
        subscribeToMerchUpdates()
    }

    // MARK: - Data Loading

    func fetchItems(for groupId: String) {
        isLoading = true
        errorMessage = nil

        // Check cache first
        if let cachedItems = cacheManager.getCachedMerchItems(forGroupId: groupId) {
            DispatchQueue.main.async {
                self.items = cachedItems
                self.updateLowStockItems()
                
                // Still try to get fresh data from server
                self.fetchItemsFromServer(for: groupId)
            }
        } else {
            // If no cached data, fetch from server
            fetchItemsFromServer(for: groupId)
        }
    }
    
    private func fetchItemsFromServer(for groupId: String) {
        db.collection("merchandise")
            .whereField("groupId", isEqualTo: groupId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    if let error = error {
                        self.errorMessage = "Error fetching items: \(error.localizedDescription)"
                        self.isLoading = false
                        return
                    }

                    if let documents = snapshot?.documents {
                        do {
                            var newItems = try documents.compactMap { doc -> MerchItem? in
                                var item = try doc.data(as: MerchItem.self)
                                
                                // Force image reload by adding timestamp parameter to URLs
                                if var urls = item.imageUrls {
                                    urls = urls.map { url in
                                        if !url.contains("?") {
                                            return "\(url)?t=\(Int(Date().timeIntervalSince1970))"
                                        }
                                        return url
                                    }
                                    item.imageUrls = urls
                                }
                                
                                if let url = item.imageURL, !url.contains("?") {
                                    item.imageURL = "\(url)?t=\(Int(Date().timeIntervalSince1970))"
                                }
                                
                                return item
                            }
                            
                            // Sort by name for consistent order
                            newItems.sort { $0.name < $1.name }
                            
                            self.items = newItems
                            self.updateLowStockItems()
                            
                            // Cache the data
                            self.cacheManager.cacheMerchItems(newItems, forGroupId: groupId)
                        } catch {
                            self.errorMessage = "Error decoding items: \(error.localizedDescription)"
                        }
                    }
                    
                    self.isLoading = false
                }
            }
    }

    func fetchSales(for groupId: String) {
        // Try from cache first
        if let cachedSales = cacheManager.getCachedMerchSales(forGroupId: groupId) {
            DispatchQueue.main.async {
                self.sales = cachedSales
            }
        }
        
        // Then fetch from server
        db.collection("merch_sales")
            .whereField("groupId", isEqualTo: groupId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "Error loading sales: \(error.localizedDescription)"
                    }
                    return
                }

                if let docs = snapshot?.documents {
                    let result = docs.compactMap { try? $0.data(as: MerchSale.self) }
                    DispatchQueue.main.async {
                        self.sales = result
                        
                        // Cache sales data
                        self.cacheManager.cacheMerchSales(result, forGroupId: groupId)
                    }
                }
            }
    }

    // MARK: - CRUD Operations for Items

    func addItem(_ item: MerchItem, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil

        // Validate the item data
        guard validateItem(item) else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Invalid item data"
                completion(false)
            }
            return
        }

        do {
            _ = try db.collection("merchandise").addDocument(from: item) { [weak self] error in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error = error {
                        self.errorMessage = "Error adding product: \(error.localizedDescription)"
                        completion(false)
                    } else {
                        // Update local list
                        self.fetchItems(for: item.groupId)
                        completion(true)
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Serialization error: \(error.localizedDescription)"
                completion(false)
            }
        }
    }

    func updateItem(_ item: MerchItem, completion: @escaping (Bool) -> Void) {
        self.editingItemId = item.id
        
        // Проверяем размер документа перед сохранением
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(item) {
            // Если размер больше 800KB (с запасом от лимита Firestore в 1MB)
            if encoded.count > 800000 {
                print("Warning: Document size exceeds 800KB: \(encoded.count) bytes")
                // Уменьшаем количество изображений
                var reducedItem = item
                if var base64Images = reducedItem.imageBase64, base64Images.count > 2 {
                    reducedItem.imageBase64 = Array(base64Images.prefix(2))
                    if let urls = reducedItem.imageUrls, urls.count > 2 {
                        reducedItem.imageUrls = Array(urls.prefix(2))
                    }
                }
                saveItemToFirestore(reducedItem, completion: completion)
            } else {
                saveItemToFirestore(item, completion: completion)
            }
        } else {
            saveItemToFirestore(item, completion: completion)
        }
    }

    private func saveItemToFirestore(_ item: MerchItem, completion: @escaping (Bool) -> Void) {
        guard validateItem(item) else {
            completion(false)
            return
        }
        
        guard let id = item.id else {
            completion(false)
            return
        }

        isLoading = true
        errorMessage = nil

        // Update updatedAt field
        var updatedItem = item
        updatedItem.updatedAt = Date()

        do {
            try db.collection("merchandise").document(id).setData(from: updatedItem) { [weak self] error in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error = error {
                        self.errorMessage = "Error updating product: \(error.localizedDescription)"
                        completion(false)
                    } else {
                        // Update local list
                        if let index = self.items.firstIndex(where: { $0.id == id }) {
                            self.items[index] = updatedItem
                        }

                        // Update low stock items list
                        self.updateLowStockItems()
                        
                        // Update cache
                        self.cacheManager.cacheMerchItems(self.items, forGroupId: updatedItem.groupId)
                        self.cacheManager.cacheMerchSales(self.sales, forGroupId: item.groupId)

                        completion(true)
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Serialization error: \(error.localizedDescription)"
                completion(false)
            }
        }
    }

    func deleteItem(_ item: MerchItem, completion: @escaping (Bool) -> Void) {
        guard let id = item.id else {
            completion(false)
            return
        }

        isLoading = true
        errorMessage = nil

        // Start a batch to delete the item and its sales
        let batch = db.batch()
        
        // Delete the item
        let itemRef = db.collection("merchandise").document(id)
        batch.deleteDocument(itemRef)
        
        // Delete related sales in a separate query
        db.collection("merch_sales")
            .whereField("itemId", isEqualTo: id)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = "Error finding related sales: \(error.localizedDescription)"
                        completion(false)
                    }
                    return
                }
                
                // Add all sales to deletion batch
                if let documents = snapshot?.documents, !documents.isEmpty {
                    for doc in documents {
                        batch.deleteDocument(doc.reference)
                    }
                }
                
                // Commit the batch
                batch.commit { [weak self] error in
                    guard let self = self else { return }
                    
                    DispatchQueue.main.async {
                        self.isLoading = false
                        
                        if let error = error {
                            self.errorMessage = "Error deleting product: \(error.localizedDescription)"
                            completion(false)
                        } else {
                            // Remove from local list
                            self.items.removeAll { $0.id == id }
                            self.sales.removeAll { $0.itemId == id }
                            
                            // Update low stock items list
                            self.updateLowStockItems()
                            
                            // Update cache
                            self.cacheManager.cacheMerchItems(self.items, forGroupId: item.groupId)
                            self.cacheManager.cacheMerchSales(self.sales, forGroupId: item.groupId)
                            
                            completion(true)
                        }
                    }
                }
            }
    }

    // MARK: - Sales Operations

    func recordSale(item: MerchItem, size: String, quantity: Int, channel: MerchSaleChannel) {
        guard let itemId = item.id,
              let groupId = AppState.shared.user?.groupId else { return }

        let sale = MerchSale(
            itemId: itemId,
            size: size,
            quantity: quantity,
            channel: channel,
            groupId: groupId
        )

        // Start a batch transaction
        let batch = db.batch()
        
        // Add the sale record
        let saleRef = db.collection("merch_sales").document()
        do {
            try batch.setData(from: sale, forDocument: saleRef)
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Error creating sale record: \(error.localizedDescription)"
            }
            return
        }
        
        // Update the stock
        let itemRef = db.collection("merchandise").document(itemId)
        var updatedStock = item.stock
        
        switch size {
        case "S": updatedStock.S -= quantity
        case "M": updatedStock.M -= quantity
        case "L": updatedStock.L -= quantity
        case "XL": updatedStock.XL -= quantity
        case "XXL": updatedStock.XXL -= quantity
        case "one_size":
            if item.category != .clothing {
                updatedStock.S -= quantity // For non-clothing items we store quantity in S
            }
        default: break
        }
        
        // Ensure stock doesn't go below zero
        updatedStock.S = max(0, updatedStock.S)
        updatedStock.M = max(0, updatedStock.M)
        updatedStock.L = max(0, updatedStock.L)
        updatedStock.XL = max(0, updatedStock.XL)
        updatedStock.XXL = max(0, updatedStock.XXL)
        
        do {
            try batch.updateData([
                "stock": Firestore.Encoder().encode(updatedStock),
                "updatedAt": Timestamp(date: Date())
            ], forDocument: itemRef)
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Error updating stock: \(error.localizedDescription)"
            }
            return
        }
        
        // Add finance record if not a gift
        if channel != .gift {
            let recordId = UUID().uuidString
            let details = "Sale of \(item.name) (size: \(size), quantity: \(quantity))"
            let record = FinanceRecord(
                id: recordId,
                type: .income,
                amount: Double(quantity) * item.price,
                currency: "EUR",
                category: "Merchandise",
                details: details,
                date: Date(),
                receiptUrl: nil,
                groupId: groupId
            )
            
            // Create a dictionary with the data and add the additional merchSaleId field
            var recordDict = record.asDict
            recordDict["merchSaleId"] = saleRef.documentID
            
            let financeRef = db.collection("finances").document(recordId)
            batch.setData(recordDict, forDocument: financeRef)
        }
        
        // Commit the batch transaction
        batch.commit { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Error recording sale: \(error.localizedDescription)"
                }
                return
            }
            
            // Update local lists
            DispatchQueue.main.async {
                // Add sale to local list with the generated ID
                var newSale = sale
                newSale.id = saleRef.documentID
                self.sales.append(newSale)
                
                // Update item in local list
                if let index = self.items.firstIndex(where: { $0.id == itemId }) {
                    var updatedItem = self.items[index]
                    updatedItem.stock = updatedStock
                    updatedItem.updatedAt = Date()
                    self.items[index] = updatedItem
                }
                
                // Update low stock items
                self.updateLowStockItems()
                
                // Update cache
                self.cacheManager.cacheMerchItems(self.items, forGroupId: groupId)
                self.cacheManager.cacheMerchSales(self.sales, forGroupId: groupId)
            }
        }
    }

    func cancelSale(_ sale: MerchSale, item: MerchItem, completion: @escaping (Bool) -> Void) {
        guard let saleId = sale.id, let itemId = item.id else {
            completion(false)
            return
        }
        
        let groupId = item.groupId
        let batch = db.batch()

        // Delete sale record
        let saleRef = db.collection("merch_sales").document(saleId)
        batch.deleteDocument(saleRef)

        // Return item to stock
        let itemRef = db.collection("merchandise").document(itemId)
        
        // Create update to return items to stock
        var updatedStock = item.stock
        switch sale.size {
        case "S": updatedStock.S += sale.quantity
        case "M": updatedStock.M += sale.quantity
        case "L": updatedStock.L += sale.quantity
        case "XL": updatedStock.XL += sale.quantity
        case "XXL": updatedStock.XXL += sale.quantity
        case "one_size":
            if item.category != .clothing {
                updatedStock.S += sale.quantity // For non-clothing items we store quantity in S
            }
        default: break
        }

        // Update stock in the batch
        do {
            batch.updateData([
                "stock": try Firestore.Encoder().encode(updatedStock),
                "updatedAt": Timestamp(date: Date())
            ], forDocument: itemRef)
        } catch {
            DispatchQueue.main.async {
                completion(false)
            }
            return
        }

        // Find and handle finance record
        db.collection("finances")
            .whereField("merchSaleId", isEqualTo: saleId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { 
                    completion(false)
                    return 
                }
                
                // Process finance records if any
                if let docs = snapshot?.documents, !docs.isEmpty {
                    for doc in docs {
                        let financeRef = self.db.collection("finances").document(doc.documentID)
                        batch.deleteDocument(financeRef)
                    }
                }
                
                // If it wasn't a gift, create a refund record
                if sale.channel != .gift {
                    // Create a refund record
                    let recordId = UUID().uuidString
                    let details = "Refund for \(item.name) (size: \(sale.size), quantity: \(sale.quantity))"
                    let amount = Double(sale.quantity) * item.price
                    
                    let record = FinanceRecord(
                        id: recordId,
                        type: .expense,
                        amount: amount,
                        currency: "EUR",
                        category: "Merchandise Refund",
                        details: details,
                        date: Date(),
                        receiptUrl: nil,
                        groupId: groupId
                    )
                    
                    let financeRef = self.db.collection("finances").document(recordId)
                    do {
                        try batch.setData(from: record, forDocument: financeRef)
                    } catch {
                        DispatchQueue.main.async {
                            completion(false)
                        }
                        return
                    }
                }
                
                // Commit the batch
                batch.commit { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self.errorMessage = "Error cancelling sale: \(error.localizedDescription)"
                            completion(false)
                        } else {
                            // Update local data
                            if let index = self.sales.firstIndex(where: { $0.id == saleId }) {
                                self.sales.remove(at: index)
                            }
                            
                            // Update item stock in local list
                            if let index = self.items.firstIndex(where: { $0.id == itemId }) {
                                self.items[index].stock = updatedStock
                            }
                            
                            // Update low stock items
                            self.updateLowStockItems()
                            
                            // Update cache
                            self.cacheManager.cacheMerchItems(self.items, forGroupId: groupId)
                            self.cacheManager.cacheMerchSales(self.sales, forGroupId: groupId)
                            
                            completion(true)
                        }
                    }
                }
            }
    }

    // MARK: - Item Validation
    
    private func validateItem(_ item: MerchItem) -> Bool {
        // Basic validation
        guard !item.name.isEmpty else { return false }
        guard item.price > 0 else { return false }
        // Don't use if let here since groupId appears to be non-optional
        guard !item.groupId.isEmpty else { return false }
        
        // Validate stock
        if item.category == .clothing {
            guard item.stock.S >= 0 && item.stock.M >= 0 && item.stock.L >= 0 &&
                  item.stock.XL >= 0 && item.stock.XXL >= 0 else { return false }
        } else {
            guard item.stock.S >= 0 else { return false }
        }
        
        // Validate low stock threshold
        guard item.lowStockThreshold >= 0 else { return false }
        
        return true
    }

    // MARK: - Low Stock Management

    private func updateLowStockItems() {
        lowStockItems = items.filter { $0.isLowStock }

        // Send notification if there are low stock items
        if !lowStockItems.isEmpty {
            sendLowStockNotification()
        }
    }

    private func sendLowStockNotification() {
        // Send notification only once a day for each item
        let lastNotificationDate = UserDefaults.standard.object(forKey: "lastLowStockNotificationDate") as? Date ?? Date(timeIntervalSince1970: 0)
        let calendar = Calendar.current

        if !calendar.isDateInToday(lastNotificationDate) {
            // Format notification text
            let itemCount = lowStockItems.count
            let title = "Low stock items"
            let body = "You have \(itemCount) item\(itemCount == 1 ? "" : "s") with low stock."

            // Generate detailed list of low stock items
            var detailedBody = "Items with low stock:\n"
            for item in lowStockItems {
                if item.category == .clothing {
                    let lowSizes = item.sizesWithLowStock.joined(separator: ", ")
                    detailedBody += "• \(item.name) - Sizes: \(lowSizes)\n"
                } else {
                    detailedBody += "• \(item.name) - Quantity: \(item.totalStock)\n"
                }
            }

            // Send notification
            NotificationManager.shared.scheduleLocalNotification(
                title: title,
                body: body,
                date: Date(), // Используем текущую дату
                identifier: "low_stock_notification"
            ) { _ in }

            // Save last notification date
            UserDefaults.standard.set(Date(), forKey: "lastLowStockNotificationDate")
        }
    }

    // MARK: - Analytics methods

    func getSalesByPeriod(from startDate: Date, to endDate: Date) -> [MerchSale] {
        return sales.filter { $0.date >= startDate && $0.date <= endDate }
    }

    func getSalesByItem(itemId: String) -> [MerchSale] {
        return sales.filter { $0.itemId == itemId }
    }

    func getSalesByCategory(category: MerchCategory) -> [MerchSale] {
        let itemIds = items.filter { $0.category == category }.compactMap { $0.id }
        return sales.filter { sale in itemIds.contains(sale.itemId) }
    }

    func getSalesByMonth() -> [String: Int] {
        let calendar = Calendar.current
        var result: [String: Int] = [:]

        for sale in sales {
            let components = calendar.dateComponents([.year, .month], from: sale.date)
            if let year = components.year, let month = components.month {
                let key = "\(year)-\(String(format: "%02d", month))"
                result[key, default: 0] += sale.quantity
            }
        }

        return result
    }

    func getTopSellingItems(limit: Int = 5) -> [MerchItem] {
        var itemSalesCount: [String: Int] = [:]

        for sale in sales {
            itemSalesCount[sale.itemId, default: 0] += sale.quantity
        }

        let sortedItems = items.sorted { item1, item2 in
            let sales1 = itemSalesCount[item1.id ?? ""] ?? 0
            let sales2 = itemSalesCount[item2.id ?? ""] ?? 0
            return sales1 > sales2
        }

        return Array(sortedItems.prefix(limit))
    }

    func getLeastSellingItems(limit: Int = 5) -> [MerchItem] {
        var itemSalesCount: [String: Int] = [:]

        for sale in sales {
            itemSalesCount[sale.itemId, default: 0] += sale.quantity
        }

        // Add items with no sales
        for item in items {
            if let id = item.id, itemSalesCount[id] == nil {
                itemSalesCount[id] = 0
            }
        }

        let sortedItems = items.sorted { item1, item2 in
            let sales1 = itemSalesCount[item1.id ?? ""] ?? 0
            let sales2 = itemSalesCount[item2.id ?? ""] ?? 0
            return sales1 < sales2
        }

        return Array(sortedItems.prefix(limit))
    }

    func getTotalRevenue(period: TimeFrame = .all) -> Double {
        let cutoffDate = getCutoffDate(for: period)
        let filteredSales = sales.filter { $0.date >= cutoffDate && $0.channel != .gift }
        
        var revenue: Double = 0
        for sale in filteredSales {
            if let item = items.first(where: { $0.id == sale.itemId }) {
                revenue += item.price * Double(sale.quantity)
            }
        }

        return revenue
    }
    
    func getRevenueByMonth() -> [String: Double] {
        let calendar = Calendar.current
        var result: [String: Double] = [:]

        for sale in sales {
            if sale.channel == .gift { continue } // Skip gifts
            
            if let item = items.first(where: { $0.id == sale.itemId }) {
                let components = calendar.dateComponents([.year, .month], from: sale.date)
                if let year = components.year, let month = components.month {
                    let key = "\(year)-\(String(format: "%02d", month))"
                    result[key, default: 0] += Double(sale.quantity) * item.price
                }
            }
        }

        return result
    }
    
    func getSalesComparison(currentPeriod: TimeFrame, previousPeriod: TimeFrame) -> (current: Int, previous: Int, percentChange: Double) {
        let currentCutoff = getCutoffDate(for: currentPeriod)
        let previousCutoff = getCutoffDate(for: previousPeriod)
        
        let currentSalesCount = sales.filter { $0.date >= currentCutoff }.reduce(0) { $0 + $1.quantity }
        let previousSalesCount = sales.filter { $0.date >= previousCutoff && $0.date < currentCutoff }.reduce(0) { $0 + $1.quantity }
        
        let percentChange: Double
        if previousSalesCount == 0 {
            percentChange = currentSalesCount > 0 ? 100.0 : 0.0
        } else {
            percentChange = (Double(currentSalesCount - previousSalesCount) / Double(previousSalesCount)) * 100.0
        }
        
        return (currentSalesCount, previousSalesCount, percentChange)
    }
    
    func getRevenueComparison(currentPeriod: TimeFrame, previousPeriod: TimeFrame) -> (current: Double, previous: Double, percentChange: Double) {
        let currentCutoff = getCutoffDate(for: currentPeriod)
        let previousCutoff = getCutoffDate(for: previousPeriod)
        
        let currentRevenue = getRevenue(from: currentCutoff, to: Date())
        let previousRevenue = getRevenue(from: previousCutoff, to: currentCutoff)
        
        let percentChange: Double
        if previousRevenue == 0 {
            percentChange = currentRevenue > 0 ? 100.0 : 0.0
        } else {
            percentChange = ((currentRevenue - previousRevenue) / previousRevenue) * 100.0
        }
        
        return (currentRevenue, previousRevenue, percentChange)
    }
    
    private func getRevenue(from startDate: Date, to endDate: Date) -> Double {
        let filteredSales = sales.filter { $0.date >= startDate && $0.date <= endDate && $0.channel != .gift }
        var revenue: Double = 0
        
        for sale in filteredSales {
            if let item = items.first(where: { $0.id == sale.itemId }) {
                revenue += item.price * Double(sale.quantity)
            }
        }
        
        return revenue
    }
    
    private func getCutoffDate(for period: TimeFrame) -> Date {
        let calendar = Calendar.current
        let date = Date()
        
        switch period {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: date) ?? date
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: date) ?? date
        case .quarter:
            return calendar.date(byAdding: .month, value: -3, to: date) ?? date
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: date) ?? date
        case .all:
            return Date(timeIntervalSince1970: 0)
        }
    }

    // MARK: - Data export

    func exportSalesData() -> Data? {
        // Create CSV with sales data
        var csvString = "Date,Item,Category,Subcategory,Size,Quantity,Price,Amount,Channel\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        for sale in sales {
            guard let item = items.first(where: { $0.id == sale.itemId }) else {
                continue
            }

            let dateString = dateFormatter.string(from: sale.date)
            let amount = item.price * Double(sale.quantity)
            let subcategory = item.subcategory?.rawValue ?? ""

            let line = "\(dateString),\"\(item.name)\",\(item.category.rawValue),\(subcategory),\(sale.size),\(sale.quantity),\(item.price),\(amount),\(sale.channel.rawValue)\n"
            csvString.append(line)
        }

        return csvString.data(using: .utf8)
    }
    
    func exportInventoryData() -> Data? {
        // Create CSV with inventory data
        var csvString = "ID,Name,Category,Subcategory,Price,Total Stock,S,M,L,XL,XXL,Low Stock Threshold,Last Updated\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for item in items {
            let id = item.id ?? ""
            let subcategory = item.subcategory?.rawValue ?? ""
            let updatedAt = item.updatedAt != nil ? dateFormatter.string(from: item.updatedAt!) : "N/A"
            
            let line = "\(id),\"\(item.name)\",\(item.category.rawValue),\(subcategory),\(item.price),\(item.totalStock),\(item.stock.S),\(item.stock.M),\(item.stock.L),\(item.stock.XL),\(item.stock.XXL),\(item.lowStockThreshold),\(updatedAt)\n"
            csvString.append(line)
        }
        
        return csvString.data(using: .utf8)
    }
    
    // Generate a complete sales report for a given period
    func generateSalesReport(period: TimeFrame) -> Data? {
        let cutoffDate = getCutoffDate(for: period)
        let filteredSales = sales.filter { $0.date >= cutoffDate }
        
        var reportText = "# Merchandise Sales Report\n"
        reportText += "Period: \(formatTimeFrame(period))\n\n"
        
        // Summary
        let totalSales = filteredSales.reduce(0) { $0 + $1.quantity }
        let totalRevenue = filteredSales.reduce(0.0) { total, sale in
            if let item = items.first(where: { $0.id == sale.itemId }), sale.channel != .gift {
                return total + (Double(sale.quantity) * item.price)
            }
            return total
        }
        let giftCount = filteredSales.filter { $0.channel == .gift }.reduce(0) { $0 + $1.quantity }
        
        reportText += "## Summary\n"
        reportText += "- Total items sold: \(totalSales) pcs.\n"
        reportText += "- Total revenue: \(String(format: "%.2f", totalRevenue)) EUR\n"
        reportText += "- Items gifted: \(giftCount) pcs.\n\n"
        
        // Sales by category
        reportText += "## Sales by Category\n"
        var salesByCategory: [MerchCategory: Int] = [:]
        var revenueByCategory: [MerchCategory: Double] = [:]
        
        for sale in filteredSales {
            if let item = items.first(where: { $0.id == sale.itemId }) {
                salesByCategory[item.category, default: 0] += sale.quantity
                
                if sale.channel != .gift {
                    revenueByCategory[item.category, default: 0] += Double(sale.quantity) * item.price
                }
            }
        }
        
        for category in MerchCategory.allCases {
            let salesCount = salesByCategory[category] ?? 0
            let revenue = revenueByCategory[category] ?? 0
            
            reportText += "- \(category.rawValue): \(salesCount) pcs. (\(String(format: "%.2f", revenue)) EUR)\n"
        }
        reportText += "\n"
        
        // Top selling items
        reportText += "## Top Selling Items\n"
        var itemSalesCount: [String: Int] = [:]
        
        for sale in filteredSales {
            itemSalesCount[sale.itemId, default: 0] += sale.quantity
        }
        
        let topItems = items.filter { item in
            guard let id = item.id else { return false }
            return itemSalesCount[id] ?? 0 > 0
        }.sorted { item1, item2 in
            let sales1 = itemSalesCount[item1.id ?? ""] ?? 0
            let sales2 = itemSalesCount[item2.id ?? ""] ?? 0
            return sales1 > sales2
        }.prefix(10)
        
        for (index, item) in topItems.enumerated() {
            guard let id = item.id else { continue }
            let salesCount = itemSalesCount[id] ?? 0
            let revenue = Double(salesCount) * item.price
            
            reportText += "\(index + 1). \(item.name) - \(salesCount) pcs. (\(String(format: "%.2f", revenue)) EUR)\n"
        }
        reportText += "\n"
        
        // Sales by channel
        reportText += "## Sales by Channel\n"
        var salesByChannel: [MerchSaleChannel: Int] = [:]
        var revenueByChannel: [MerchSaleChannel: Double] = [:]
        
        for sale in filteredSales {
            salesByChannel[sale.channel, default: 0] += sale.quantity
            
            if sale.channel != .gift, let item = items.first(where: { $0.id == sale.itemId }) {
                revenueByChannel[sale.channel, default: 0] += Double(sale.quantity) * item.price
            }
        }
        
        for channel in MerchSaleChannel.allCases {
            let salesCount = salesByChannel[channel] ?? 0
            let revenue = revenueByChannel[channel] ?? 0
            
            reportText += "- \(channel.rawValue): \(salesCount) pcs."
            if channel != .gift {
                reportText += " (\(String(format: "%.2f", revenue)) EUR)"
            }
            reportText += "\n"
        }
        
        return reportText.data(using: .utf8)
    }
    
    private func formatTimeFrame(_ timeFrame: TimeFrame) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        
        let endDate = Date()
        let startDate = getCutoffDate(for: timeFrame)
        
        return "\(dateFormatter.string(from: startDate)) - \(dateFormatter.string(from: endDate))"
    }

    // MARK: - Helper Methods
    
    // Filter items by search text
    func filterItems(by searchText: String, category: MerchCategory? = nil) -> [MerchItem] {
        var filteredItems = items
        
        // Filter by category if specified
        if let category = category {
            filteredItems = filteredItems.filter { $0.category == category }
        }
        
        // If search text is empty, return category-filtered items
        if searchText.isEmpty {
            return filteredItems
        }
        
        // Special case for "low_stock_filter"
        if searchText == "low_stock_filter" {
            return lowStockItems
        }
        
        // Filter by search text
        return filteredItems.filter { item in
            let subcategoryText = item.subcategory?.rawValue ?? ""
            let skuText = item.sku ?? ""
            
            return item.name.lowercased().contains(searchText.lowercased()) ||
                   item.description.lowercased().contains(searchText.lowercased()) ||
                   item.category.rawValue.lowercased().contains(searchText.lowercased()) ||
                   subcategoryText.lowercased().contains(searchText.lowercased()) ||
                   skuText.lowercased().contains(searchText.lowercased())
        }
    }
    
    // Get all sales for a specific item
    func getSalesForItem(_ itemId: String) -> [MerchSale] {
        return sales.filter { $0.itemId == itemId }
    }

    // MARK: - Firestore Updates Subscription

    private func subscribeToMerchUpdates() {
        guard let groupId = AppState.shared.user?.groupId else { return }
        
        // Отписываемся от предыдущих слушателей, если есть
        merchItemsListener?.remove()
        
        // Создаем слушатель для коллекции товаров группы
        merchItemsListener = db.collection("merchItems")
            .whereField("groupId", isEqualTo: groupId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error listening for merch updates: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                // Обработка изменений документов
                var updatedItems: [MerchItem] = []
                
                for document in snapshot.documents {
                    do {
                        var item = try document.data(as: MerchItem.self)
                        
                        // Устанавливаем ID, если не задан
                        if item.id == nil {
                            item.id = document.documentID
                        }
                        
                        updatedItems.append(item)
                    } catch {
                        print("Error decoding merch item: \(error.localizedDescription)")
                    }
                }
                
                // Обновляем список товаров в сервисе
                DispatchQueue.main.async {
                    self.items = updatedItems
                    self.updateLowStockItems()
                }
            }
    }

    // MARK: - Current Item Management

    func getCurrentItem() -> MerchItem? {
        return items.first { $0.id == editingItemId }
    }
}

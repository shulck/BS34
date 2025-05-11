// FinanceService.swift

import Foundation
import FirebaseFirestore

final class FinanceService: ObservableObject {
    static let shared = FinanceService()

    @Published var records: [FinanceRecord] = []
    private let db = Firestore.firestore()
    
    // Ключ для кеширования транзакций
    private let offlineRecordsKey = "offlineFinanceRecords"

    func fetch(for groupId: String) {
        print("Fetching finances for group: \(groupId)")
        db.collection("finances")
            .whereField("groupId", isEqualTo: groupId)
            .order(by: "date", descending: true)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error loading finances: \(error.localizedDescription)")
                    return
                }
                
                guard let docs = snapshot?.documents else {
                    print("No documents found or error")
                    return
                }
                
                print("Found \(docs.count) finance documents")
                
                var loadedRecords: [FinanceRecord] = []
                
                for document in docs {
                    do {
                        // Получаем данные документа
                        let data = document.data()
                        print("Document data: \(data)")
                        
                        // Извлекаем необходимые поля вручную
                        let id = document.documentID
                        
                        guard let typeString = data["type"] as? String,
                              let type = FinanceType(rawValue: typeString),
                              let amount = data["amount"] as? Double,
                              let currency = data["currency"] as? String,
                              let category = data["category"] as? String,
                              let groupId = data["groupId"] as? String else {
                            print("Missing required fields in document: \(id)")
                            continue
                        }
                        
                        // Получаем дату
                        let date: Date
                        if let timestamp = data["date"] as? Timestamp {
                            date = timestamp.dateValue()
                        } else {
                            date = Date()
                            print("Warning: using current date for document \(id)")
                        }
                        
                        // Получаем опциональные поля
                        let details = data["details"] as? String ?? ""
                        let receiptUrl = data["receiptUrl"] as? String
                        
                        // Создаем запись финансов
                        let record = FinanceRecord(
                            id: id,
                            type: type,
                            amount: amount,
                            currency: currency,
                            category: category,
                            details: details,
                            date: date,
                            receiptUrl: receiptUrl,
                            groupId: groupId
                        )
                        
                        loadedRecords.append(record)
                    } catch {
                        print("Error manually parsing document: \(error)")
                    }
                }
                
                DispatchQueue.main.async {
                    print("Loaded \(loadedRecords.count) finance records manually")
                    self?.records = loadedRecords
                }
            }
    }

    func add(_ record: FinanceRecord, completion: @escaping (Bool) -> Void) {
        // Создаем копию записи с новым ID, если это новая запись
        var newRecord = record
        if newRecord.id.isEmpty {
            newRecord.id = UUID().uuidString
        }
        
        // Подготавливаем данные
        let recordData: [String: Any] = [
            "id": newRecord.id,
            "type": newRecord.type.rawValue,
            "amount": newRecord.amount,
            "currency": newRecord.currency,
            "category": newRecord.category,
            "details": newRecord.details,
            "date": Timestamp(date: newRecord.date),
            "groupId": newRecord.groupId
        ]
        
        // Добавляем URL чека, если он есть
        var finalData = recordData
        if let receiptUrl = newRecord.receiptUrl {
            finalData["receiptUrl"] = receiptUrl
        }
        
        print("Adding record with data: \(finalData)")
        
        // Добавляем документ с конкретным ID
        db.collection("finances").document(newRecord.id).setData(finalData) { [weak self] error in
            if let error = error {
                print("Error adding record: \(error.localizedDescription)")
                // Cache the record if adding failed
                self?.cacheRecord(newRecord)
                completion(false)
            } else {
                print("Record added successfully with ID: \(newRecord.id)")
                // Обновляем список записей
                self?.fetch(for: newRecord.groupId)
                completion(true)
            }
        }
    }
    
    func update(_ record: FinanceRecord, completion: @escaping (Bool) -> Void) {
        guard !record.id.isEmpty else {
            print("Cannot update record with empty ID")
            completion(false)
            return
        }
        
        // Подготавливаем данные
        let recordData: [String: Any] = [
            "id": record.id,
            "type": record.type.rawValue,
            "amount": record.amount,
            "currency": record.currency,
            "category": record.category,
            "details": record.details,
            "date": Timestamp(date: record.date),
            "groupId": record.groupId
        ]
        
        // Добавляем URL чека, если он есть
        var finalData = recordData
        if let receiptUrl = record.receiptUrl {
            finalData["receiptUrl"] = receiptUrl
        }
        
        print("Updating record with data: \(finalData)")
        
        db.collection("finances").document(record.id).setData(finalData) { [weak self] error in
            if let error = error {
                print("Error updating document: \(error.localizedDescription)")
                completion(false)
            } else {
                print("Document successfully updated: \(record.id)")
                self?.fetch(for: record.groupId)
                DispatchQueue.main.async {
                    completion(true)
                }
            }
        }
    }

    func delete(_ record: FinanceRecord, completion: @escaping (Bool) -> Void = { _ in }) {
        guard !record.id.isEmpty else {
            print("Cannot delete record with empty ID")
            completion(false)
            return
        }
        
        print("Deleting record with ID: \(record.id)")
        
        db.collection("finances").document(record.id).delete { [weak self] error in
            if let error = error {
                print("Error deleting document: \(error.localizedDescription)")
                completion(false)
            } else {
                print("Document successfully deleted: \(record.id)")
                
                // Удаляем запись из локального массива records
                DispatchQueue.main.async {
                    self?.records.removeAll { $0.id == record.id }
                    completion(true)
                }
            }
        }
    }
    
    // MARK: - Offline Management
    
    func cacheRecord(_ record: FinanceRecord) {
        var records = fetchCachedRecords()
        records.append(record)
        saveCachedRecords(records)
    }
    
    func fetchCachedRecords() -> [FinanceRecord] {
        let userDefaults = UserDefaults.standard
        guard let data = userDefaults.data(forKey: offlineRecordsKey),
              let records = try? JSONDecoder().decode([FinanceRecord].self, from: data) else {
            return []
        }
        return records
    }
    
    private func saveCachedRecords(_ records: [FinanceRecord]) {
        let userDefaults = UserDefaults.standard
        guard let data = try? JSONEncoder().encode(records) else { return }
        userDefaults.set(data, forKey: offlineRecordsKey)
    }
    
    func removeCachedRecord(_ record: FinanceRecord) {
        var records = fetchCachedRecords()
        records.removeAll { $0.id == record.id }
        saveCachedRecords(records)
    }
    
    func syncCachedRecords(completion: @escaping (Int) -> Void) {
        let records = fetchCachedRecords()
        let group = DispatchGroup()
        var synced = 0
        
        for record in records {
            group.enter()
            add(record) { success in
                if success {
                    self.removeCachedRecord(record)
                    synced += 1
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(synced)
        }
    }
    
    func isCached(_ record: FinanceRecord) -> Bool {
        return fetchCachedRecords().contains { $0.id == record.id }
    }

    var totalIncome: Double {
        records.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    var totalExpense: Double {
        records.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    var profit: Double {
        totalIncome - totalExpense
    }
}

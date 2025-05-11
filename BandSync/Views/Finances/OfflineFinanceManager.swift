//
//  OfflineFinanceManager.swift
//  BandSyncApp
//
//  Created by Oleksandr Kuziakin on 10.05.2025.
//


// OfflineFinanceManager.swift

import Foundation

class OfflineFinanceManager {
    static let shared = OfflineFinanceManager()
    
    private let userDefaults = UserDefaults.standard
    private let offlineRecordsKey = "offlineFinanceRecords"
    
    func cacheRecord(_ record: FinanceRecord) {
        var records = fetchCachedRecords()
        records.append(record)
        saveCachedRecords(records)
    }
    
    func fetchCachedRecords() -> [FinanceRecord] {
        guard let data = userDefaults.data(forKey: offlineRecordsKey),
              let records = try? JSONDecoder().decode([FinanceRecord].self, from: data) else {
            return []
        }
        return records
    }
    
    private func saveCachedRecords(_ records: [FinanceRecord]) {
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
            FinanceService.shared.add(record) { success in
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
}
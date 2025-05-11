//
//  CacheService.swift
//  BandSync
//
//  Created by Claude AI on 31.03.2025.
//

import Foundation
import FirebaseFirestore

final class CacheService {
    static let shared = CacheService()
    
    private let cacheDirectory: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    
    private init() {
        // Get cache directory
        cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("BandSyncCache")
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: cacheDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            } catch {
                print("Error creating cache directory: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Common caching methods
    
    // Save data to cache
    func cacheData<T: Encodable>(_ data: T, forKey key: String) {
        do {
            let data = try encoder.encode(data)
            try data.write(to: cacheDirectory.appendingPathComponent(key))
        } catch {
            print("Error saving data to cache for key \(key): \(error.localizedDescription)")
        }
    }
    
    // Get data from cache
    func loadData<T: Decodable>(forKey key: String, as type: T.Type) -> T? {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(type, from: data)
        } catch {
            print("Error loading data from cache for key \(key): \(error.localizedDescription)")
            return nil
        }
    }
    
    // Check if data exists in cache
    func hasCache(forKey key: String) -> Bool {
        return FileManager.default.fileExists(atPath: cacheDirectory.appendingPathComponent(key).path)
    }
    
    // Remove data from cache
    func removeCache(forKey key: String) {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                print("Error removing cache for key \(key): \(error.localizedDescription)")
            }
        }
    }
    
    // Clear all cache
    func clearAllCache() {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: nil
            )
            
            for url in contents {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            print("Error clearing cache: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Specific methods for different data types
    
    // Cache events
    func cacheEvents(_ events: [Event], forGroupId groupId: String) {
        cacheData(events, forKey: "events_\(groupId)")
    }
    
    // Get cached events
    func getCachedEvents(forGroupId groupId: String) -> [Event]? {
        return loadData(forKey: "events_\(groupId)", as: [Event].self)
    }
    
    // Cache setlists
    func cacheSetlists(_ setlists: [Setlist], forGroupId groupId: String) {
        cacheData(setlists, forKey: "setlists_\(groupId)")
    }
    
    // Get cached setlists
    func getCachedSetlists(forGroupId groupId: String) -> [Setlist]? {
        return loadData(forKey: "setlists_\(groupId)", as: [Setlist].self)
    }
    
    // Cache contacts
    func cacheContacts(_ contacts: [Contact], forGroupId groupId: String) {
        cacheData(contacts, forKey: "contacts_\(groupId)")
    }
    
    // Get cached contacts
    func getCachedContacts(forGroupId groupId: String) -> [Contact]? {
        return loadData(forKey: "contacts_\(groupId)", as: [Contact].self)
    }
    
    // Cache tasks
    func cacheTasks(_ tasks: [TaskModel], forGroupId groupId: String) {
        cacheData(tasks, forKey: "tasks_\(groupId)")
    }
    
    // Get cached tasks
    func getCachedTasks(forGroupId groupId: String) -> [TaskModel]? {
        return loadData(forKey: "tasks_\(groupId)", as: [TaskModel].self)
    }
    
    // Cache financial records
    func cacheFinances(_ records: [FinanceRecord], forGroupId groupId: String) {
        cacheData(records, forKey: "finances_\(groupId)")
    }
    
    // Get cached financial records
    func getCachedFinances(forGroupId groupId: String) -> [FinanceRecord]? {
        return loadData(forKey: "finances_\(groupId)", as: [FinanceRecord].self)
    }
    
    // Cache merchandise
    func cacheMerch(_ items: [MerchItem], forGroupId groupId: String) {
        cacheData(items, forKey: "merch_\(groupId)")
    }
    
    // Get cached merchandise
    func getCachedMerch(forGroupId groupId: String) -> [MerchItem]? {
        return loadData(forKey: "merch_\(groupId)", as: [MerchItem].self)
    }
    
    // Cache users
    func cacheUsers(_ users: [UserModel], forGroupId groupId: String) {
        cacheData(users, forKey: "users_\(groupId)")
    }
    
    // Get cached users
    func getCachedUsers(forGroupId groupId: String) -> [UserModel]? {
        return loadData(forKey: "users_\(groupId)", as: [UserModel].self)
    }
    
    // MARK: - Service methods
    
    // Get cache meta information
    func getCacheInfo() -> [String: Any] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]
            )
            
            var totalSize: UInt64 = 0
            var fileCount = 0
            var oldestDate: Date = Date()
            
            for url in contents {
                if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let size = attributes[.size] as? UInt64,
                   let creationDate = attributes[.creationDate] as? Date {
                    totalSize += size
                    fileCount += 1
                    
                    if creationDate < oldestDate {
                        oldestDate = creationDate
                    }
                }
            }
            
            return [
                "totalSize": totalSize,
                "fileCount": fileCount,
                "oldestCache": oldestDate
            ]
        } catch {
            print("Error getting cache information: \(error.localizedDescription)")
            return [
                "totalSize": 0,
                "fileCount": 0,
                "oldestCache": Date()
            ]
        }
    }
    
    // Clear old cache (older than 30 days)
    func clearOldCache() {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.creationDateKey]
            )
            
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            
            for url in contents {
                if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let creationDate = attributes[.creationDate] as? Date,
                   creationDate < cutoffDate {
                    try FileManager.default.removeItem(at: url)
                }
            }
        } catch {
            print("Error clearing old cache: \(error.localizedDescription)")
        }
    }
}

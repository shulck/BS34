//
//  SetlistService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 31.03.2025.
//

import Foundation
import FirebaseFirestore
import Network

final class SetlistService: ObservableObject {
    static let shared = SetlistService()
    
    @Published var setlists: [Setlist] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isOfflineMode: Bool = false

    private let db = Firestore.firestore()
    private var networkMonitor = NWPathMonitor()
    private var hasLoadedFromCache = false
    
    init() {
        // Initialize network monitoring
        setupNetworkMonitoring()
    }
    
    // Set up network monitoring
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let isConnected = path.status == .satisfied
                self?.isOfflineMode = !isConnected
                
                // When connection is restored, update data
                if isConnected && self?.hasLoadedFromCache == true {
                    if let groupId = AppState.shared.user?.groupId {
                        self?.fetchSetlists(for: groupId)
                    }
                }
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor.Setlist")
        networkMonitor.start(queue: queue)
    }

    func fetchSetlists(for groupId: String) {
        isLoading = true
        errorMessage = nil
        
        // Check network connection
        if isOfflineMode {
            loadFromCache(groupId: groupId)
            return
        }
        
        db.collection("setlists")
            .whereField("groupId", isEqualTo: groupId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        self.errorMessage = "Error loading setlists: \(error.localizedDescription)"
                        self.loadFromCache(groupId: groupId)
                        return
                    }
                    
                    if let docs = snapshot?.documents {
                        let items = docs.compactMap { try? $0.data(as: Setlist.self) }
                        self.setlists = items
                        
                        // Save to cache
                        CacheService.shared.cacheSetlists(items, forGroupId: groupId)
                    }
                }
            }
    }
    
    // Load from cache
    private func loadFromCache(groupId: String) {
        if let cachedSetlists = CacheService.shared.getCachedSetlists(forGroupId: groupId) {
            self.setlists = cachedSetlists
            self.hasLoadedFromCache = true
            self.isLoading = false
            
            if isOfflineMode {
                self.errorMessage = "Loaded from cache (offline mode)"
            }
        } else {
            self.errorMessage = "No data available in offline mode"
            self.isLoading = false
        }
    }

    func addSetlist(_ setlist: Setlist, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        
        // Check network connection
        if isOfflineMode {
            errorMessage = "Cannot add setlists in offline mode"
            isLoading = false
            completion(false)
            return
        }
        
        do {
            _ = try db.collection("setlists").addDocument(from: setlist) { [weak self] error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        self.errorMessage = "Error adding setlist: \(error.localizedDescription)"
                        completion(false)
                    } else {
                        self.fetchSetlists(for: setlist.groupId)
                        completion(true)
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Serialization error: \(error)"
                completion(false)
            }
        }
    }

    func updateSetlist(_ setlist: Setlist, completion: @escaping (Bool) -> Void) {
        guard let id = setlist.id else {
            completion(false)
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Check network connection
        if isOfflineMode {
            errorMessage = "Cannot update setlists in offline mode"
            isLoading = false
            completion(false)
            return
        }
        
        do {
            try db.collection("setlists").document(id).setData(from: setlist) { [weak self] error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        self.errorMessage = "Error updating setlist: \(error.localizedDescription)"
                        completion(false)
                    } else {
                        self.fetchSetlists(for: setlist.groupId)
                        completion(true)
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Serialization error: \(error)"
                completion(false)
            }
        }
    }

    func deleteSetlist(_ setlist: Setlist) {
        guard let id = setlist.id else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Check network connection
        if isOfflineMode {
            errorMessage = "Cannot delete setlists in offline mode"
            isLoading = false
            return
        }
        
        db.collection("setlists").document(id).delete { [weak self] error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error deleting setlist: \(error.localizedDescription)"
                } else if let groupId = AppState.shared.user?.groupId {
                    self.fetchSetlists(for: groupId)
                }
            }
        }
    }
    
    // Get setlist by ID
    func getSetlist(by id: String) -> Setlist? {
        return setlists.first { $0.id == id }
    }
    
    deinit {
        networkMonitor.cancel()
    }
}


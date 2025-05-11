//
//  FirebaseManager.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseCore

class FirebaseManager {
    static let shared = FirebaseManager()
    
    private(set) var isInitialized = false
    private let initializationLock = NSLock()
    
    private init() {
        print("FirebaseManager: instance created")
    }
    
    func initialize() {
        print("FirebaseManager: attempting to initialize Firebase")
        // Using lock for thread safety
        initializationLock.lock()
        print("FirebaseManager: lock acquired")
        defer {
            initializationLock.unlock()
            print("FirebaseManager: lock released")
        }
        
        if (!isInitialized) {
            print("FirebaseManager: Firebase was not initialized, initializing")
            do {
                FirebaseApp.configure()
                print("FirebaseManager: Firebase successfully initialized")
                isInitialized = true
            } catch let error {
                print("FirebaseManager: ERROR initializing Firebase: \(error)")
            }
        } else {
            print("FirebaseManager: Firebase was already initialized")
        }
    }
    
    func ensureInitialized() {
        print("FirebaseManager: checking initialization")
        if (!isInitialized) {
            print("FirebaseManager: initialization required")
            initialize()
        } else {
            print("FirebaseManager: already initialized")
        }
    }
}

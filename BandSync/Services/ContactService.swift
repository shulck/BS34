//
//  ContactService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  ContactService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseFirestore


final class ContactService: ObservableObject {
    static let shared = ContactService()

    @Published var contacts: [Contact] = []

    private let db = Firestore.firestore()

    func fetchContacts(for groupId: String) {
        db.collection("contacts")
            .whereField("groupId", isEqualTo: groupId)
            .getDocuments { [weak self] snapshot, error in
                if let docs = snapshot?.documents {
                    let items = docs.compactMap { try? $0.data(as: Contact.self) }
                    DispatchQueue.main.async {
                        self?.contacts = items
                    }
                } else {
                    print("Error loading contacts: \(error?.localizedDescription ?? "unknown")")
                }
            }
    }

    func addContact(_ contact: Contact, completion: @escaping (Bool) -> Void) {
        do {
            _ = try db.collection("contacts").addDocument(from: contact) { error in
                if let error = error {
                    print("Error adding contact: \(error.localizedDescription)")
                    completion(false)
                } else {
                    self.fetchContacts(for: contact.groupId)
                    completion(true)
                }
            }
        } catch {
            print("Error serializing contact: \(error)")
            completion(false)
        }
    }

    func updateContact(_ contact: Contact, completion: @escaping (Bool) -> Void) {
        guard let id = contact.id else { return }
        do {
            try db.collection("contacts").document(id).setData(from: contact) { error in
                if let error = error {
                    print("Error updating contact: \(error.localizedDescription)")
                    completion(false)
                } else {
                    self.fetchContacts(for: contact.groupId)
                    completion(true)
                }
            }
        } catch {
            print("Serialization error: \(error)")
            completion(false)
        }
    }

    func deleteContact(_ contact: Contact) {
        guard let id = contact.id else { return }
        db.collection("contacts").document(id).delete { error in
            if let error = error {
                print("Error deleting: \(error.localizedDescription)")
            } else if let groupId = AppState.shared.user?.groupId {
                self.fetchContacts(for: groupId)
            }
        }
    }
}

//
//  ContactPickerView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


import SwiftUI
import Contacts
import ContactsUI

public struct ContactPickerView: UIViewControllerRepresentable {
    private var onContactPicked: (CNContact?) -> Void
    
    public init(onContactPicked: @escaping (CNContact?) -> Void) {
        self.onContactPicked = onContactPicked
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }
    
    public func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    
    public class Coordinator: NSObject, CNContactPickerDelegate {
        private var parent: ContactPickerView
        
        init(_ parent: ContactPickerView) {
            self.parent = parent
        }
        
        public func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.onContactPicked(nil)
        }
        
        public func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.onContactPicked(contact)
        }
        
        public func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            parent.onContactPicked(contacts.first)
        }
    }
}
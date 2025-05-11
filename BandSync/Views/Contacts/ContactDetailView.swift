//
//  ContactDetailView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 31.03.2025.
//

import SwiftUI

struct ContactDetailView: View {
    @StateObject private var contactService = ContactService.shared
    @State private var contact: Contact
    @State private var isEditing = false
    @State private var showingDeleteConfirmation = false
    @Environment(\.dismiss) var dismiss
    
    init(contact: Contact) {
        _contact = State(initialValue: contact)
    }
    
    var body: some View {
        Form {
            // Main information
            Section(header: Text("Information")) {
                if isEditing {
                    TextField("Name", text: $contact.name)
                    TextField("Role", text: $contact.role)
                  
                } else {
                    LabeledContent("Name", value: contact.name)
                    LabeledContent("Role", value: contact.role)
                    if contact.eventTag != nil{
                        LabeledContent("Event", value: contact.eventTag ?? "No Event")
                    }
                }
            }
            
            // Contact details
            Section(header: Text("Contact details")) {
                if isEditing {
                    TextField("Phone", text: $contact.phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $contact.email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                } else {
                    // Phone with call option
                    Button {
                        call(phone: contact.phone)
                    } label: {
                        HStack {
                            Text("Phone")
                            Spacer()
                            Text(contact.phone)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Email with send option
                    Button {
                        sendEmail(to: contact.email)
                    } label: {
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(contact.email)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            // Action buttons (only in view mode)
            if !isEditing {
                Section {
                    Button {
                        call(phone: contact.phone)
                    } label: {
                        Label("Call", systemImage: "phone")
                    }
                    
                    Button {
                        sendEmail(to: contact.email)
                    } label: {
                        Label("Email", systemImage: "envelope")
                    }
                    
                    Button {
                        sendSMS(to: contact.phone)
                    } label: {
                        Label("Send SMS", systemImage: "message")
                    }
                }
                
                // Delete button
                if AppState.shared.hasEditPermission(for: .contacts) {
                    Section {
                        Button("Delete contact", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "Editing" : contact.name)
        .toolbar {
            // Edit/Save button
            if AppState.shared.hasEditPermission(for: .contacts) {
                ToolbarItem(placement: .primaryAction) {
                    if isEditing {
                        Button("Save") {
                            saveChanges()
                        }
                    } else {
                        Button("Edit") {
                            isEditing = true
                        }
                    }
                }
            }
            
            // Cancel button (only in edit mode)
            if isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Restore original data
                        if let original = contactService.contacts.first(where: { $0.id == contact.id }) {
                            contact = original
                        }
                        isEditing = false
                    }
                }
            }
        }
        .alert("Delete contact?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteContact()
            }
        } message: {
            Text("Are you sure you want to delete this contact? This action cannot be undone.")
        }
    }
    
    // Function to save changes
    private func saveChanges() {
        contactService.updateContact(contact) { success in
            if success {
                isEditing = false
            }
        }
    }
    
    // Function to delete contact
    private func deleteContact() {
        contactService.deleteContact(contact)
        dismiss()
    }
    
    // Function to call
    private func call(phone: String) {
        let cleaned = phone.replacingOccurrences(of: " ", with: "")
        if let url = URL(string: "tel://\(cleaned)") {
            print("Attempting to call: \(url.absoluteString)")
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                print("Cannot open call URL")
            }
        }
    }


    
    // Function to send email
    private func sendEmail(to: String) {
        if let url = URL(string: "mailto:\(to)"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    
    // Function to send SMS
    private func sendSMS(to: String) {
        if let url = URL(string: "sms:\(to.replacingOccurrences(of: " ", with: ""))"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}

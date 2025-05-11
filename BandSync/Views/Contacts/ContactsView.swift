import SwiftUI
import Contacts
import ContactsUI

struct ContactsView: View {
    @StateObject private var contactService = ContactService.shared
    @State private var searchText = ""
    @State private var showAddContact = false
    @State private var showImportContacts = false
    @State private var selectedCategory: String? = nil
    @State private var isLoading = false
    
    // Contact categories
    // Contact categories
    private let categories = ["All", "Musicians", "Organizers", "Coordinators", "Venues",  "Concerts", "Festivals","Others"]

    
    // Filtered contacts
    // Filtered contacts
    private var filteredContacts: [Contact] {
        var result = contactService.contacts
        
        // Filter by search
        if !searchText.isEmpty {
            result = result.filter { contact in
                contact.name.lowercased().contains(searchText.lowercased()) ||
                contact.email.lowercased().contains(searchText.lowercased()) ||
                contact.phone.contains(searchText)
            }
        }
        
        // Filter by category
        if let category = selectedCategory, category != "All" {
            switch category {
            case "Concerts":
                result = result.filter { $0.eventType == "Concert" }
            case "Festivals":
                result = result.filter { $0.eventType == "Festival" }
            default:
                result = result.filter { $0.role == category }
            }
        }
        
        return result
    }

    
    // Group contacts by first letter
    private var groupedContacts: [String: [Contact]] {
        Dictionary(grouping: filteredContacts) { contact in
            String(contact.name.prefix(1).uppercased())
        }
    }
    
    // Sorted group keys
    private var sortedKeys: [String] {
        groupedContacts.keys.sorted()
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // Categories section
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(categories, id: \.self) { category in
                                CategoryButton(
                                    title: category,
                                    isSelected: selectedCategory == category,
                                    action: {
                                        if selectedCategory == category {
                                            selectedCategory = nil
                                        } else {
                                            selectedCategory = category
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .background(Color.gray.opacity(0.1))
                    
                    // Contacts list
                    List {
                        ForEach(sortedKeys, id: \.self) { key in
                            Section(header: Text(key)) {
                                ForEach(groupedContacts[key] ?? []) { contact in
                                    NavigationLink(destination: ContactDetailView(contact: contact)) {
                                        VStack(alignment: .leading) {
                                            Text(contact.name)
                                                .font(.headline)
                                            Text(contact.role)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Text(contact.phone)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        
                        if filteredContacts.isEmpty {
                            HStack {
                                Spacer()
                                Text("No contacts")
                                    .foregroundColor(.gray)
                                    .font(.headline)
                                    .padding()
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }

                    }
                    .listStyle(PlainListStyle())
                }
                
                // Show loading indicator
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(10)
                }
            }
            .navigationTitle("Contacts")
            .searchable(text: $searchText, prompt: "Search contacts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showAddContact = true
                        }) {
                            Label("Add contact", systemImage: "person.badge.plus")
                        }
                        
                        Button(action: {
                            showImportContacts = true
                        }) {
                            Label("Import from contacts", systemImage: "person.crop.circle.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                loadContacts()
            }
            .sheet(isPresented: $showAddContact) {
                AddContactView(isPresented: $showAddContact)
            }
            .sheet(isPresented: $showImportContacts) {
                ContactPickerView { contact in
                    if let contact = contact {
                        importSystemContact(contact)
                    }
                    showImportContacts = false
                }
            }
        }
    }
    
    // Load contacts
    private func loadContacts() {
        isLoading = true
        
        if let groupId = AppState.shared.user?.groupId {
            contactService.fetchContacts(for: groupId)
            isLoading = false
        } else {
            isLoading = false
        }
    }
    
    // Import contact from system contact
    private func importSystemContact(_ contact: CNContact) {
        guard let groupId = AppState.shared.user?.groupId else { return }
        
        // Get name
        let firstName = contact.givenName
        let lastName = contact.familyName
        let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        
        // Get phone
        var phoneNumber = ""
        if let phone = contact.phoneNumbers.first?.value.stringValue {
            phoneNumber = phone
        }
        
        // Get email
        var emailAddress = ""
        if let email = contact.emailAddresses.first?.value as String? {
            emailAddress = email
        }
        
        // Create new contact
        let newContact = Contact(
            name: fullName,
            email: emailAddress,
            phone: phoneNumber,
            role: "Others", // Default
            groupId: groupId
        )
        
        // Add contact
        contactService.addContact(newContact) { _ in
            // Update completed
        }
    }
}

// Helper component for category buttons
struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

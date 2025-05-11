import SwiftUI

struct AddContactView: View {
    @Binding var isPresented: Bool
    @StateObject private var contactService = ContactService.shared
    
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var role = "Musicians"
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Available roles for contacts
    private let roles = ["Musicians", "Organizers","Coordinators", "Venues", "Producers", "Sound Engineers", "Others"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Information")) {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                }
                
                Section(header: Text("Category")) {
                    Picker("Role", selection: $role) {
                        ForEach(roles, id: \.self) {
                            Text($0)
                        }
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button("Save") {
                        saveContact()
                    }
                    .disabled(name.isEmpty || phone.isEmpty || isLoading)
                }
            }
            .navigationTitle("New Contact")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .overlay(Group {
                if isLoading {
                    ProgressView()
                        .padding()
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(8)
                }
            })
        }
    }
    
    private func saveContact() {
        guard let groupId = AppState.shared.user?.groupId else {
            errorMessage = "Could not determine group"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let newContact = Contact(
            name: name,
            email: email,
            phone: phone,
            role: role,
            groupId: groupId
        )
        
        contactService.addContact(newContact) { success in
            isLoading = false
            
            if success {
                isPresented = false
            } else {
                errorMessage = "Failed to add contact"
            }
        }
    }
}

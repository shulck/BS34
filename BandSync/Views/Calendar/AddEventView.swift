import SwiftUI
import MapKit

struct AddEventView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var setlistService = SetlistService.shared
    @State private var showingSetlistSelector = false
    @State private var showingLocationPicker = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedLocation: LocationDetails?
    @State private var showingScheduleEditor = false
    @State private var showingNavigationOptions = false
    @State private var navigationCoordinate: CLLocationCoordinate2D?
    @State private var navigationName: String = ""
    @State private var currentViewController: UIViewController?
    
    @State private var event = Event(
        title: "",
        date: Date(),
        type: .concert,
        status: .booked,
        location: nil,
        organizerName: nil,
        organizerEmail: nil,
        organizerPhone: nil,
        coordinatorName: nil,
        coordinatorEmail: nil,
        coordinatorPhone: nil,
        hotelName: nil,
        hotelAddress: nil,
        hotelCheckIn: nil,
        hotelCheckOut: nil,
        fee: nil,
        currency: "EUR",
        notes: nil,
        schedule: [],
        setlistId: nil,
        groupId: AppState.shared.user?.groupId ?? "",
        isPersonal: false
    )

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic")) {
                    TextField("Title", text: $event.title)
                    DatePicker("Date", selection: $event.date)
                    
                    Picker("Type", selection: $event.type) {
                        ForEach(EventType.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    
                    Picker("Status", selection: $event.status) {
                        ForEach(EventStatus.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    
                    // Setlist field (only for concerts, festivals and rehearsals)
                    if [.concert, .festival, .rehearsal].contains(event.type) {
                        Button {
                            showingSetlistSelector = true
                        } label: {
                            HStack {
                                Text("Setlist")
                                Spacer()
                                Text(getSetlistName())
                                    .foregroundColor(.gray)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                        }
                    }
                }

                Section(header: Text("Location")) {
                    // Button for selecting location on map
                    Button(action: {
                        showingLocationPicker = true
                    }) {
                        HStack {
                            Image(systemName: "map")
                                .foregroundColor(.blue)
                            Text("Select on map")
                        }
                    }
                    
                    // Display selected location
                    if let location = selectedLocation {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(location.name)
                                .font(.headline)
                            Text(location.address)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                        
                        // Button to clear selected location
                        Button("Clear location") {
                            selectedLocation = nil
                            event.location = nil
                        }
                        .foregroundColor(.red)
                    } else {
                        TextField("Venue", text: Binding(
                            get: { event.location ?? "" },
                            set: { event.location = $0.isEmpty ? nil : $0 }
                        ))
                    }
                }

                // Additional fields depending on event type
                if [.concert, .festival].contains(event.type) {
                    // For concerts and festivals show fee information
                    Section(header: Text("Fee")) {
                        HStack {
                            TextField("Amount", value: Binding(
                                get: { event.fee ?? 0 },
                                set: { event.fee = $0 > 0 ? $0 : nil }
                            ), formatter: NumberFormatter())
                            .keyboardType(.decimalPad)
                            
                            TextField("Currency", text: Binding(
                                get: { event.currency ?? "EUR" },
                                set: { event.currency = $0.isEmpty ? "EUR" : $0 }
                            ))
                            .frame(width: 80)
                        }
                    }
                    
                    // Organizer information
                    Section(header: Text("Organizer")) {
                        TextField("Name", text: Binding(
                            get: { event.organizerName ?? "" },
                            set: { event.organizerName = $0.isEmpty ? nil : $0 }
                        ))
                        
                        TextField("Email", text: Binding(
                            get: { event.organizerEmail ?? "" },
                            set: { event.organizerEmail = $0.isEmpty ? nil : $0 }
                        ))
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        
                        TextField("Phone", text: Binding(
                            get: { event.organizerPhone ?? "" },
                            set: { event.organizerPhone = $0.isEmpty ? nil : $0 }
                        ))
                        .keyboardType(.phonePad)
                    }
                    
                    // Coordinator (only for festivals and concerts)
                    Section(header: Text("Coordinator")) {
                        TextField("Name", text: Binding(
                            get: { event.coordinatorName ?? "" },
                            set: { event.coordinatorName = $0.isEmpty ? nil : $0 }
                        ))
                        
                        TextField("Email", text: Binding(
                            get: { event.coordinatorEmail ?? "" },
                            set: { event.coordinatorEmail = $0.isEmpty ? nil : $0 }
                        ))
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        
                        TextField("Phone", text: Binding(
                            get: { event.coordinatorPhone ?? "" },
                            set: { event.coordinatorPhone = $0.isEmpty ? nil : $0 }
                        ))
                        .keyboardType(.phonePad)
                    }
                }

                // For events requiring accommodation - improve section
                if [.concert, .festival, .photoshoot].contains(event.type) {
                    Section(header: Text("Accommodation")) {
                        TextField("Hotel name", text: Binding(
                            get: { event.hotelName ?? "" },
                            set: { event.hotelName = $0.isEmpty ? nil : $0 }
                        ))
                        .autocapitalization(.words)

                        TextField("Hotel address", text: Binding(
                            get: { event.hotelAddress ?? "" },
                            set: { event.hotelAddress = $0.isEmpty ? nil : $0 }
                        ))
                        .autocapitalization(.words)

                        // Show remaining fields only if hotel name is filled
                        if let hotelName = event.hotelName, !hotelName.isEmpty {
                            DatePicker("Check-in", selection: Binding(
                                get: { event.hotelCheckIn ?? Date() },
                                set: { event.hotelCheckIn = $0 }
                            ), displayedComponents: [.date, .hourAndMinute])
                            
                            DatePicker("Check-out", selection: Binding(
                                get: { event.hotelCheckOut ?? Calendar.current.date(byAdding: .day, value: 1, to: Date())! },
                                set: { event.hotelCheckOut = $0 }
                            ), displayedComponents: [.date, .hourAndMinute])
                            
                            // Add button to check route to hotel if address is filled
                            if let address = event.hotelAddress, !address.isEmpty {
                                Button {
                                    checkRouteToHotel(address)
                                } label: {
                                    Label("Check route", systemImage: "map")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }

                Section(header: Text("Notes")) {
                    TextEditor(text: Binding(
                        get: { event.notes ?? "" },
                        set: { event.notes = $0.isEmpty ? nil : $0 }
                    ))
                    .frame(minHeight: 100)
                }
                
                // Daily schedule section - should always be visible
                Section(header: Text("Daily schedule")) {
                    Button {
                        showingScheduleEditor = true
                    } label: {
                        HStack {
                            Text("Schedule")
                            Spacer()
                            if let schedule = event.schedule, !schedule.isEmpty {
                                Text("\(schedule.count) items")
                                    .foregroundColor(.gray)
                            } else {
                                Text("Add schedule")
                                    .foregroundColor(.blue)
                            }
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray.opacity(0.5))
                        }
                    }
                    
                    // Show schedule preview if it exists
                    if let schedule = event.schedule, !schedule.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(schedule.prefix(3), id: \.self) { item in
                                Text("• \(item)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            if schedule.count > 3 {
                                Text("and more \(schedule.count - 3)...")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                
                // Display errors
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("New event")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEvent()
                    }
                    .disabled(event.title.isEmpty || isLoading)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingSetlistSelector) {
                SetlistSelectorView(selectedSetlistId: $event.setlistId)
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(selectedLocation: $selectedLocation)
                    .onDisappear {
                        // Update event location when a place is selected on the map
                        if let location = selectedLocation {
                            event.location = location.name + ", " + location.address
                        }
                    }
            }
            .sheet(isPresented: $showingScheduleEditor) {
                ScheduleEditorSheet(schedule: $event.schedule)
            }
            .overlay(Group {
                if isLoading {
                    ProgressView()
                        .padding()
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(8)
                        .shadow(radius: 3)
                }
            })
            .onAppear {
                if let groupId = AppState.shared.user?.groupId {
                    setlistService.fetchSetlists(for: groupId)
                }
            }
        }
    }
    
    // Get selected setlist name
    private func getSetlistName() -> String {
        if let setlistId = event.setlistId,
           let setlist = setlistService.setlists.first(where: { $0.id == setlistId }) {
            return setlist.name
        }
        return "Not selected"
    }
    
    // Function to check route to hotel
    private func checkRouteToHotel(_ address: String) {
        NavigationService.shared.navigateToAddress(address, name: event.hotelName ?? "Hotel")
    }
    
    // Save event
    private func saveEvent() {
        guard let groupId = AppState.shared.user?.groupId else {
            errorMessage = "Could not determine group"
            return
        }
        
        isLoading = true
        event.groupId = groupId
        
        // Save event first
        EventService.shared.addEvent(event) { success in
            DispatchQueue.main.async {
                isLoading = false
                
                if success {
                    // Schedule notifications for events
                    NotificationManager.shared.scheduleEventNotification(event: event)
                    
                    // Save organizer and coordinator contacts
                    saveContacts(for: event)
                    
                    dismiss()
                } else {
                    errorMessage = "Failed to save event"
                }
            }
        }
    }

    // Function to save organizer and coordinator contacts
    private func saveContacts(for event: Event) {
        // Save Organizer contact if available
        if let organizerName = event.organizerName,
           let organizerEmail = event.organizerEmail,
           let organizerPhone = event.organizerPhone {
            let organizerContact = Contact(
                name: organizerName,
                email: organizerEmail,
                phone: organizerPhone,
                role: "Organizers",
                groupId: event.groupId,
                eventTag: event.title,
                eventType: event.type.rawValue
            )
            ContactService.shared.addContact(organizerContact) { success in
                if !success {
                    print("Failed to save organizer contact")
                }
            }
        }
        
        // Save Coordinator contact if available
        if let coordinatorName = event.coordinatorName,
           let coordinatorEmail = event.coordinatorEmail,
           let coordinatorPhone = event.coordinatorPhone {
            let coordinatorContact = Contact(
                name: coordinatorName,
                email: coordinatorEmail,
                phone: coordinatorPhone,
                role: "Coordinators",
                groupId: event.groupId,
                eventTag: event.title,
                eventType: event.type.rawValue
            )
            ContactService.shared.addContact(coordinatorContact) { success in
                if !success {
                    print("Failed to save coordinator contact")
                }
            }
        }
    }

}

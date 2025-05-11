import SwiftUI
import MapKit

struct EventDetailView: View {
    @StateObject private var setlistService = SetlistService.shared
    
    // Breaking state into smaller parts
    @State private var event: Event
    @State private var isEditing = false
    @State private var showingSetlistSelector = false
    @State private var showingLocationPicker = false
    @State private var showingDeleteConfirmation = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedLocation: LocationDetails?
    @State private var showingScheduleEditor = false
    @State private var showingNavigationOptions = false
    @State private var navigationCoordinate: CLLocationCoordinate2D?
    @State private var navigationName: String = ""
    @State private var currentViewController: UIViewController?
    @Environment(\.dismiss) var dismiss
    
    // Simplified initializer
    init(event: Event) {
        self._event = State(initialValue: event)
    }
    
    var body: some View {
        // Simplifying structure by breaking into subcomponents
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Event header with color indication of type
                eventHeaderSection
                
                Divider()
                
                // Location section - always shown as it's mandatory
                locationSection
                
                Divider()
                
                // Daily schedule section - only when data is available or in edit mode
                if isEditing || (event.schedule != nil && !event.schedule!.isEmpty) {
                    scheduleSection
                    Divider()
                }
                
                // Setlist section (only for corresponding event types and when data is available)
                if [.concert, .festival, .rehearsal].contains(event.type) &&
                   (isEditing || event.setlistId != nil) {
                    setlistSection
                    Divider()
                }
                
                // Organizer (only when data is available or in edit mode)
                if [.concert, .festival, .interview, .photoshoot].contains(event.type) &&
                   (isEditing || hasOrganizerData()) {
                    organizerSection
                    Divider()
                }
                
                // Coordinator (only when data is available or in edit mode)
                if [.concert, .festival].contains(event.type) &&
                   (isEditing || hasCoordinatorData()) {
                    coordinatorSection
                    Divider()
                }
                
                // Hotel (only when data is available or in edit mode)
                if [.concert, .festival, .photoshoot].contains(event.type) &&
                   (isEditing || hasHotelData()) {
                    hotelSection
                    Divider()
                }
                
                // Fee (only when data is available or in edit mode)
                if [.concert, .festival, .interview, .photoshoot].contains(event.type) &&
                   (isEditing || (event.fee != nil && event.currency != nil)) {
                    financesSection
                    Divider()
                }
                
                // Notes (only when available or in edit mode)
                if isEditing || (event.notes != nil && !event.notes!.isEmpty) {
                    notesSection
                }
                
                // Display errors
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                // Delete button (only for admins and managers)
                if AppState.shared.hasEditPermission(for: .calendar) && !isEditing {
                    deleteButton
                }
                
                Spacer(minLength: 50)
            }
            .padding(.vertical)
        }
        .navigationTitle(isEditing ? "Editing" : "Event")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            mainToolbarItems
        }
        .overlay(loadingOverlay)
        .alert("Delete event?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteEvent()
            }
        } message: {
            Text("Are you sure you want to delete this event? This action cannot be undone.")
        }
        .sheet(isPresented: $showingSetlistSelector) {
            SetlistSelectorView(selectedSetlistId: $event.setlistId)
        }
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerView(selectedLocation: $selectedLocation)
                .onDisappear {
                    if let location = selectedLocation {
                        event.location = location.name + ", " + location.address
                    }
                }
        }
        .sheet(isPresented: $showingScheduleEditor) {
            ScheduleEditorSheet(schedule: $event.schedule)
        }
        .onAppear {
            setupOnAppear()
        }
        .background(
            NavigationServiceHost { viewController in
                self.currentViewController = viewController
            }
        )
    }
    
    // MARK: - UI Components
    
    // Event header
    private var eventHeaderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEditing {
                TextField("Event name", text: $event.title)
                    .font(.title.bold())
                    .padding(.bottom, 4)
            } else {
                Text(event.title)
                    .font(.title.bold())
                    .foregroundColor(Color(UIColor(hex: event.type.color)))
                    .padding(.bottom, 4)
            }
            
            eventTypeAndStatusRow
            
            if isEditing {
                DatePicker("Date and time", selection: $event.date)
            } else {
                Label(formatDate(event.date), systemImage: "calendar")
            }
        }
        .padding(.horizontal)
    }
    
    // Row with event type and status
    private var eventTypeAndStatusRow: some View {
        HStack(spacing: 16) {
            if isEditing {
                Picker("Type", selection: $event.type) {
                    ForEach(EventType.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
            } else {
                Label(event.type.rawValue, systemImage: getIconForEventType(event.type))
                    .foregroundColor(Color(UIColor(hex: event.type.color)))
            }
            
            if isEditing {
                Picker("Status", selection: $event.status) {
                    ForEach(EventStatus.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
            } else {
                Label(event.status.rawValue, systemImage: "checkmark.circle")
            }
        }
    }
    
    // Location section
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location")
                .font(.headline)
                .padding(.horizontal)
            
            if isEditing {
                editingLocationView
            } else {
                VStack(spacing: 12) {
                    EventMapView(event: event)
                    
                    if let location = event.location, !location.isEmpty {
                        Button {
                            showLocationDirections(address: location, name: event.title)
                        } label: {
                            Label("Get directions", systemImage: "arrow.triangle.turn.up.right.diamond")
                                .foregroundColor(.blue)
                                .padding(8)
                                .frame(maxWidth: .infinity)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
    
    // Editing location
    private var editingLocationView: some View {
        VStack(spacing: 10) {
            Button(action: {
                showingLocationPicker = true
            }) {
                HStack {
                    Image(systemName: "map")
                        .foregroundColor(.blue)
                    Text("Select on map")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            .padding(.horizontal)
            
            if let location = selectedLocation {
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.name)
                        .font(.headline)
                    Text(location.address)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            } else {
                TextField("Venue", text: Binding(
                    get: { event.location ?? "" },
                    set: { event.location = $0.isEmpty ? nil : $0 }
                ))
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
    }
    
    // Daily schedule section
    private var scheduleSection: some View {
        Group {
            if isEditing || (event.schedule != nil && !event.schedule!.isEmpty) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Daily schedule")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if isEditing {
                        Button {
                            showingScheduleEditor = true
                        } label: {
                            HStack {
                                Label(
                                    event.schedule == nil || event.schedule!.isEmpty ?
                                        "Add schedule" : "Edit schedule",
                                    systemImage: event.schedule == nil || event.schedule!.isEmpty ?
                                        "plus.circle" : "pencil"
                                )
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    } else if let schedule = event.schedule, !schedule.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(schedule, id: \.self) { item in
                                if item.contains(" - ") {
                                    HStack(alignment: .top) {
                                        let components = item.split(separator: " - ", maxSplits: 1)
                                        if components.count == 2 {
                                            Text(String(components[0]))
                                                .bold()
                                                .frame(width: 70, alignment: .leading)
                                            
                                            Text(String(components[1]))
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                } else {
                                    Text(item)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    } else {
                        Text("No schedule added")
                            .foregroundColor(.gray)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                }
            }
        }
    }
    
    // Setlist section
    private var setlistSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Setlist")
                .font(.headline)
                .padding(.horizontal)
            
            if isEditing {
                editingSetlistView
            } else {
                displaySetlistView
            }
        }
    }
    
    // Editing setlist
    private var editingSetlistView: some View {
        Button {
            showingSetlistSelector = true
        } label: {
            HStack {
                if let setlistId = event.setlistId,
                   let setlist = setlistService.setlists.first(where: { $0.id == setlistId }) {
                    Label(setlist.name, systemImage: "music.note.list")
                } else {
                    Label("Select setlist", systemImage: "plus.circle")
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(.horizontal)
    }
    
    // Displaying setlist
    private var displaySetlistView: some View {
        Group {
            if let setlistId = event.setlistId,
               let setlist = setlistService.setlists.first(where: { $0.id == setlistId }) {
                NavigationLink(destination: SetlistDetailView(setlist: setlist)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(setlist.name, systemImage: "music.note.list")
                        Text("\(setlist.songs.count) songs • \(setlist.formattedTotalDuration)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
            } else {
                Text("No setlist selected")
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .foregroundColor(.gray)
            }
        }
    }
    
    // Organizer section
    private var organizerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Organizer")
                .font(.headline)
                .padding(.horizontal)
            
            if isEditing {
                editingOrganizerView
            } else {
                displayOrganizerView
            }
        }
    }
    
    // Editing organizer information
    private var editingOrganizerView: some View {
        VStack(spacing: 10) {
            TextField("Name", text: Binding(
                get: { event.organizerName ?? "" },
                set: { event.organizerName = $0.isEmpty ? nil : $0 }
            ))
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            TextField("Email", text: Binding(
                get: { event.organizerEmail ?? "" },
                set: { event.organizerEmail = $0.isEmpty ? nil : $0 }
            ))
            .keyboardType(.emailAddress)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            TextField("Phone", text: Binding(
                get: { event.organizerPhone ?? "" },
                set: { event.organizerPhone = $0.isEmpty ? nil : $0 }
            ))
            .keyboardType(.phonePad)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(.horizontal)
    }
    
    // Displaying organizer information
    private var displayOrganizerView: some View {
        Group {
            // Fixing conditional expression
            if (event.organizerName != nil && !event.organizerName!.isEmpty) ||
               (event.organizerEmail != nil && !event.organizerEmail!.isEmpty) ||
               (event.organizerPhone != nil && !event.organizerPhone!.isEmpty) {
                
                VStack(alignment: .leading, spacing: 8) {
                    if let name = event.organizerName, !name.isEmpty {
                        Label(name, systemImage: "person")
                    }
                    
                    if let email = event.organizerEmail, !email.isEmpty {
                        Button {
                            openMail(email)
                        } label: {
                            Label(email, systemImage: "envelope")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if let phone = event.organizerPhone, !phone.isEmpty {
                        Button {
                            call(phone)
                        } label: {
                            Label(phone, systemImage: "phone")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
    }
    
    // Coordinator section (for festivals and concerts)
    private var coordinatorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Coordinator")
                .font(.headline)
                .padding(.horizontal)
            
            if isEditing {
                editingCoordinatorView
            } else {
                displayCoordinatorView
            }
        }
    }
    
    // Editing coordinator information
    private var editingCoordinatorView: some View {
        VStack(spacing: 10) {
            TextField("Name", text: Binding(
                get: { event.coordinatorName ?? "" },
                set: { event.coordinatorName = $0.isEmpty ? nil : $0 }
            ))
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            TextField("Email", text: Binding(
                get: { event.coordinatorEmail ?? "" },
                set: { event.coordinatorEmail = $0.isEmpty ? nil : $0 }
            ))
            .keyboardType(.emailAddress)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            TextField("Phone", text: Binding(
                get: { event.coordinatorPhone ?? "" },
                set: { event.coordinatorPhone = $0.isEmpty ? nil : $0 }
            ))
            .keyboardType(.phonePad)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(.horizontal)
    }
    
    // Displaying coordinator information
    private var displayCoordinatorView: some View {
        Group {
            // Fixing conditional expression
            if (event.coordinatorName != nil && !event.coordinatorName!.isEmpty) ||
               (event.coordinatorEmail != nil && !event.coordinatorEmail!.isEmpty) ||
               (event.coordinatorPhone != nil && !event.coordinatorPhone!.isEmpty) {
                
                VStack(alignment: .leading, spacing: 8) {
                    if let name = event.coordinatorName, !name.isEmpty {
                        Label(name, systemImage: "person")
                    }
                    
                    if let email = event.coordinatorEmail, !email.isEmpty {
                        Button {
                            openMail(email)
                        } label: {
                            Label(email, systemImage: "envelope")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if let phone = event.coordinatorPhone, !phone.isEmpty {
                        Button {
                            call(phone)
                        } label: {
                            Label(phone, systemImage: "phone")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if event.coordinatorName == nil && event.coordinatorEmail == nil && event.coordinatorPhone == nil {
                        Text("No coordinator information")
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
    }
    
    // Hotel section
    private var hotelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Accommodation")
                .font(.headline)
                .padding(.horizontal)
            
            if isEditing {
                editingHotelView
            } else {
                displayHotelView
            }
        }
    }
    
    // Editing hotel information
    private var editingHotelView: some View {
        VStack(spacing: 10) {
            TextField("Hotel name", text: Binding(
                get: { event.hotelName ?? "" },
                set: { event.hotelName = $0.isEmpty ? nil : $0 }
            ))
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            TextField("Hotel address", text: Binding(
                get: { event.hotelAddress ?? "" },
                set: { event.hotelAddress = $0.isEmpty ? nil : $0 }
            ))
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            if event.hotelName != nil && !event.hotelName!.isEmpty {
                DatePicker("Check-in", selection: Binding(
                    get: { event.hotelCheckIn ?? Date() },
                    set: { event.hotelCheckIn = $0 }
                ))
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                DatePicker("Check-out", selection: Binding(
                    get: { event.hotelCheckOut ?? Calendar.current.date(byAdding: .day, value: 1, to: Date())! },
                    set: { event.hotelCheckOut = $0 }
                ))
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
    
    // Displaying hotel information
    private var displayHotelView: some View {
        Group {
            if let hotelName = event.hotelName, !hotelName.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label(hotelName, systemImage: "house")
                    
                    if let hotelAddress = event.hotelAddress, !hotelAddress.isEmpty {
                        Label(hotelAddress, systemImage: "location")
                        
                        // Adding button to open hotel address in Maps
                        Button {
                            openMaps(for: hotelAddress)
                        } label: {
                            Label("Open in Maps", systemImage: "map")
                                .foregroundColor(.blue)
                        }
                        
                        // Button for directions
                        Button {
                            NavigationService.shared.navigateToAddress(hotelAddress, name: hotelName)
                        } label: {
                            Label("Get directions", systemImage: "arrow.triangle.turn.up.right.diamond")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if let checkIn = event.hotelCheckIn {
                        Label("Check-in: \(formatDateTime(checkIn))", systemImage: "arrow.down.to.line")
                    }
                    
                    if let checkOut = event.hotelCheckOut {
                        Label("Check-out: \(formatDateTime(checkOut))", systemImage: "arrow.up.to.line")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
    }
    
    // Finances section
    private var financesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Finances")
                .font(.headline)
                .padding(.horizontal)
            
            if isEditing {
                editingFinancesView
            } else {
                displayFinancesView
            }
        }
    }
    
    // Editing financial information
    private var editingFinancesView: some View {
        HStack {
            TextField("Amount", value: Binding(
                get: { event.fee ?? 0 },
                set: { event.fee = $0 > 0 ? $0 : nil }
            ), formatter: NumberFormatter())
            .keyboardType(.decimalPad)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            TextField("Currency", text: Binding(
                get: { event.currency ?? "EUR" },
                set: { event.currency = $0.isEmpty ? "EUR" : $0 }
            ))
            .frame(width: 80)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(.horizontal)
    }
    
    // Displaying financial information
    private var displayFinancesView: some View {
        Group {
            if let fee = event.fee, let currency = event.currency {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Fee: \(Int(fee)) \(currency)", systemImage: "dollarsign")
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
    }
    
    // Notes section
    private var notesSection: some View {
        Group {
            if isEditing || (event.notes != nil && !event.notes!.isEmpty) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if isEditing {
                        TextEditor(text: Binding(
                            get: { event.notes ?? "" },
                            set: { event.notes = $0.isEmpty ? nil : $0 }
                        ))
                        .frame(minHeight: 100)
                        .padding(4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    } else if let notes = event.notes, !notes.isEmpty {
                        Text(notes)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    } else {
                        Text("No notes")
                            .foregroundColor(.gray)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                }
            }
        }
    }
    
    // Delete button
    private var deleteButton: some View {
        Button {
            showingDeleteConfirmation = true
        } label: {
            Label("Delete event", systemImage: "trash")
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }
    
    // Toolbar items
    @ToolbarContentBuilder
    private var mainToolbarItems: some ToolbarContent {
        // Edit/Save button (only for administrators and managers)
        if AppState.shared.hasEditPermission(for: .calendar) {
            ToolbarItem(placement: .primaryAction) {
                if isEditing {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(event.title.isEmpty || isLoading)
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
                    cancelEditing()
                }
            }
        }
    }
    
    // Loading indicator
    private var loadingOverlay: some View {
        Group {
            if isLoading {
                ProgressView()
                    .padding()
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(8)
                    .shadow(radius: 3)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    // Initialize on first appearance
    private func setupOnAppear() {
        if let groupId = AppState.shared.user?.groupId {
            setlistService.fetchSetlists(for: groupId)
        }
        
        // Try to extract location information from text field
        if selectedLocation == nil, let locationText = event.location, !locationText.isEmpty {
            geocodeEventLocation(locationText)
        }
    }
    
    // Cancel editing
    private func cancelEditing() {
        // Restore original data
        if let original = EventService.shared.events.first(where: { $0.id == event.id }) {
            event = original
            selectedLocation = nil
        }
        isEditing = false
    }
    
    // Get icon depending on event type
    private func getIconForEventType(_ type: EventType) -> String {
        switch type {
        case .concert: return "music.mic"
        case .festival: return "music.note.list"
        case .rehearsal: return "pianokeys"
        case .meeting: return "person.2"
        case .interview: return "quote.bubble"
        case .photoshoot: return "camera"
        case .personal: return "person.crop.circle"
        }
    }
    
    // Format date
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Format date and time
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Call function
    private func call(_ phone: String) {
        if let url = URL(string: "tel://\(phone.replacingOccurrences(of: " ", with: ""))"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    // Send email function
    private func openMail(_ email: String) {
        if let url = URL(string: "mailto:\(email)"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    // Open address in Maps function
    private func openMaps(for address: String) {
        let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "http://maps.apple.com/?q=\(encodedAddress)"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    // Function for routing directions
    private func openMapsWithDirections(to coordinate: CLLocationCoordinate2D, name: String) {
        navigationCoordinate = coordinate
        navigationName = name
        showingNavigationOptions = true
    }
    
    // Geocode location text
    private func geocodeEventLocation(_ locationText: String) {
        let geocoder = CLGeocoder()
        
        geocoder.geocodeAddressString(locationText) { placemarks, error in
            // Check for errors
            if let error = error {
                print("Geocoding error: \(error.localizedDescription)")
                return
            }
            
            // Get first result
            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                return
            }
            
            // Get place name
            let name: String
            if let placemarkName = placemark.name {
                name = placemarkName
            } else if let eventLocation = self.event.location {
                name = eventLocation
            } else {
                name = "Event location"
            }
            
            // Get address
            let address = self.formatAddress(from: placemark)
            
            // Create identifier
            let detailsId = UUID().uuidString
            
            // Get coordinates
            let coordinates = location.coordinate
            
            // Create location details object
            let details = LocationDetails(
                id: detailsId,
                name: name,
                address: address,
                coordinate: coordinates
            )
            
            // Update location on main thread
            DispatchQueue.main.async {
                self.selectedLocation = details
            }
        }
    }
    
    // Format address from place mark
    private func formatAddress(from placemark: CLPlacemark) -> String {
        var address = ""
        
        if let thoroughfare = placemark.thoroughfare {
            address += thoroughfare
        }
        
        if let subThoroughfare = placemark.subThoroughfare {
            if !address.isEmpty {
                address += " "
            }
            address += subThoroughfare
        }
        
        if let locality = placemark.locality {
            if !address.isEmpty {
                address += ", "
            }
            address += locality
        }
        
        if let administrativeArea = placemark.administrativeArea {
            if !address.isEmpty {
                address += ", "
            }
            address += administrativeArea
        }
        
        if address.isEmpty {
            address = "Unknown address"
        }
        
        return address
    }
    
    // Save changes
    private func saveChanges() {
        isLoading = true
        
        EventService.shared.updateEvent(event) { success in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if success {
                    // Update notifications for events
                    NotificationManager.shared.scheduleEventNotification(event: self.event)
                    self.isEditing = false
                } else {
                    self.errorMessage = "Failed to save changes"
                }
            }
        }
    }
    
    // Delete event
    private func deleteEvent() {
        // Cancel notifications for this event
        if let eventId = event.id {
            NotificationManager.shared.cancelNotification(withIdentifier: "event_day_before_\(eventId)")
            NotificationManager.shared.cancelNotification(withIdentifier: "event_hour_before_\(eventId)")
        }
        
        EventService.shared.deleteEvent(event)
        dismiss()
    }
    
    // Helper methods for checking data availability
    private func hasOrganizerData() -> Bool {
        return (event.organizerName != nil && !event.organizerName!.isEmpty) ||
               (event.organizerEmail != nil && !event.organizerEmail!.isEmpty) ||
               (event.organizerPhone != nil && !event.organizerPhone!.isEmpty)
    }

    private func hasCoordinatorData() -> Bool {
        return (event.coordinatorName != nil && !event.coordinatorName!.isEmpty) ||
               (event.coordinatorEmail != nil && !event.coordinatorEmail!.isEmpty) ||
               (event.coordinatorPhone != nil && !event.coordinatorPhone!.isEmpty)
    }

    private func hasHotelData() -> Bool {
        return (event.hotelName != nil && !event.hotelName!.isEmpty) ||
               (event.hotelAddress != nil && !event.hotelAddress!.isEmpty) ||
               event.hotelCheckIn != nil || event.hotelCheckOut != nil
    }

    // New function to show route
    private func showLocationDirections(address: String, name: String) {
        NavigationService.shared.navigateToAddress(address, name: name)
    }
}

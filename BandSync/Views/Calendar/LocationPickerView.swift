//
//  LocationPickerView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


import SwiftUI
import MapKit
import Combine

struct LocationPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedLocation: LocationDetails?
    
    @State private var searchText = ""
    @State private var searchResults: [LocationDetails] = []
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 50.450001, longitude: 30.523333), // Kyiv
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var isSearching = false
    @State private var cancellables = Set<AnyCancellable>()
    
    private let searchPublisher = PassthroughSubject<String, Never>()
    
    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                TextField("Search location", text: $searchText)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .onChange(of: searchText) { newValue in
                        searchPublisher.send(newValue)
                    }
                
                Button("Cancel") {
                    dismiss()
                }
            }
            .padding()
            
            if isSearching {
                // Loading indicator
                ProgressView()
                    .padding()
            } else if !searchResults.isEmpty && !searchText.isEmpty {
                // Search results
                List {
                    ForEach(searchResults) { location in
                        Button {
                            selectLocation(location)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(location.name)
                                    .font(.headline)
                                Text(location.address)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                .listStyle(PlainListStyle())
            } else {
                // Map for location selection
                Map(coordinateRegion: $region, annotationItems: selectedLocation != nil ? [selectedLocation!] : []) { location in
                    MapMarker(coordinate: location.coordinate, tint: .red)
                }
                .gesture(
                    TapGesture()
                        .onEnded { _ in
                            // Use center of visible region for location selection
                            selectCoordinate(region.center)
                        }
                )
            }
        }
        .navigationTitle("Select location")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupSearchPublisher()
            
            // Request current user location
            LocationManager.shared.requestLocation { location in
                if let location = location {
                    region = MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )
                }
            }
        }
    }
    
    // Setup publisher for search with delay
    private func setupSearchPublisher() {
        searchPublisher
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .filter { !$0.isEmpty && $0.count >= 3 }
            .sink { searchText in
                searchLocations(query: searchText)
            }
            .store(in: &cancellables)
    }
    
    // Search locations by query
    private func searchLocations(query: String) {
        isSearching = true
        searchResults = []
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isSearching = false
            
            guard let response = response, error == nil else {
                return
            }
            
            searchResults = response.mapItems.map { item in
                LocationDetails(
                    id: UUID().uuidString,
                    name: item.name ?? "Unknown location",
                    address: formatAddress(from: item.placemark),
                    coordinate: item.placemark.coordinate
                )
            }
        }
    }
    
    // Select location from search results
    private func selectLocation(_ location: LocationDetails) {
        selectedLocation = location
        dismiss()
    }
    
    // Select coordinates on map
    private func selectCoordinate(_ coordinate: CLLocationCoordinate2D) {
        // Get location information by coordinates
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
            guard let placemark = placemarks?.first, error == nil else {
                return
            }
            
            let locationDetails = LocationDetails(
                id: UUID().uuidString,
                name: placemark.name ?? "Selected location",
                address: formatAddress(from: placemark),
                coordinate: coordinate
            )
            
            selectedLocation = locationDetails
            dismiss()
        }
    }
    
    // Add function to open route in maps
    private func openMapsWithDirections(to coordinate: CLLocationCoordinate2D, name: String) {
        // Option 1: Apple Maps
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
        
        // Option 2: Google Maps (if installed)
        let googleUrlString = "comgooglemaps://?daddr=\(coordinate.latitude),\(coordinate.longitude)&directionsmode=driving"
        if let googleUrl = URL(string: googleUrlString), UIApplication.shared.canOpenURL(googleUrl) {
            UIApplication.shared.open(googleUrl)
        }
    }
    
    // Format address from placemark
    private func formatAddress(from placemark: CLPlacemark) -> String {
        var address = ""
        
        if let thoroughfare = placemark.thoroughfare {
            address += thoroughfare
        }
        
        if let subThoroughfare = placemark.subThoroughfare {
            if (!address.isEmpty) {
                address += " "
            }
            address += subThoroughfare
        }
        
        if let locality = placemark.locality {
            if (!address.isEmpty) {
                address += ", "
            }
            address += locality
        }
        
        if let administrativeArea = placemark.administrativeArea {
            if (!address.isEmpty) {
                address += ", "
            }
            address += administrativeArea
        }
        
        if let country = placemark.country {
            if (!address.isEmpty) {
                address += ", "
            }
            address += country
        }
        
        if (address.isEmpty) {
            address = "Unknown address"
        }
        
        return address
    }
}

// Model for location details
struct LocationDetails: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var address: String
    var coordinate: CLLocationCoordinate2D
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case address
        case latitude
        case longitude
    }
    
    init(id: String, name: String, address: String, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.name = name
        self.address = address
        self.coordinate = coordinate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        address = try container.decode(String.self, forKey: .address)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(address, forKey: .address)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
    }
    
    static func == (lhs: LocationDetails, rhs: LocationDetails) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.address == rhs.address &&
               lhs.coordinate.latitude == rhs.coordinate.latitude &&
               lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

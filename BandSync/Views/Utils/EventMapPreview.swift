//
//  EventMapPreview.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 02.04.2025.
//
import SwiftUI
import MapKit

struct EventMapPreview: View {
    let event: Event
    
    @State private var region: MKCoordinateRegion
    @State private var mapPoints: [EventMapPoint] = []
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Map(coordinateRegion: $region, annotationItems: mapPoints) { point in
                MapAnnotation(coordinate: point.coordinate) {
                    // ...existing code...
                }
            }
            
            // Loading indicator
            if isLoading {
                ProgressView()
                    .padding(8)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(8)
            }
        }
        .onAppear {
            geocodeEventLocation()
        }
    }
    
    private func geocodeEventLocation() {
        isLoading = true
        
        guard let locationString = event.location, !locationString.isEmpty else {
            isLoading = false
            return
        }
        
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(locationString) { placemarks, error in
            if let error = error {
                print("Location geocoding error: \(error.localizedDescription)")
                isLoading = false
                return
            }
            
            guard let placemark = placemarks?.first, let location = placemark.location else {
                isLoading = false
                return
            }
            
            // Create annotation
            let coordinate = location.coordinate
            let name = placemark.name ?? "Venue"
            let address = formatAddress(from: placemark)
            
            // Create map annotation
            let newAnnotation = EventMapPoint(
                id: UUID().uuidString,
                title: name,
                coordinate: coordinate
            )
            
            // Update region and annotation
            DispatchQueue.main.async {
                region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
                mapPoints = [newAnnotation]
                isLoading = false
            }
        }
    }
    
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
}

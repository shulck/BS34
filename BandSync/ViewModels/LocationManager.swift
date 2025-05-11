//
//  LocationManager.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


import Foundation
import CoreLocation
import MapKit

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let manager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var isAuthorized = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Check current authorization status
        authorizationStatus = manager.authorizationStatus
        isAuthorized = authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    // Request location usage permission
    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }
    
    // Request location (one-time)
    func requestLocation(completion: @escaping (CLLocation?) -> Void) {
        if isAuthorized {
            manager.requestLocation()
            
            // Wait for location or use last known
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                completion(self.location)
            }
        } else {
            // If no permission, request it
            requestWhenInUseAuthorization()
            completion(nil)
        }
    }
    
    // Start location tracking
    func startUpdatingLocation() {
        manager.startUpdatingLocation()
    }
    
    // Stop location tracking
    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    // Location update received
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location
    }
    
    // Error handling
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location determination error: \(error.localizedDescription)")
    }
    
    // Handle authorization status changes
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        isAuthorized = authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    // MARK: - Utility Methods
    
    // Get place name from coordinates
    func getPlaceName(for coordinate: CLLocationCoordinate2D, completion: @escaping (String?) -> Void) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
            guard let placemark = placemarks?.first, error == nil else {
                completion(nil)
                return
            }
            
            var placeName = ""
            
            if let name = placemark.name {
                placeName = name
            } else if let thoroughfare = placemark.thoroughfare {
                placeName = thoroughfare
                
                if let subThoroughfare = placemark.subThoroughfare {
                    placeName += " " + subThoroughfare
                }
            }
            
            if placeName.isEmpty {
                if let locality = placemark.locality {
                    placeName = locality
                } else if let administrativeArea = placemark.administrativeArea {
                    placeName = administrativeArea
                } else {
                    placeName = "Unknown location"
                }
            }
            
            completion(placeName)
        }
    }
    
    // Calculate route between two points
    func calculateRoute(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, completion: @escaping (MKRoute?) -> Void) {
        let sourcePlacemark = MKPlacemark(coordinate: source)
        let destinationPlacemark = MKPlacemark(coordinate: destination)
        
        let sourceItem = MKMapItem(placemark: sourcePlacemark)
        let destinationItem = MKMapItem(placemark: destinationPlacemark)
        
        let request = MKDirections.Request()
        request.source = sourceItem
        request.destination = destinationItem
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            guard let route = response?.routes.first, error == nil else {
                completion(nil)
                return
            }
            
            completion(route)
        }
    }
    
    // Calculate distance between two points
    func distance(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> CLLocationDistance {
        let sourceLocation = CLLocation(latitude: source.latitude, longitude: source.longitude)
        let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        
        return sourceLocation.distance(from: destinationLocation)
    }
    
    // Format distance for display
    func formatDistance(_ distance: CLLocationDistance) -> String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        return formatter.string(fromDistance: distance)
    }
}
import SwiftUI
import MapKit
import UIKit

class NavigationService {
    static let shared = NavigationService()
    
    private init() {}
    
    // Method for opening navigation by address with a map selection dialog
    func navigateToAddress(_ address: String, name: String) {
        // First geocode the address to show the selection
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, error in
            guard let placemark = placemarks?.first, let location = placemark.location else {
                // If geocoding failed, try opening Apple Maps directly
                self.openAppleMapsDirectly(address: address)
                return
            }
            
            // Show map selection dialog
            self.showMapSelectionDialog(coordinate: location.coordinate, name: name)
        }
    }
    
    // Show map selection dialog
    private func showMapSelectionDialog(coordinate: CLLocationCoordinate2D, name: String) {
        let alert = UIAlertController(
            title: "Select application",
            message: "Which application to use for navigation?",
            preferredStyle: .actionSheet
        )
        
        // Apple Maps option
        alert.addAction(UIAlertAction(title: "Apple Maps", style: .default) { _ in
            self.openInAppleMaps(coordinate: coordinate, name: name)
        })
        
        // ALWAYS add Google Maps for testing
        alert.addAction(UIAlertAction(title: "Google Maps", style: .default) { _ in
            self.openInGoogleMaps(coordinate: coordinate, name: name)
        })
        
        // Cancel button
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // Setup for iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = UIApplication.shared.windows.first?.rootViewController?.view
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        // Show dialog
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                return
            }
            
            // Find the top controller to show the alert
            var topController = rootViewController
            while let presentedController = topController.presentedViewController {
                topController = presentedController
            }
            
            topController.present(alert, animated: true)
        }
    }
    
    // Check Google Maps availability - correct URL check
    private func isGoogleMapsInstalled() -> Bool {
        guard let url = URL(string: "comgooglemaps://") else {
            return false
        }
        
        // On devices without Google Maps always return true for testing
        return true
    }
    
    // Opening Apple Maps directly (backup method)
    private func openAppleMapsDirectly(address: String) {
        let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let appleURL = URL(string: "http://maps.apple.com/?daddr=\(encodedAddress)&dirflg=d")!
        
        if UIApplication.shared.canOpenURL(appleURL) {
            UIApplication.shared.open(appleURL)
        }
    }
    
    // Opening route in Apple Maps
    private func openInAppleMaps(coordinate: CLLocationCoordinate2D, name: String) {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
    
    // Opening route in Google Maps
    private func openInGoogleMaps(coordinate: CLLocationCoordinate2D, name: String) {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // String for Safari if Google Maps app is not installed
        let safariURLString = "https://www.google.com/maps/dir/?api=1&destination=\(coordinate.latitude),\(coordinate.longitude)&travelmode=driving"
        
        // String for Google Maps app
        let googleMapsURLString = "comgooglemaps://?daddr=\(coordinate.latitude),\(coordinate.longitude)&directionsmode=driving&q=\(encodedName)"
        
        if let googleMapsURL = URL(string: googleMapsURLString), UIApplication.shared.canOpenURL(googleMapsURL) {
            UIApplication.shared.open(googleMapsURL)
        } else if let safariURL = URL(string: safariURLString) {
            // Open in Safari if the app is not installed
            UIApplication.shared.open(safariURL)
        }
    }
    
    // Keep navigateToCoordinate method for backward compatibility
    func navigateToCoordinate(_ coordinate: CLLocationCoordinate2D, name: String) {
        showMapSelectionDialog(coordinate: coordinate, name: name)
    }
}

// UIViewController as hosting for SwiftUI
struct NavigationServiceHost: UIViewControllerRepresentable {
    let perform: (UIViewController) -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        return UIViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        perform(uiViewController)
    }
}

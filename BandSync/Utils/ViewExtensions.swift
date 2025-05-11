import SwiftUI
import MapKit

extension View {
    // Modifier for adding navigation functionality using NavigationServiceHost
    func withNavigationService(handler: @escaping (UIViewController) -> Void) -> some View {
        self.background(
            NavigationServiceHost(perform: handler)
        )
    }
    
    // Modifier for convenient navigation display
    func withDirectionsSupport(coordinate: CLLocationCoordinate2D, name: String) -> some View {
        self.onTapGesture {
            NavigationService.shared.navigateToCoordinate(coordinate, name: name)
        }
    }
    
    // Modifier for convenient address navigation display
    func withAddressDirections(address: String, name: String) -> some View {
        self.onTapGesture {
            NavigationService.shared.navigateToAddress(address, name: name)
        }
    }
}

import MapKit

// Model for annotation, compatible with MapKit SwiftUI
typealias EventMapPoint = MapPointModel

struct MapPointModel: Identifiable {
    let id: String
    let title: String
    let coordinate: CLLocationCoordinate2D
}

// Map annotation types
enum MapAnnotationType {
    case standard
    case custom
}

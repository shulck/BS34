import SwiftUI
import MapKit

struct EventMapView: View {
    let event: Event
    
    @State private var region: MKCoordinateRegion
    @State private var mapPoints: [MapPointModel] = []
    @State private var isLoading = true
    
    init(event: Event) {
        self.event = event
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 50.45, longitude: 30.52),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    }
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
                    .padding()
            } else if mapPoints.isEmpty {
                Text("No location information")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                Map(coordinateRegion: $region, annotationItems: mapPoints) { point in
                    MapAnnotation(coordinate: point.coordinate) {
                        VStack {
                            Image(systemName: getIconForEventType(event.type))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color(UIColor(hex: event.type.colorHex)))
                                .clipShape(Circle())
                            
                            Text(point.title)
                                .font(.caption)
                                .padding(4)
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(4)
                        }
                    }
                }
                .frame(height: 200)
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
        .onAppear {
            geocodeEventLocation()
        }
    }
    
    // Geocode event location address
    private func geocodeEventLocation() {
        guard let locationString = event.location, !locationString.isEmpty else {
            isLoading = false
            return
        }
        
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(locationString) { placemarks, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    print("Geocoding error: \(error.localizedDescription)")
                    return
                }
                
                guard let placemark = placemarks?.first, let location = placemark.location else {
                    return
                }
                
                // Configure map region
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
                
                // Create annotation
                let point = MapPointModel(
                    id: UUID().uuidString,
                    title: locationString.components(separatedBy: ",").first ?? locationString,
                    coordinate: location.coordinate
                )
                
                mapPoints = [point]
            }
        }
    }
    
    // Get icon based on event type
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
}

// Extension for converting hex string to UIColor
extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}

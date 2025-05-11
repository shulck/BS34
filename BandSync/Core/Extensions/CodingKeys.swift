import FirebaseFirestore
import Foundation

// Extension for Firebase data conversion
extension DocumentSnapshot {
    func decoded<T: Decodable>() throws -> T {
        guard let data = self.data() else {
            throw NSError(domain: "FirestoreError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Document data was empty"])
        }
        
        // Convert Timestamp to Date
        let processedData = data.mapValues { value -> Any in
            if let timestamp = value as? Timestamp {
                return timestamp.dateValue()
            }
            return value
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: processedData)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: jsonData)
    }
}

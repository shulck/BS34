import SwiftUI

// View for individual event row
struct EventRowView: View {
    let event: Event
    
    var body: some View {
        HStack {
            Rectangle()
                .fill(Color(hex: event.type.color))
                .frame(width: 4)
                .cornerRadius(2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                
                HStack {
                    Text(event.type.rawValue)
                        .font(.caption)
                        .padding(3)
                        .padding(.horizontal, 3)
                        .background(Color(hex: event.type.color).opacity(0.2))
                        .cornerRadius(4)
                    
                    Text(event.status.rawValue)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(formatTime(event.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 8)
        }
        .padding(.vertical, 4)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

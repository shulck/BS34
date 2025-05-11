//
//  CustomDatePicker.swift
//  BandSync
//
//  Created by Claude AI on 03.04.2025.
//

import SwiftUI

// Helper structure for marking dates in the calendar
struct CalendarDateMarker: View {
    let date: Date
    let events: [Event]
    
    var body: some View {
        // Check if there are events on this date
        if hasEventsForDate() {
            VStack {
                Spacer()
                HStack(spacing: 3) {
                    // Display up to 3 markers for different types of events
                    ForEach(uniqueEventTypes().prefix(3), id: \.self) { eventType in
                        Circle()
                            .fill(Color(hex: eventType.color))
                            .frame(width: 6, height: 6)
                    }
                    
                    // If there are more than 3 types of events, show a "+" marker
                    if uniqueEventTypes().count > 3 {
                        Text("+")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.bottom, 4)
            }
        } else {
            // Empty view if there are no events
            EmptyView()
        }
    }
    
    // Check for events on the selected date
    private func hasEventsForDate() -> Bool {
        return !eventsForDate().isEmpty
    }
    
    // Get the list of events for the given date
    private func eventsForDate() -> [Event] {
        return events.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }
    }
    
    // Get unique event types to display markers of different colors
    private func uniqueEventTypes() -> [EventType] {
        let types = eventsForDate().map { $0.type }
        return Array(Set(types))
    }
}

struct CustomDatePicker: View {
    @Binding var selectedDate: Date
    let events: [Event]
    
    // Current month and year
    @State private var currentMonth = 0
    @State private var currentYear = 0
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with month and year
            HStack {
                Button {
                    // Previous month
                    currentMonth -= 1
                    
                    if currentMonth < 0 {
                        currentMonth = 11
                        currentYear -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                }
                
                Spacer()
                
                // Display current month and year
                Text(monthYearText())
                    .font(.title2.bold())
                
                Spacer()
                
                Button {
                    // Next month
                    currentMonth += 1
                    
                    if currentMonth > 11 {
                        currentMonth = 0
                        currentYear += 1
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                }
            }
            .padding(.horizontal)
            
            // Days of the week
            HStack(spacing: 0) {
                ForEach(daysOfWeek(), id: \.self) { day in
                    Text(day)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Dates of the current month
            let columns = Array(repeating: GridItem(.flexible()), count: 7)
            
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(extractDates()) { dateValue in
                    // Date cell
                    VStack {
                        if dateValue.day != -1 {
                            // If the date belongs to the current month
                            Button {
                                selectedDate = dateValue.date
                            } label: {
                                ZStack {
                                    // Highlight the selected date
                                    if Calendar.current.isDate(dateValue.date, inSameDayAs: selectedDate) {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 35, height: 35)
                                    }
                                    
                                    // Highlight today's date
                                    if Calendar.current.isDateInToday(dateValue.date) && !Calendar.current.isDate(dateValue.date, inSameDayAs: selectedDate) {
                                        Circle()
                                            .stroke(Color.blue, lineWidth: 1.5)
                                            .frame(width: 35, height: 35)
                                    }
                                    
                                    // Day number
                                    Text("\(dateValue.day)")
                                        .font(.system(size: 16))
                                        .fontWeight(Calendar.current.isDate(dateValue.date, inSameDayAs: selectedDate) ? .bold : .regular)
                                        .foregroundColor(
                                            Calendar.current.isDate(dateValue.date, inSameDayAs: selectedDate) ? .white :
                                                (Calendar.current.isDateInToday(dateValue.date) ? .blue : .primary)
                                        )
                                }
                            }
                            
                            // Event markers below the date
                            CalendarDateMarker(date: dateValue.date, events: events)
                                .frame(height: 6)
                        }
                    }
                    .frame(height: 45)
                }
            }
            
            Spacer()
        }
        .onAppear {
            // Initialize the current month and year
            let calendar = Calendar.current
            currentMonth = calendar.component(.month, from: selectedDate) - 1 // 0-based
            currentYear = calendar.component(.year, from: selectedDate)
        }
    }
    
    // Get the name of the month and year
    private func monthYearText() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "LLLL yyyy" // Full month name and year
        
        // Create a date for the first day of the selected month
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: currentYear, month: currentMonth + 1, day: 1)) ?? Date()
        
        return dateFormatter.string(from: date)
    }
    
    // Get abbreviated names of the days of the week
    private func daysOfWeek() -> [String] {
        var days = Calendar.current.shortWeekdaySymbols
        let sunday = days.removeFirst()
        days.append(sunday)
        return days
    }

    
    // Extract dates of the current month
    private func extractDates() -> [DateValue] {
        var dateValues = [DateValue]()
        
        let calendar = Calendar.current
        
        // Get the date for the first day of the selected month
        guard let firstDayOfMonth = calendar.date(from: DateComponents(year: currentYear, month: currentMonth + 1, day: 1)) else {
            return dateValues
        }
        
        // Get the number of days in the month
        let range = calendar.range(of: .day, in: .month, for: firstDayOfMonth)!
        
        // Get the weekday of the first day of the month (0 = Sunday, 1 = Monday, etc.)
        var firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) - 1
        if firstWeekday == 0 { firstWeekday = 7 } // Move Sunday to the end
        
        // Add empty cells for the days of the previous month
        for _ in 0..<firstWeekday-1 {
            dateValues.append(DateValue(day: -1, date: Date()))
        }
        
        // Add days of the current month
        for day in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                dateValues.append(DateValue(day: day, date: date))
            }
        }
        
        return dateValues
    }
}

// Helper structure for representing a date in the calendar
struct DateValue: Identifiable {
    let id = UUID().uuidString
    let day: Int
    let date: Date
}

// Extension for converting a Hex string to Color
extension Color {
    init(hex: String) {
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
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

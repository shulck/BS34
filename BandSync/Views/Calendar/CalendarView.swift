//
//  CalendarView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 03.04.2025.
//
import SwiftUI

struct CalendarView: View {
    @StateObject private var eventService = EventService.shared
    @State private var selectedDate = Date()
    @State private var showAddEvent = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Calendar Section
                CustomDatePicker(selectedDate: $selectedDate, events: eventService.events)
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.primary.opacity(0.05), radius: 8, x: 0, y: 4)
                    .padding([.horizontal, .top])

                Divider()

                // Header for selected date
                HStack {
                    Text(formatDate(selectedDate))
                        .font(.headline)
                    Spacer()
                    Text("\(eventsForSelectedDate().count) \(eventCountLabel(eventsForSelectedDate().count))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Events List
                if eventsForSelectedDate().isEmpty {
                    Spacer()
                    Text("No events for selected date")
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.primary.opacity(0.03), radius: 5, x: 0, y: 2)
                    Spacer()
                } else {
                    List {
                        ForEach(eventsForSelectedDate(), id: \.id) { event in
                            ZStack {
                                Color.clear // To avoid background bleed
                                NavigationLink(destination: EventDetailView(event: event)) {
                                    EventRowView(event: event)
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(UIColor.systemBackground))
                                                .shadow(color: Color.primary.opacity(0.06), radius: 4, x: 0, y: 2)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .padding(.top, 8)

                }
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Calendar")
            .toolbar {
                Button(action: {
                    showAddEvent = true
                }) {
                    Label("Add", systemImage: "plus")
                        .labelStyle(IconOnlyLabelStyle())
                        .padding(8)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(10)
                        .shadow(color: Color.primary.opacity(0.05), radius: 3, x: 0, y: 2)
                }
            }
            .onAppear {
                if let groupId = AppState.shared.user?.groupId {
                    eventService.fetchEvents(for: groupId)
                }
            }
            .sheet(isPresented: $showAddEvent) {
                AddEventView()
            }
        }
    }

    private func eventsForSelectedDate() -> [Event] {
        eventService.events.filter {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
        }.sorted { $0.date < $1.date }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    private func eventCountLabel(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod10 == 1 && mod100 != 11 {
            return "event"
        } else if mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20) {
            return "events"
        } else {
            return "events"
        }
    }
}

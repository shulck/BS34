//
//  TimingDetailView.swift
//  BandSyncApp
//
//  Created by Oleksandr Kuziakin on 09.05.2025.
//


//
//  TimingDetailView.swift
//  BandSyncApp
//
//  Created by Oleksandr Kuziakin on 09.05.2025.
//


import SwiftUI

struct TimingDetailView: View {
    let setlist: Setlist
    @Environment(\.dismiss) var dismiss
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            List {
                if let concertDate = setlist.concertDate {
                    Section(header: Text("Concert Information")) {
                        HStack {
                            Text("Start Date and Time:")
                            Spacer()
                            Text(formattedDate(concertDate))
                        }
                    }
                }
                
                Section(header: Text("Song Timing")) {
                    ForEach(setlist.songs.indices, id: \.self) { index in
                        let song = setlist.songs[index]
                        VStack(alignment: .leading) {
                            Text("\(index + 1). \(song.title)")
                                .font(.headline)
                            
                            HStack {
                                Text("Duration: \(song.formattedDuration)")
                                    .font(.caption)
                                
                                Spacer()
                                
                                if let startTime = song.startTime {
                                    Text("Start: \(timeFormatter.string(from: startTime))")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Setlist Timing")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

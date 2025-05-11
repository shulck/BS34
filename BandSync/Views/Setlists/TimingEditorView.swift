//
//  TimingEditorView.swift
//  BandSyncApp
//
//  Created by Oleksandr Kuziakin on 09.05.2025.
//


//
//  TimingEditorView.swift
//  BandSyncApp
//
//  Created by Oleksandr Kuziakin on 09.05.2025.
//


import SwiftUI

struct TimingEditorView: View {
    @Binding var songs: [Song]
    @Binding var concertDate: Date
    @Binding var hasEndTime: Bool
    @Binding var concertEndDate: Date
    let onTimingsChanged: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var editingSong: Int? = nil
    @State private var newStartTime: Date = Date()
    @State private var showAlertForBreaks: Bool = false
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
    
    private var totalDuration: String {
        let seconds = songs.reduce(0) { $0 + $1.totalSeconds }
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Concert Parameters")) {
                    DatePicker("Concert Start", selection: $concertDate, displayedComponents: [.date, .hourAndMinute])
                        .onChange(of: concertDate) { _ in
                            onTimingsChanged()
                        }
                    
                    Toggle("Fix End Time", isOn: $hasEndTime)
                        .onChange(of: hasEndTime) { _ in
                            onTimingsChanged()
                        }
                    
                    if hasEndTime {
                        DatePicker("Concert End", selection: $concertEndDate, displayedComponents: [.date, .hourAndMinute])
                            .onChange(of: concertEndDate) { _ in
                                onTimingsChanged()
                            }
                    }
                    
                    if hasEndTime {
                        Button("Add Breaks") {
                            showAlertForBreaks = true
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                Section(header: Text("Setlist Timing • Duration: \(totalDuration)")) {
                    ForEach(songs.indices, id: \.self) { index in
                        VStack(alignment: .leading) {
                            HStack {
                                Text("\(index + 1). \(songs[index].title)")
                                    .font(.headline)
                                Spacer()
                                Text(songs[index].formattedDuration)
                                    .foregroundColor(.gray)
                            }
                            
                            if let startTime = songs[index].startTime {
                                HStack {
                                    if editingSong == index {
                                        DatePicker("", selection: $newStartTime, displayedComponents: [.hourAndMinute])
                                            .labelsHidden()
                                        
                                        Button("OK") {
                                            // Apply new start time
                                            var updatedSongs = songs
                                            var song = updatedSongs[index]
                                            song.startTime = newStartTime
                                            updatedSongs[index] = song
                                            songs = updatedSongs
                                            
                                            // Recalculate time for following songs
                                            recalculateTimingsFromIndex(index + 1)
                                            
                                            editingSong = nil
                                        }
                                    } else {
                                        Text("Start: \(timeFormatter.string(from: startTime))")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                        
                                        Spacer()
                                        
                                        // Button to edit start time
                                        Button("Change") {
                                            editingSong = index
                                            newStartTime = startTime
                                        }
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    }
                                    
                                    if index < songs.count - 1, let nextStartTime = songs[index + 1].startTime {
                                        Spacer()
                                        let breakInterval = nextStartTime.timeIntervalSince(Date(timeInterval: Double(songs[index].totalSeconds), since: startTime))
                                        
                                        if breakInterval > 0 {
                                            Text("Break: \(formatTimeInterval(breakInterval))")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Setlist Timing")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onTimingsChanged()
                        dismiss()
                    }
                }
            }
            .alert("Add Breaks", isPresented: $showAlertForBreaks) {
                Button("5 min between songs") { addBreaks(5) }
                Button("10 min between songs") { addBreaks(10) }
                Button("15 min between songs") { addBreaks(15) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Select the duration of breaks between songs")
            }
        }
    }
    
    // Recalculate timings starting from specified index
    private func recalculateTimingsFromIndex(_ startIndex: Int) {
        guard startIndex < songs.count else { return }
        
        var updatedSongs = songs
        var currentTime: Date
        if startIndex > 0, let previousSongStart = updatedSongs[startIndex - 1].startTime {
            // Start after previous song
            currentTime = Date(timeInterval: Double(updatedSongs[startIndex - 1].totalSeconds), since: previousSongStart)
        } else {
            // Or from the beginning of the concert, if this is the first song
            currentTime = concertDate
        }
        
        for i in startIndex..<updatedSongs.count {
            var song = updatedSongs[i]
            song.startTime = currentTime
            updatedSongs[i] = song
            
            currentTime = Date(timeInterval: Double(song.totalSeconds), since: currentTime)
        }
        
        songs = updatedSongs
    }
    
    // Add breaks between songs
    private func addBreaks(_ minutes: Int) {
        guard songs.count > 1 else { return }
        
        var updatedSongs = songs
        var currentTime = concertDate
        
        for i in 0..<updatedSongs.count {
            var song = updatedSongs[i]
            song.startTime = currentTime
            updatedSongs[i] = song
            
            // After each song (except the last one) add a break
            currentTime = Date(timeInterval: Double(song.totalSeconds), since: currentTime)
            if i < updatedSongs.count - 1 {
                currentTime = Date(timeInterval: Double(minutes * 60), since: currentTime)
            }
        }
        
        songs = updatedSongs
        
        // If total time exceeds concert time, adjust timing
        if hasEndTime && songs.count > 0 {
            let lastSong = updatedSongs.last!
            if let lastStart = lastSong.startTime {
                let currentEnd = Date(timeInterval: Double(lastSong.totalSeconds), since: lastStart)
                
                if currentEnd > concertEndDate {
                    // Adjust by removing breaks or compressing total time
                    distributeTimeBetweenSongsWithoutBreaks()
                }
            }
        }
    }
    
    // Distribute time evenly, without breaks
    private func distributeTimeBetweenSongsWithoutBreaks() {
        guard hasEndTime && !songs.isEmpty else { return }
        
        let totalSeconds = songs.reduce(0) { $0 + $1.totalSeconds }
        let availableTime = concertEndDate.timeIntervalSince(concertDate)
        
        var updatedSongs = songs
        
        // If total song duration exceeds available time,
        // proportionally compress time
        if Double(totalSeconds) > availableTime {
            let scaleFactor = availableTime / Double(totalSeconds)
            var currentTime = concertDate
            
            for i in 0..<updatedSongs.count {
                var song = updatedSongs[i]
                song.startTime = currentTime
                updatedSongs[i] = song
                
                let scaledDuration = Double(song.totalSeconds) * scaleFactor
                currentTime = Date(timeInterval: scaledDuration, since: currentTime)
            }
        } else {
            // Otherwise distribute songs evenly
            let timePerSong = availableTime / Double(updatedSongs.count)
            var currentTime = concertDate
            
            for i in 0..<updatedSongs.count {
                var song = updatedSongs[i]
                song.startTime = currentTime
                updatedSongs[i] = song
                
                currentTime = Date(timeInterval: timePerSong, since: currentTime)
            }
        }
        
        songs = updatedSongs
    }
    
    // Format time interval to min:sec
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

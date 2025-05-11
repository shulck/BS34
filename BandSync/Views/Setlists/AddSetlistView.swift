//
//  AddSetlistView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct AddSetlistView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name: String = ""
    @State private var songs: [Song] = []
    @State private var newTitle: String = ""
    @State private var minutes: String = ""
    @State private var seconds: String = ""
    @State private var bpm: String = ""
    @StateObject private var service = SetlistService.shared
    
    // Concert timing
    @State private var useTimings: Bool = false
    @State private var concertDate = Date()
    @State private var concertEndDate = Date(timeIntervalSinceNow: 7200) // Default +2 hours
    @State private var concertLengthHours: Int = 2
    @State private var concertLengthMinutes: Int = 0
    
    @State private var showImportSongs: Bool = false
    @State private var autoCreateSongs: Bool = false
    
    // State for song editing
    @State private var editingSongIndex: Int? = nil
    @State private var showEditSong = false
    
    // Sample song durations for auto-creation
    private let sampleSongDurations = [
        (3, 30), // 3 min 30 sec
        (4, 0),  // 4 min
        (3, 45), // 3 min 45 sec
        (5, 10), // 5 min 10 sec
        (3, 20), // 3 min 20 sec
        (4, 15)  // 4 min 15 sec
    ]
    
    var body: some View {
        NavigationView {
            Form {
                // Setlist information
                Section(header: Text("Setlist Information")) {
                    TextField("Setlist Name", text: $name)
                    
                    Toggle("Use Concert Timing", isOn: $useTimings)
                    
                    if useTimings {
                        DatePicker("Concert Start", selection: $concertDate, displayedComponents: [.date, .hourAndMinute])
                        
                        HStack {
                            Text("Concert Duration:")
                            Spacer()
                            Picker("", selection: $concertLengthHours) {
                                ForEach(0..<6, id: \.self) { hour in
                                    Text("\(hour) h").tag(hour)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 70)
                            
                            Picker("", selection: $concertLengthMinutes) {
                                ForEach(0..<60, id: \.self) { minute in
                                    if minute % 5 == 0 {
                                        Text("\(minute) min").tag(minute)
                                    }
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 90)
                        }
                        
                        Button("Auto-create songs for concert") {
                            autoCreateSongsForConcert()
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                // Section with auto-created songs
                if useTimings && autoCreateSongs && songs.count > 0 {
                    Section(header: Text("Auto-created songs")) {
                        HStack {
                            Text("Total songs:")
                            Spacer()
                            Text("\(songs.count)")
                                .bold()
                        }
                        
                        HStack {
                            Text("Total Duration:")
                            Spacer()
                            Text(formattedTotalDuration)
                                .bold()
                        }
                        
                        Button("Clear and recreate") {
                            songs = []
                            autoCreateSongsForConcert()
                        }
                        .foregroundColor(.red)
                    }
                }

                // Manual song addition section
                Section(header: Text("Add Song Manually")) {
                    TextField("Name", text: $newTitle)
                    HStack {
                        TextField("Min", text: $minutes)
                            .keyboardType(.numberPad)
                        Text(":")
                        TextField("Sec", text: $seconds)
                            .keyboardType(.numberPad)
                    }
                    TextField("BPM", text: $bpm)
                        .keyboardType(.numberPad)

                    Button("Add") {
                        addSongManually()
                    }
                    
                    Button("Import Songs") {
                        showImportSongs = true
                    }
                }

                // List of added songs
                if songs.count > 0 {
                    Section(header: Text("Songs in Setlist")) {
                        ForEach(songs.indices, id: \.self) { index in
                            let song = songs[index]
                            Button(action: {
                                editingSongIndex = index
                                showEditSong = true
                            }) {
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text(song.title)
                                        Spacer()
                                        Text(song.formattedDuration)
                                        Image(systemName: "pencil")
                                            .foregroundColor(.blue)
                                            .font(.caption)
                                    }
                                    
                                    if useTimings, let startTime = song.startTime {
                                        Text("Start: \(timeFormatter.string(from: startTime))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .onDelete { indexSet in
                            songs.remove(atOffsets: indexSet)
                            recalculateTimings()
                        }
                    }

                    // Summary section
                    Section {
                        HStack {
                            Text("Total Duration")
                            Spacer()
                            Text(formattedTotalDuration)
                                .bold()
                        }
                    }
                }
            }
            .navigationTitle("Create Setlist")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSetlist()
                    }
                    .disabled(name.isEmpty || songs.isEmpty)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showImportSongs) {
                ImportSongsView(selectedSongs: $songs, useTimings: useTimings) {
                    recalculateTimings()
                }
            }
            .sheet(isPresented: $showEditSong, onDismiss: {
                // Reset index and recalculate timings
                editingSongIndex = nil
                recalculateTimings()
            }) {
                if let index = editingSongIndex, index < songs.count {
                    EditSongView(song: Binding(
                        get: { songs[index] },
                        set: { songs[index] = $0 }
                    ))
                }
            }
            .onChange(of: concertLengthHours) { _ in updateConcertEndDate() }
            .onChange(of: concertLengthMinutes) { _ in updateConcertEndDate() }
            .onChange(of: concertDate) { _ in updateConcertEndDate() }
            .onAppear {
                if let groupId = AppState.shared.user?.groupId {
                    service.fetchSetlists(for: groupId)
                }
            }
        }
    }
    
    // Time formatter
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
    
    // Formatted total duration
    private var formattedTotalDuration: String {
        let total = songs.reduce(0) { $0 + $1.totalSeconds }
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // Update concert end date
    private func updateConcertEndDate() {
        let totalMinutes = concertLengthHours * 60 + concertLengthMinutes
        concertEndDate = Calendar.current.date(byAdding: .minute, value: totalMinutes, to: concertDate) ?? concertDate
    }
    
    // Automatically create songs for concert
    private func autoCreateSongsForConcert() {
        songs = []
        autoCreateSongs = true
        
        // Collect existing songs from current setlists
        var existingSongs: [Song] = []
        for setlist in service.setlists {
            for song in setlist.songs {
                if !existingSongs.contains(where: { $0.title == song.title }) {
                    existingSongs.append(song)
                }
            }
        }
        
        // Total concert duration in seconds
        let totalConcertSeconds = concertLengthHours * 3600 + concertLengthMinutes * 60
        
        // Break duration (15% of total time)
        let breakDurationSeconds = Int(Double(totalConcertSeconds) * 0.15)
        
        // Remaining time for songs
        let availableSongTimeSeconds = totalConcertSeconds - breakDurationSeconds
        
        var currentTotalDuration = 0
        
        // If no existing songs, use templates
        if existingSongs.isEmpty {
            var songCounter = 1
            
            while currentTotalDuration < availableSongTimeSeconds {
                // Randomly select a duration from examples
                let randomIndex = Int.random(in: 0..<sampleSongDurations.count)
                let (min, sec) = sampleSongDurations[randomIndex]
                let songDuration = min * 60 + sec
                
                // If adding this song exceeds available time, exit
                if currentTotalDuration + songDuration > availableSongTimeSeconds {
                    break
                }
                
                // Create song with random BPM
                let randomBPM = Int.random(in: 90...160)
                let song = Song(
                    title: "Song \(songCounter)",
                    durationMinutes: min,
                    durationSeconds: sec,
                    bpm: randomBPM
                )
                
                songs.append(song)
                currentTotalDuration += songDuration
                songCounter += 1
            }
        } else {
            // Use existing songs
            let shuffledSongs = existingSongs.shuffled()
            var index = 0
            
            while currentTotalDuration < availableSongTimeSeconds && index < shuffledSongs.count {
                let song = shuffledSongs[index]
                
                // If adding this song exceeds available time, try the next one
                if currentTotalDuration + song.totalSeconds > availableSongTimeSeconds && index < shuffledSongs.count - 1 {
                    index += 1
                    continue
                }
                
                // Clone song with new ID
                var newSong = song
                newSong.id = UUID().uuidString
                newSong.startTime = nil
                
                songs.append(newSong)
                currentTotalDuration += newSong.totalSeconds
                index += 1
                
                // If we've gone through all songs but still haven't filled the time, start over
                if index >= shuffledSongs.count && currentTotalDuration < availableSongTimeSeconds {
                    index = 0
                }
            }
        }
        
        // Recalculate timings for all songs
        recalculateTimings()
    }
    
    // Add song manually
    private func addSongManually() {
        guard let min = Int(minutes), let sec = Int(seconds), let bpmVal = Int(bpm), !newTitle.isEmpty else { return }
        
        let song = Song(
            title: newTitle,
            durationMinutes: min,
            durationSeconds: sec,
            bpm: bpmVal
        )
        
        songs.append(song)
        newTitle = ""
        minutes = ""
        seconds = ""
        bpm = ""
        
        recalculateTimings()
    }
    
    // Recalculate timings for all songs
    private func recalculateTimings() {
        if !songs.isEmpty && useTimings {
            // Create a full copy of the array
            var updatedSongs = songs
            var currentTime = concertDate
            
            // Update timings for all songs
            for i in 0..<updatedSongs.count {
                updatedSongs[i].startTime = currentTime
                currentTime = Date(timeInterval: Double(updatedSongs[i].totalSeconds), since: currentTime)
            }
            
            // Assign the updated array
            songs = updatedSongs
        }
    }
    
    // Save setlist
    private func saveSetlist() {
        guard let uid = AppState.shared.user?.id,
              let groupId = AppState.shared.user?.groupId,
              !name.isEmpty, !songs.isEmpty
        else { return }
        
        if useTimings {
            recalculateTimings()
        }

        let setlist = Setlist(
            name: name,
            userId: uid,
            groupId: groupId,
            isShared: true,
            songs: songs,
            concertDate: useTimings ? concertDate : nil
        )

        SetlistService.shared.addSetlist(setlist) { success in
            if success {
                dismiss()
            }
        }
    }
}


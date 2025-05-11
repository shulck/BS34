//
//  ImportSongsView.swift
//  BandSyncApp
//
//  Created by Oleksandr Kuziakin on 09.05.2025.
//


//
//  ImportSongsView.swift
//  BandSyncApp
//
//  Created by Oleksandr Kuziakin on 09.05.2025.
//


import SwiftUI

struct ImportSongsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var service = SetlistService.shared
    @Binding var selectedSongs: [Song]
    let useTimings: Bool
    let onImport: () -> Void
    
    @State private var selectedSetlist: Setlist?
    @State private var selectedIndices: [Int] = []
    
    var body: some View {
        NavigationView {
            VStack {
                if service.setlists.isEmpty {
                    VStack {
                        Spacer()
                        Text("No available setlists")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                } else {
                    Form {
                        Section(header: Text("Select a setlist")) {
                            Picker("Setlist", selection: $selectedSetlist) {
                                Text("Select").tag(nil as Setlist?)
                                ForEach(service.setlists) { setlist in
                                    Text(setlist.name).tag(setlist as Setlist?)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .onChange(of: selectedSetlist) { newValue in
                                selectedIndices = []
                            }
                        }
                        
                        if let setlist = selectedSetlist {
                            Section(header: Text("Songs")) {
                                ForEach(setlist.songs.indices, id: \.self) { index in
                                    let song = setlist.songs[index]
                                    Button(action: {
                                        toggleSongSelection(index)
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(song.title)
                                                Text("\(song.formattedDuration) • \(song.bpm) BPM")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                            
                                            Spacer()
                                            
                                            if selectedIndices.contains(index) {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                    .foregroundColor(.primary)
                                }
                            }
                            
                            Section {
                                Button("Select all") {
                                    if selectedIndices.count == setlist.songs.count {
                                        selectedIndices = []
                                    } else {
                                        selectedIndices = Array(0..<setlist.songs.count)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Import Songs")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        importSelectedSongs()
                    }
                    .disabled(selectedIndices.isEmpty)
                }
            }
            .onAppear {
                if service.setlists.isEmpty {
                    if let groupId = AppState.shared.user?.groupId {
                        service.fetchSetlists(for: groupId)
                    }
                }
            }
        }
    }
    
    // Toggle song selection
    private func toggleSongSelection(_ index: Int) {
        if let position = selectedIndices.firstIndex(of: index) {
            selectedIndices.remove(at: position)
        } else {
            selectedIndices.append(index)
        }
    }
    
    // Import selected songs
    private func importSelectedSongs() {
        guard let setlist = selectedSetlist else { return }
        
        // Create copies of selected songs
        let songsToAdd = selectedIndices.sorted().map { index -> Song in
            var song = setlist.songs[index]
            // Create a new ID for the song to make it unique
            song.id = UUID().uuidString
            // Reset start time so it can be recalculated
            song.startTime = nil
            return song
        }
        
        // Add songs to selected setlist
        selectedSongs.append(contentsOf: songsToAdd)
        
        // Call import handler to recalculate timings
        onImport()
        
        // Close window
        dismiss()
    }
}

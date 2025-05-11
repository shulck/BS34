//
//  SetlistDetailView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 31.03.2025.
//

import SwiftUI

struct SetlistDetailView: View {
    @StateObject private var viewModel: SetlistDetailViewModel
    @Environment(\.dismiss) var dismiss
    
    init(setlist: Setlist) {
        _viewModel = StateObject(wrappedValue: SetlistDetailViewModel(setlist: setlist))
    }
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
    
    var body: some View {
        VStack {
            headerView
            
            Divider()
            
            songListView
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .navigationTitle(viewModel.isEditing ? "Edit" : "Setlist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .padding()
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(8)
                    .shadow(radius: 3)
            }
        }
        .alert("Delete setlist?", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deleteSetlist {
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to delete this setlist? This action cannot be undone.")
        }
        .sheet(isPresented: $viewModel.showAddSong) {
            AddSongView(setlist: $viewModel.setlist, onSave: {
                viewModel.updateSetlist()
            })
        }
        .sheet(isPresented: $viewModel.showExportView) {
            SetlistExportView(setlist: viewModel.setlist)
        }
        .sheet(isPresented: $viewModel.showTimingView) {
            TimingDetailView(setlist: viewModel.setlist)
        }
        .sheet(isPresented: $viewModel.showEditSong, onDismiss: {
            viewModel.updateSetlist()
            viewModel.editingSongIndex = nil
        }) {
            if let index = viewModel.editingSongIndex, index < viewModel.setlist.songs.count {
                EditSongView(song: Binding(
                    get: { viewModel.setlist.songs[index] },
                    set: { newValue in
                        var updatedSongs = viewModel.setlist.songs
                        updatedSongs[index] = newValue
                        viewModel.setlist.songs = updatedSongs
                    }
                ))
            }
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isEditing {
                TextField("Setlist Name", text: $viewModel.editName)
                    .font(.title2.bold())
                    .padding(.horizontal)
            } else {
                Text(viewModel.setlist.name)
                    .font(.title2.bold())
                    .padding(.horizontal)
            }
            
            HStack {
                Text("\(viewModel.setlist.songs.count) songs")
                Spacer()
                Text("Total Duration: \(viewModel.setlist.formattedTotalDuration)")
                    .bold()
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.horizontal)
        }
        .padding(.top)
    }
    
    private var songListView: some View {
        List {
            ForEach(viewModel.setlist.songs.indices, id: \.self) { index in
                let song = viewModel.setlist.songs[index]
                Button(action: {
                    if viewModel.isEditing {
                        viewModel.editingSongIndex = index
                        viewModel.showEditSong = true
                    }
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(song.title)
                                .font(.headline)
                            
                            HStack {
                                Text("BPM: \(song.bpm)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                if let startTime = song.startTime {
                                    Spacer()
                                    Text(timeFormatter.string(from: startTime))
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        Spacer()
                        Text(song.formattedDuration)
                            .monospacedDigit()
                        
                        if viewModel.isEditing {
                            Image(systemName: "pencil")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                    }
                }
                .disabled(!viewModel.isEditing)
            }
            .onDelete(perform: viewModel.isEditing ? viewModel.deleteSong : nil)
            .onMove(perform: viewModel.isEditing ? viewModel.moveSong : nil)
            
            if viewModel.setlist.songs.isEmpty {
                Text("Setlist is empty")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
            
            if viewModel.setlist.concertDate != nil && !viewModel.setlist.songs.isEmpty {
                Section {
                    Button {
                        viewModel.showTimingView = true
                    } label: {
                        Label("View Timing", systemImage: "clock")
                    }
                }
            }
            
            // Add bottom padding only when in edit mode
            if viewModel.isEditing {
                Spacer()
                    .frame(height: 60)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(PlainListStyle())
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                if AppState.shared.hasEditPermission(for: .setlists) {
                    if viewModel.isEditing {
                        Button {
                            viewModel.saveChanges()
                        } label: {
                            Label("Save", systemImage: "checkmark")
                        }
                        
                        Button {
                            viewModel.showAddSong = true
                        } label: {
                            Label("Add Song", systemImage: "music.note.plus")
                        }
                    } else {
                        Button {
                            viewModel.startEditing()
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            viewModel.showDeleteConfirmation = true
                        } label: {
                            Label("Delete Setlist", systemImage: "trash")
                        }
                    }
                }
                
                Button {
                    viewModel.showExportView = true
                } label: {
                    Label("Export to PDF", systemImage: "arrow.up.doc")
                }
            } label: {
                Label("Menu", systemImage: "ellipsis.circle")
            }
        }
        
        if viewModel.isEditing {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    viewModel.cancelEditing()
                }
            }
            
            ToolbarItem(placement: .bottomBar) {
                EditButton()
            }
        }
    }
}

// View for adding a song
struct AddSongView: View {
    @Binding var setlist: Setlist
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var title = ""
    @State private var minutes = ""
    @State private var seconds = ""
    @State private var bpm = ""
    @State private var key = "" // Added key field
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Song Information")) {
                    TextField("Name", text: $title)
                    
                    HStack {
                        Text("Duration:")
                        TextField("Min", text: $minutes)
                            .keyboardType(.numberPad)
                            .frame(width: 40)
                        Text(":")
                        TextField("Sec", text: $seconds)
                            .keyboardType(.numberPad)
                            .frame(width: 40)
                    }
                    
                    TextField("BPM", text: $bpm)
                        .keyboardType(.numberPad)
                        
                    TextField("Key", text: $key) // New field
                }
            }
            .navigationTitle("Add Song")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addSong()
                    }
                    .disabled(title.isEmpty || (minutes.isEmpty && seconds.isEmpty) || bpm.isEmpty)
                }
            }
        }
    }
    
    private func addSong() {
        guard !title.isEmpty else { return }
        
        let min = Int(minutes) ?? 0
        let sec = Int(seconds) ?? 0
        let bpmValue = Int(bpm) ?? 120
        
        // Check data validity
        if min == 0 && sec == 0 {
            return
        }
        
        // Create new song
        let newSong = Song(
            title: title,
            durationMinutes: min,
            durationSeconds: sec,
            bpm: bpmValue,
            key: key.isEmpty ? nil : key // Add key
        )
        
        // Add song to setlist
        var updatedSetlist = setlist
        updatedSetlist.songs.append(newSong)
        setlist = updatedSetlist
        
        // Call save handler
        onSave()
        
        // Close modal
        dismiss()
    }
}

// ViewModel for SetlistDetailView
class SetlistDetailViewModel: ObservableObject {
    @Published var setlist: Setlist
    @Published var isEditing = false
    @Published var showAddSong = false
    @Published var showDeleteConfirmation = false
    @Published var showExportView = false
    @Published var showTimingView = false
    @Published var editingSongIndex: Int? = nil
    @Published var showEditSong = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var editName = ""
    
    init(setlist: Setlist) {
        self.setlist = setlist
    }
    
    // Start editing
    func startEditing() {
        editName = setlist.name
        isEditing = true
    }
    
    // Cancel editing
    func cancelEditing() {
        editName = ""
        isEditing = false
    }
    
    // Save changes
    func saveChanges() {
        // Update setlist name
        if !editName.isEmpty && editName != setlist.name {
            setlist.name = editName
        }
        
        updateSetlist()
        isEditing = false
    }
    
    // Delete song
    func deleteSong(at offsets: IndexSet) {
        var updatedSongs = setlist.songs
        updatedSongs.remove(atOffsets: offsets)
        setlist.songs = updatedSongs
    }
    
    // Move song
    func moveSong(from source: IndexSet, to destination: Int) {
        var updatedSongs = setlist.songs
        updatedSongs.move(fromOffsets: source, toOffset: destination)
        setlist.songs = updatedSongs
    }
    
    // Update setlist in database
    func updateSetlist() {
        isLoading = true
        errorMessage = nil
        
        print("Updating setlist in database. Number of songs: \(setlist.songs.count)")
        for (i, song) in setlist.songs.enumerated() {
            print("Song \(i+1): \(song.title), Duration: \(song.durationMinutes):\(song.durationSeconds)")
        }
        
        // Send to Firebase
        SetlistService.shared.updateSetlist(setlist) { [weak self] success in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if !success {
                    self?.errorMessage = "Failed to save changes"
                }
            }
        }
    }
    
    // Delete setlist
    func deleteSetlist(completion: @escaping () -> Void) {
        SetlistService.shared.deleteSetlist(setlist)
        completion()
    }
}


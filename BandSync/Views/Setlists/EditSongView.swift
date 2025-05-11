import SwiftUI

struct EditSongView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var song: Song
    
    // Local state for editing
    @State private var editedTitle: String
    @State private var editedDurationMinutes: Int
    @State private var editedDurationSeconds: Int
    @State private var editedBpm: Int
    @State private var editedKey: String
    
    // Initialize with copied values to prevent direct binding issues
    init(song: Binding<Song>) {
        self._song = song
        
        // Initialize local state variables with the current song values
        self._editedTitle = State(initialValue: song.wrappedValue.title)
        self._editedDurationMinutes = State(initialValue: song.wrappedValue.durationMinutes)
        self._editedDurationSeconds = State(initialValue: song.wrappedValue.durationSeconds)
        self._editedBpm = State(initialValue: song.wrappedValue.bpm)
        self._editedKey = State(initialValue: song.wrappedValue.key ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Song Information")) {
                    TextField("Name", text: $editedTitle)
                    
                    HStack {
                        Text("Duration:")
                        TextField("Min", value: $editedDurationMinutes, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                            .frame(width: 40)
                        Text(":")
                        TextField("Sec", value: $editedDurationSeconds, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                            .frame(width: 40)
                        Button("Done") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                           to: nil,
                                                           from: nil,
                                                           for: nil)
                        }
                        .font(.caption)
                        .padding(.leading, 8)
                    }
                    
                    TextField("BPM", value: $editedBpm, formatter: NumberFormatter())
                        .keyboardType(.numberPad)
                    
                    TextField("Key", text: $editedKey)
                        // Removed autocapitalization modifier
                }
                
                Section {
                    Button("Check changes") {
                        print("Current duration: \(editedDurationMinutes):\(editedDurationSeconds), BPM: \(editedBpm), Key: \(editedKey)")
                    }
                    .foregroundColor(.blue)
                }
                
                // Keep debug section but make it less intrusive
                Section(header: Text("Debug Info")) {
                    HStack {
                        Text("Original key:")
                            .font(.caption)
                        Spacer()
                        Text(song.key ?? "nil")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Edit Song")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSong()
                    }
                    .disabled(editedTitle.isEmpty || (editedDurationMinutes == 0 && editedDurationSeconds == 0))
                }
            }
        }
    }
    
    private func saveSong() {
        // Validate data
        if editedTitle.isEmpty || (editedDurationMinutes == 0 && editedDurationSeconds == 0) {
            return
        }
        
        // Log debug info before saving
        print("Saving song with key: \(editedKey.isEmpty ? "nil" : "'\(editedKey)'")")
        
        // Update the song with edited values
        var updatedSong = song
        updatedSong.title = editedTitle
        updatedSong.durationMinutes = editedDurationMinutes
        updatedSong.durationSeconds = editedDurationSeconds
        updatedSong.bpm = editedBpm
        updatedSong.key = editedKey.isEmpty ? nil : editedKey
        
        // Update the binding
        song = updatedSong
        
        // Close modal
        dismiss()
    }
}

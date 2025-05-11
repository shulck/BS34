//
//  SetlistExportView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI
import PDFKit

struct SetlistExportView: View {
    // Store a copy of the setlist to prevent reference issues
    @State private var localSetlist: Setlist
    @State private var pdfData: Data?
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) var dismiss
    
    // Export parameters
    @State private var showBPM = true
    @State private var showKey = false
    
    // Initialize with a copy of the original setlist
    init(setlist: Setlist) {
        _localSetlist = State(initialValue: setlist)
    }
    
    var body: some View {
        VStack {
            if let pdfData = pdfData, let pdfDocument = PDFDocument(data: pdfData) {
                PDFPreviewView(document: pdfDocument)
                    .padding()
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "doc.text")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.gray)
                    
                    Text("PDF Preview")
                        .font(.title2)
                    
                    Text("Setlist: \(localSetlist.name)")
                        .font(.headline)
                    
                    Text("\(localSetlist.songs.count) songs • \(localSetlist.formattedTotalDuration)")
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            // Export settings
            Form {
                Section(header: Text("Export Parameters")) {
                    Toggle("Show BPM", isOn: $showBPM)
                        .onChange(of: showBPM) { _ in
                            print("BPM toggle changed to: \(showBPM)")
                            generatePDF()
                        }
                    
                    Toggle("Show Key", isOn: $showKey)
                        .onChange(of: showKey) { _ in
                            print("Key toggle changed to: \(showKey)")
                            generatePDF()
                        }
                }
            }
            .frame(height: 180)
            
            // Debug Section for troubleshooting
            VStack(alignment: .leading, spacing: 4) {
                Text("Debug Info:")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text("Keys in songs: \(keysInfo)")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text("showKey state: \(showKey ? "Enabled" : "Disabled")")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 16) {
                Button {
                    generatePDF()
                } label: {
                    Label("Update PDF", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button {
                    showShareSheet = true
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(pdfData == nil ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(pdfData == nil)
            }
            .padding()
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .navigationTitle("Export Setlist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
        .overlay(Group {
            if isExporting {
                VStack {
                    ProgressView()
                    Text("Creating PDF...")
                }
                .padding()
                .background(Color.white.opacity(0.9))
                .cornerRadius(10)
                .shadow(radius: 5)
            }
        })
        .onAppear {
            // Check if keys exist on songs and log them
            printKeyDebugInfo()
            generatePDF()
        }
        .sheet(isPresented: $showShareSheet) {
            if let pdfData = pdfData {
                ShareSheet(items: [pdfData])
            }
        }
    }
    
    // Computed property to show key information for debugging
    private var keysInfo: String {
        let keysPresent = localSetlist.songs.filter { $0.key != nil && !($0.key?.isEmpty ?? true) }.count
        return "\(keysPresent)/\(localSetlist.songs.count)"
    }
    
    // Debug function to print key information
    private func printKeyDebugInfo() {
        print("===== KEY DEBUG INFO =====")
        print("Total songs: \(localSetlist.songs.count)")
        for (i, song) in localSetlist.songs.enumerated() {
            let keyStatus = song.key != nil ? (song.key!.isEmpty ? "empty string" : "'\(song.key!)'") : "nil"
            print("Song \(i+1): \(song.title) - Key: \(keyStatus)")
        }
    }
    
    // Generate PDF
    private func generatePDF() {
        isExporting = true
        errorMessage = nil
        
        // Print debug info before PDF generation
        print("=== EXPORT VIEW DEBUG ===")
        print("Toggle state before PDF generation - Show BPM: \(showBPM), Show Key: \(showKey)")
        printKeyDebugInfo()
        
        DispatchQueue.global(qos: .userInitiated).async {
            let options = SetlistPDFExporter.ExportOptions(
                showBPM: self.showBPM,
                showKey: self.showKey
            )
            
            // Confirm options are set correctly
            print("Export options passed to exporter - Show BPM: \(options.showBPM), Show Key: \(options.showKey)")
            
            let generatedPDF = SetlistPDFExporter.export(setlist: self.localSetlist, options: options)
            
            DispatchQueue.main.async {
                self.isExporting = false
                
                if let pdf = generatedPDF {
                    self.pdfData = pdf
                    print("PDF created successfully with \(self.localSetlist.songs.count) songs")
                } else {
                    self.errorMessage = "Failed to create PDF. Please try again."
                    print("Failed to create PDF")
                }
            }
        }
    }
}

// PDF Preview View
struct PDFPreviewView: UIViewRepresentable {
    let document: PDFDocument
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}

// Share Sheet View
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

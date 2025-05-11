//
//  SetlistPDFExporter.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import PDFKit
import UIKit

final class SetlistPDFExporter {
    struct ExportOptions {
        var showBPM: Bool = true
        var showKey: Bool = false
    }
    
    // Maximum songs per page - keeping 24 with optimized layout
    private static let maxSongsPerPage = 24
    
    static func export(setlist: Setlist, options: ExportOptions = ExportOptions()) -> Data? {
        // Create a new PDF document
        let pdf = PDFDocument()
        
        // Standard A4 page size (595 x 842 points)
        let pageBounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        
        // Calculate how many pages we need
        let totalSongs = setlist.songs.count
        let songsPerPage = min(totalSongs, maxSongsPerPage)
        let totalPages = Int(ceil(Double(totalSongs) / Double(songsPerPage)))
        
        // Print detailed debug information
        print("==== PDF EXPORT DEBUG INFO ====")
        print("Export options - Show BPM: \(options.showBPM), Show Key: \(options.showKey)")
        print("PDF Export - Total songs: \(totalSongs), Per page: \(songsPerPage), Pages: \(totalPages)")
        
        for pageIndex in 0..<totalPages {
            // Calculate start and end index for songs on this page
            let startIndex = pageIndex * songsPerPage
            let endIndex = min(startIndex + songsPerPage, totalSongs)
            let songsForPage = Array(setlist.songs[startIndex..<endIndex])
            
            // Create page
            if let page = createPDFPage(
                pageBounds: pageBounds,
                setlist: setlist,
                songs: songsForPage,
                options: options,
                pageNumber: pageIndex + 1,
                totalPages: totalPages,
                startNumber: startIndex + 1
            ) {
                pdf.insert(page, at: pageIndex)
            }
        }
        
        return pdf.dataRepresentation()
    }
    
    private static func createPDFPage(
        pageBounds: CGRect,
        setlist: Setlist,
        songs: [Song],
        options: ExportOptions,
        pageNumber: Int,
        totalPages: Int,
        startNumber: Int
    ) -> PDFPage? {
        let renderer = UIGraphicsImageRenderer(bounds: pageBounds)
        let image = renderer.image { context in
            // Fill background
            UIColor.white.setFill()
            context.fill(pageBounds)
            
            // Set margins for better readability when on the floor
            let topMargin: CGFloat = 20 // Reduced top margin
            let bottomMargin: CGFloat = 30 // Reduced bottom margin since no page number
            
            // Draw title (only on first page)
            var yPosition: CGFloat = topMargin
            
            // Use dark gray color for title and numbers
            let grayColor = UIColor.darkGray
            
            if pageNumber == 1 {
                // Smaller font for title (12 points) in gray color
                let titleFont = UIFont.boldSystemFont(ofSize: 12)
                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: titleFont,
                    .foregroundColor: grayColor
                ]
                
                let titleString = setlist.name
                let titleSize = titleString.size(withAttributes: titleAttributes)
                let titleRect = CGRect(
                    x: (pageBounds.width - titleSize.width) / 2,
                    y: yPosition,
                    width: titleSize.width,
                    height: titleSize.height
                )
                
                titleString.draw(in: titleRect, withAttributes: titleAttributes)
                yPosition = titleRect.maxY + 5 // Smaller space after title
                
                // Draw horizontal line below title
                let lineWidth: CGFloat = pageBounds.width * 0.7 // 70% of page width
                let lineHeight: CGFloat = 1.0
                let lineRect = CGRect(
                    x: (pageBounds.width - lineWidth) / 2,
                    y: yPosition,
                    width: lineWidth,
                    height: lineHeight
                )
                
                context.cgContext.setStrokeColor(grayColor.cgColor)
                context.cgContext.setLineWidth(lineHeight)
                context.cgContext.stroke(lineRect)
                
                yPosition += 10 // Space after the line
            } else {
                // For subsequent pages, add a small header
                let headerFont = UIFont.boldSystemFont(ofSize: 12)
                let headerAttributes: [NSAttributedString.Key: Any] = [
                    .font: headerFont,
                    .foregroundColor: grayColor
                ]
                
                // Modified header without explicit page numbers
                let headerString = setlist.name
                let headerSize = headerString.size(withAttributes: headerAttributes)
                let headerRect = CGRect(
                    x: (pageBounds.width - headerSize.width) / 2,
                    y: yPosition,
                    width: headerSize.width,
                    height: headerSize.height
                )
                
                headerString.draw(in: headerRect, withAttributes: headerAttributes)
                yPosition = headerRect.maxY + 5
                
                // Draw horizontal line below header
                let lineWidth: CGFloat = pageBounds.width * 0.7 // 70% of page width
                let lineHeight: CGFloat = 1.0
                let lineRect = CGRect(
                    x: (pageBounds.width - lineWidth) / 2,
                    y: yPosition,
                    width: lineWidth,
                    height: lineHeight
                )
                
                context.cgContext.setStrokeColor(grayColor.cgColor)
                context.cgContext.setLineWidth(lineHeight)
                context.cgContext.stroke(lineRect)
                
                yPosition += 10 // Space after the line
            }
            
            // Calculate font sizes
            let songFontSize: CGFloat = 24 // Large bold font for song titles
            let numberFontSize: CGFloat = 14 // Smaller regular font for numbers
            let smallLabelFontSize: CGFloat = 12 // Smaller font for labels like "bpm"
            
            // Create fonts
            let songFont = UIFont.boldSystemFont(ofSize: songFontSize)
            let numberFont = UIFont.systemFont(ofSize: numberFontSize) // Regular (not bold) font for numbers
            let smallLabelFont = UIFont.systemFont(ofSize: smallLabelFontSize) // Small font for labels
            
            // Create attributes with same colors as song titles but smaller font
            let blackColor = UIColor.black
            
            // Calculate available space for songs
            let availableHeight = pageBounds.height - yPosition - bottomMargin
            
            // Calculate number of songs and optimal spacing to fill the page
            let songCount = songs.count
            let baseSongHeight = songFont.lineHeight
            
            // Calculate spacing between songs to evenly distribute across available height
            let totalBaseHeight = baseSongHeight * CGFloat(songCount)
            let remainingSpace = availableHeight - totalBaseHeight
            
            // Calculate even spacing between songs
            let spacingBetweenSongs = remainingSpace / CGFloat(max(1, songCount - 1))
            
            // Ensure minimum spacing
            let actualSpacing = max(5.0, spacingBetweenSongs)
            
            // Create attributes for different text styles
            let songAttributes: [NSAttributedString.Key: Any] = [
                .font: songFont,
                .foregroundColor: blackColor
            ]
            
            let numberAttributes: [NSAttributedString.Key: Any] = [
                .font: numberFont,
                .foregroundColor: grayColor
            ]
            
            let smallLabelAttributes: [NSAttributedString.Key: Any] = [
                .font: smallLabelFont,
                .foregroundColor: blackColor // Same color as song title (black)
            ]
            
            // Draw song list in a single column, centered, with equal spacing
            for (index, song) in songs.enumerated() {
                let songNumber = startNumber + index
                
                // Current Y position for this song
                let currentY = yPosition + (baseSongHeight + actualSpacing) * CGFloat(index)
                
                // Draw song number with smaller, regular font
                let numberText = "\(songNumber)."
                let numberSize = numberText.size(withAttributes: numberAttributes)
                
                // Create song title for the bold part
                let songTitle = song.title
                
                // Calculate sizes
                let songTitleSize = songTitle.size(withAttributes: songAttributes)
                
                // BPM value and label parts with different styling
                let bpmValue = "\(song.bpm)"
                let bpmLabel = " bpm" // Lowercase "bpm"
                
                let bpmValueSize = bpmValue.size(withAttributes: songAttributes)
                let bpmLabelSize = bpmLabel.size(withAttributes: smallLabelAttributes)
                
                // Key information (if enabled)
                var keyText = ""
                var keySize = CGSize.zero
                
                if options.showKey {
                    if let key = song.key, !key.isEmpty {
                        keyText = "\(key)"
                    } else {
                        keyText = "-"
                    }
                    keySize = keyText.size(withAttributes: songAttributes)
                }
                
                // Calculate total width with all components
                let spacing = 5.0 // Spacing between elements
                let separator = " - "
                let separatorSize = separator.size(withAttributes: songAttributes)
                
                var totalWidth = numberSize.width + spacing + songTitleSize.width
                
                // Add BPM components if enabled
                if options.showBPM {
                    totalWidth += spacing + separatorSize.width + bpmValueSize.width + bpmLabelSize.width
                }
                
                // Add key if enabled
                if options.showKey && !keyText.isEmpty {
                    totalWidth += spacing + keySize.width
                    
                    // Add separator if BPM is not shown but key is
                    if !options.showBPM {
                        totalWidth += separatorSize.width
                    }
                }
                
                // Calculate starting X position to center the combined text
                let startX = (pageBounds.width - totalWidth) / 2
                
                // Draw components:
                var currentX = startX
                
                // 1. Draw number
                let numberRect = CGRect(
                    x: currentX,
                    y: currentY + (baseSongHeight - numberSize.height) / 2, // Vertically center with song
                    width: numberSize.width,
                    height: numberSize.height
                )
                numberText.draw(in: numberRect, withAttributes: numberAttributes)
                currentX += numberSize.width + spacing
                
                // 2. Draw song title
                let songRect = CGRect(
                    x: currentX,
                    y: currentY,
                    width: songTitleSize.width,
                    height: baseSongHeight
                )
                songTitle.draw(in: songRect, withAttributes: songAttributes)
                currentX += songTitleSize.width
                
                // 3. Add separator and BPM if enabled
                if options.showBPM || (options.showKey && !keyText.isEmpty) {
                    // Draw separator
                    let separatorRect = CGRect(
                        x: currentX,
                        y: currentY,
                        width: separatorSize.width,
                        height: baseSongHeight
                    )
                    separator.draw(in: separatorRect, withAttributes: songAttributes)
                    currentX += separatorSize.width
                    
                    // If BPM is enabled, draw BPM value (bold) and "bpm" (small)
                    if options.showBPM {
                        // Draw BPM value (large, same as song title)
                        let bpmValueRect = CGRect(
                            x: currentX,
                            y: currentY,
                            width: bpmValueSize.width,
                            height: baseSongHeight
                        )
                        bpmValue.draw(in: bpmValueRect, withAttributes: songAttributes)
                        currentX += bpmValueSize.width
                        
                        // Draw "bpm" label (small, black)
                        let bpmLabelRect = CGRect(
                            x: currentX,
                            y: currentY + (baseSongHeight - bpmLabelSize.height) / 2,
                            width: bpmLabelSize.width,
                            height: bpmLabelSize.height
                        )
                        bpmLabel.draw(in: bpmLabelRect, withAttributes: smallLabelAttributes)
                        currentX += bpmLabelSize.width + spacing
                    }
                    
                    // If key is enabled, draw key
                    if options.showKey && !keyText.isEmpty {
                        // Add separator if BPM is shown
                        if options.showBPM {
                            // Draw a small bullet point or separator
                            let bulletPoint = " • "
                            let bulletSize = bulletPoint.size(withAttributes: songAttributes)
                            let bulletRect = CGRect(
                                x: currentX,
                                y: currentY,
                                width: bulletSize.width,
                                height: baseSongHeight
                            )
                            bulletPoint.draw(in: bulletRect, withAttributes: songAttributes)
                            currentX += bulletSize.width
                        }
                        
                        // Draw key
                        let keyRect = CGRect(
                            x: currentX,
                            y: currentY,
                            width: keySize.width,
                            height: baseSongHeight
                        )
                        keyText.draw(in: keyRect, withAttributes: songAttributes)
                    }
                }
            }
            
            // No page number at the bottom
        }
        
        return PDFPage(image: image)
    }
}

// ReceiptStorage.swift

import Foundation
import UIKit

class ReceiptStorage {
    static func saveReceipt(image: UIImage, recordId: String) -> String? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Could not access documents directory")
            return nil
        }
        
        let receiptsFolder = documentsDirectory.appendingPathComponent("receipts")
        
        // Create folder if it doesn't exist
        if !FileManager.default.fileExists(atPath: receiptsFolder.path) {
            do {
                try FileManager.default.createDirectory(at: receiptsFolder, withIntermediateDirectories: true, attributes: nil)
                print("Created receipts folder at: \(receiptsFolder.path)")
            } catch {
                print("Failed to create receipts folder: \(error)")
                return nil
            }
        }
        
        let fileName = "\(recordId).jpg"
        let fileURL = receiptsFolder.appendingPathComponent(fileName)
        
        guard let data = image.jpegData(compressionQuality: 0.7) else {
            print("Failed to convert image to JPEG data")
            return nil
        }
        
        do {
            try data.write(to: fileURL)
            print("Receipt saved successfully at: \(fileURL.path)")
            return fileURL.path
        } catch {
            print("Error saving receipt: \(error)")
            return nil
        }
    }
    
    static func loadReceipt(path: String) -> UIImage? {
        print("Loading receipt from path: \(path)")
        if FileManager.default.fileExists(atPath: path) {
            return UIImage(contentsOfFile: path)
        } else {
            print("Receipt file does not exist at path: \(path)")
            return nil
        }
    }
    
    static func deleteReceipt(path: String) {
        print("Deleting receipt at path: \(path)")
        do {
            try FileManager.default.removeItem(atPath: path)
            print("Receipt deleted successfully")
        } catch {
            print("Error deleting receipt: \(error)")
        }
    }
}

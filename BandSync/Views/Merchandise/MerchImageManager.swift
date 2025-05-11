//
//  MerchImageManager.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 02.04.2025.
//

import Foundation
import UIKit

class MerchImageManager {
    static let shared = MerchImageManager()
    
    private let fileManager = FileManager.default
    private let imageCache = NSCache<NSString, UIImage>()
    
    private var documentDirectory: URL {
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private var merchImagesDirectory: URL {
        let directory = documentDirectory.appendingPathComponent("merch_images")
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }
    
    private init() {
        // Create cache directory if needed
        try? fileManager.createDirectory(at: merchImagesDirectory, withIntermediateDirectories: true)
    }
    
    // Upload image locally and return URL
    func uploadImage(_ image: UIImage, for merchItem: MerchItem, completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else {
                completion(.failure(NSError(domain: "ImageUploadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "MerchImageManager instance is nil"])))
                return
            }
            
            guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                completion(.failure(NSError(domain: "ImageUploadError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not convert image to JPEG data"])))
                return
            }
            
            let itemIdentifier = merchItem.id ?? UUID().uuidString
            let timestamp = Int(Date().timeIntervalSince1970)
            let imageName = "\(itemIdentifier)_\(timestamp).jpg"
            let imagePath = self.merchImagesDirectory.appendingPathComponent(imageName)
            
            do {
                try imageData.write(to: imagePath)
                
                // Cache the image for faster retrieval
                self.imageCache.setObject(image, forKey: imagePath.absoluteString as NSString)
                
                DispatchQueue.main.async {
                    completion(.success(imagePath))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // Upload multiple images and return array of URLs
    func uploadImages(_ images: [UIImage], for merchItem: MerchItem, completion: @escaping (Result<[URL], Error>) -> Void) {
        let group = DispatchGroup()
        var urls: [URL] = []
        var uploadError: Error?
        
        for image in images {
            group.enter()
            
            uploadImage(image, for: merchItem) { result in
                switch result {
                case .success(let url):
                    urls.append(url)
                case .failure(let error):
                    uploadError = error
                }
                
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if let error = uploadError {
                completion(.failure(error))
            } else {
                completion(.success(urls))
            }
        }
    }
    
    // Download image from local path or URL
    func downloadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        // Check if it's a local file or remote URL
        if urlString.starts(with: "file://") || urlString.starts(with: "/") {
            let imagePath: URL
            if urlString.starts(with: "file://") {
                imagePath = URL(string: urlString)!
            } else {
                imagePath = URL(fileURLWithPath: urlString)
            }
            
            // Check cache first
            if let cachedImage = imageCache.object(forKey: urlString as NSString) {
                DispatchQueue.main.async {
                    completion(cachedImage)
                }
                return
            }
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                    return
                }
                
                if let imageData = try? Data(contentsOf: imagePath),
                   let image = UIImage(data: imageData) {
                    // Cache the image
                    self.imageCache.setObject(image, forKey: urlString as NSString)
                    
                    DispatchQueue.main.async {
                        completion(image)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }
        } else {
            // Handle remote URL
            guard let url = URL(string: urlString) else {
                completion(nil)
                return
            }
            
            // Check cache first
            if let cachedImage = imageCache.object(forKey: urlString as NSString) {
                DispatchQueue.main.async {
                    completion(cachedImage)
                }
                return
            }
            
            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                guard
                    let self = self,
                    let data = data,
                    let image = UIImage(data: data)
                else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                    return
                }
                
                // Cache the image
                self.imageCache.setObject(image, forKey: urlString as NSString)
                
                DispatchQueue.main.async {
                    completion(image)
                }
            }.resume()
        }
    }
    
    // Delete an image
    func deleteImage(url: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            if url.starts(with: "file://") || url.starts(with: "/") {
                let imagePath: URL
                if url.starts(with: "file://") {
                    imagePath = URL(string: url)!
                } else {
                    imagePath = URL(fileURLWithPath: url)
                }
                
                do {
                    try self.fileManager.removeItem(at: imagePath)
                    
                    // Remove from cache
                    self.imageCache.removeObject(forKey: url as NSString)
                    
                    DispatchQueue.main.async {
                        completion(true)
                    }
                } catch {
                    print("Error deleting image: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
            } else {
                // For remote URLs, we just remove them from cache
                self.imageCache.removeObject(forKey: url as NSString)
                DispatchQueue.main.async {
                    completion(true)
                }
            }
        }
    }
    
    // Clear image cache
    func clearCache() {
        imageCache.removeAllObjects()
    }
    
    // Get all locally stored images
    func getAllLocalImages() -> [URL] {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: merchImagesDirectory,
                                                               includingPropertiesForKeys: nil)
            return fileURLs
        } catch {
            print("Error getting local images: \(error.localizedDescription)")
            return []
        }
    }
    
    // Кодирование изображений в Base64 и возврат строк
    func encodeImagesToBase64(_ images: [UIImage], completion: @escaping (Result<[String], Error>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            var base64Strings: [String] = []
            
            for image in images {
                // Изменяем размер изображения для уменьшения объема данных
                let resizedImage = self.resizeImage(image, targetSize: CGSize(width: 800, height: 800))
                
                // Конвертируем в JPEG с компрессией
                guard let imageData = resizedImage.jpegData(compressionQuality: 0.5) else { continue }
                
                // Кодируем в Base64
                let base64String = imageData.base64EncodedString()
                base64Strings.append(base64String)
            }
            
            DispatchQueue.main.async {
                completion(.success(base64Strings))
            }
        }
    }
    
    // Декодирование Base64 в UIImage
    func decodeBase64ToImage(_ base64String: String) -> UIImage? {
        guard let data = Data(base64Encoded: base64String) else { return nil }
        return UIImage(data: data)
    }
    
    // Изменение размера изображения для оптимизации
    func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        // Выбираем меньший коэффициент, чтобы изображение поместилось целиком
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }
        
        // Создаем новый контекст для отрисовки
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
    }
}

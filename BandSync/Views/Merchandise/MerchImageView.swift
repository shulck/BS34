import SwiftUI

struct MerchImageView: View {
    let imageUrl: String
    let item: MerchItem?
    @State private var uiImage: UIImage?
    
    init(imageUrl: String, item: MerchItem? = nil) {
        self.imageUrl = imageUrl
        self.item = item
    }
    
    var body: some View {
        Group {
            if let uiImage = uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(8)
            } else {
                ProgressView()
                    .frame(width: 100, height: 100)
                    .task {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        // Сначала проверяем переданный элемент
        if let directItem = item, 
           let base64Strings = directItem.imageBase64,
           !base64Strings.isEmpty {
            // Если URL содержит индекс изображения
            if let imageIndex = extractImageIndex(from: imageUrl),
               imageIndex < base64Strings.count {
                if let data = Data(base64Encoded: base64Strings[imageIndex]),
                   let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.uiImage = image
                    }
                }
                return
            }
            // Если индекс не найден, но есть хотя бы одно изображение, используем первое
            else if !base64Strings.isEmpty {
                if let data = Data(base64Encoded: base64Strings[0]),
                   let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.uiImage = image
                    }
                }
                return
            }
        }
        
        // Если это base64 URL, попробуем найти товар по ID
        if imageUrl.hasPrefix("base64://") {
            if let itemId = extractItemId(from: imageUrl) {
                // Ищем товар в сервисе
                if let matchingItem = MerchService.shared.items.first(where: { $0.id == itemId }),
                   let base64Strings = matchingItem.imageBase64,
                   !base64Strings.isEmpty {
                    
                    let imageIndex = extractImageIndex(from: imageUrl) ?? 0
                    if imageIndex < base64Strings.count {
                        if let data = Data(base64Encoded: base64Strings[imageIndex]),
                           let image = UIImage(data: data) {
                            DispatchQueue.main.async {
                                self.uiImage = image
                            }
                        }
                        return
                    }
                }
            }
        }
        
        // Если все предыдущие методы не сработали, пробуем загрузить из URL
        guard let url = URL(string: imageUrl) else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.uiImage = image
                }
            }
        }.resume()
    }
    
    // Вспомогательные функции
    private func extractItemId(from url: String) -> String? {
        // URL формата "base64://itemId_index"
        let components = url.replacingOccurrences(of: "base64://", with: "").components(separatedBy: "_")
        return components.first
    }
    
    private func extractImageIndex(from url: String) -> Int? {
        // URL формата "base64://itemId_index"
        let components = url.replacingOccurrences(of: "base64://", with: "").components(separatedBy: "_")
        if components.count > 1, let index = Int(components[1]) {
            return index
        }
        return nil
    }
}
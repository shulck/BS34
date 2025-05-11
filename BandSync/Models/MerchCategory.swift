import Foundation
import FirebaseFirestore

enum MerchCategory: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }

    case clothing = "Clothing"
    case music = "Music"
    case accessory = "Accessories"
    case other = "Other"

    // Adding icon property
    var icon: String {
        switch self {
        case .clothing: return "tshirt"
        case .music: return "music.note"
        case .accessory: return "bag"
        case .other: return "ellipsis.circle"
        }
    }
    
    // Default subcategories for each category
    var defaultSubcategories: [MerchSubcategory] {
        return MerchSubcategory.subcategories(for: self)
    }
    
    // Whether the category needs sizes
    var needsSizes: Bool {
        return self == .clothing
    }
    
    // Get a suggested low stock threshold based on category
    var suggestedLowStockThreshold: Int {
        switch self {
        case .clothing: return 5
        case .music: return 10
        case .accessory: return 15
        case .other: return 3
        }
    }
}

struct MerchSizeStock: Codable {
    var S: Int = 0
    var M: Int = 0
    var L: Int = 0
    var XL: Int = 0
    var XXL: Int = 0

    init(S: Int = 0, M: Int = 0, L: Int = 0, XL: Int = 0, XXL: Int = 0) {
        self.S = S
        self.M = M
        self.L = L
        self.XL = XL
        self.XXL = XXL
    }

    // Total quantity
    var total: Int {
        return S + M + L + XL + XXL
    }

    // Check for low stock - updated algorithm
    func hasLowStock(threshold: Int, category: MerchCategory) -> Bool {
        // For items with total quantity greater than 50, never consider low stock
        if total >= 50 {
            return false
        }
        
        // For clothing, check each size
        if category == .clothing {
            // If any size has stock but is below the threshold, it's low stock
            if (S > 0 && S <= threshold) ||
               (M > 0 && M <= threshold) ||
               (L > 0 && L <= threshold) ||
               (XL > 0 && XL <= threshold) ||
               (XXL > 0 && XXL <= threshold) {
                return true
            }
            
            // If all sizes have zero, it's low stock if the total is zero
            if total == 0 {
                return true
            }
            
            return false
        } else {
            // For non-clothing items, check total stock against threshold
            return total <= threshold
        }
    }
    
    // Get all sizes with stock
    var sizesInStock: [String] {
        var result: [String] = []
        
        if S > 0 { result.append("S") }
        if M > 0 { result.append("M") }
        if L > 0 { result.append("L") }
        if XL > 0 { result.append("XL") }
        if XXL > 0 { result.append("XXL") }
        
        return result
    }
    
    // Get all sizes with low stock
    func sizesWithLowStock(threshold: Int) -> [String] {
        var result: [String] = []
        
        if S > 0 && S <= threshold { result.append("S") }
        if M > 0 && M <= threshold { result.append("M") }
        if L > 0 && L <= threshold { result.append("L") }
        if XL > 0 && XL <= threshold { result.append("XL") }
        if XXL > 0 && XXL <= threshold { result.append("XXL") }
        
        return result
    }
}

struct MerchItem: Identifiable, Codable {
    @DocumentID var id: String?

    var name: String
    var description: String
    var price: Double
    var category: MerchCategory
    var subcategory: MerchSubcategory?
    var stock: MerchSizeStock
    var groupId: String
    var lowStockThreshold: Int
    var sku: String?
    var cost: Double?
    var imageURL: String?
    var imageUrls: [String]?
    var updatedAt: Date?
    
    // Добавляем поле для хранения Base64-изображений
    var imageBase64: [String]?
    
    // Обновляем инициализатор
    init(
        id: String? = nil,
        name: String,
        description: String,
        price: Double,
        category: MerchCategory,
        subcategory: MerchSubcategory? = nil,
        stock: MerchSizeStock,
        groupId: String,
        lowStockThreshold: Int = 5,
        sku: String? = nil,
        cost: Double? = nil,
        imageURL: String? = nil,
        imageUrls: [String]? = nil,
        updatedAt: Date? = Date(),
        imageBase64: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.price = price
        self.category = category
        self.subcategory = subcategory
        self.stock = stock
        self.groupId = groupId
        self.lowStockThreshold = lowStockThreshold
        self.sku = sku
        self.cost = cost
        self.imageURL = imageURL
        self.imageUrls = imageUrls
        self.updatedAt = updatedAt
        self.imageBase64 = imageBase64
    }
    
    // Метод для генерации SKU
    func generateSKU() -> String {
        let prefix = category.rawValue.prefix(2).uppercased()
        let nameComponent = name.filter { !$0.isWhitespace }.prefix(3).uppercased()
        let randomSuffix = String(format: "%04d", Int.random(in: 1000...9999))
        return "\(prefix)-\(nameComponent)-\(randomSuffix)"
    }
    
    // Вычисляемое свойство для получения общего количества запасов
    var totalStock: Int {
        return stock.total
    }
    
    // Проверка на низкий запас
    var isLowStock: Bool {
        return stock.hasLowStock(threshold: lowStockThreshold, category: category)
    }
    
    // Получение списка размеров с низким запасом
    var sizesWithLowStock: [String] {
        return stock.sizesWithLowStock(threshold: lowStockThreshold)
    }
}

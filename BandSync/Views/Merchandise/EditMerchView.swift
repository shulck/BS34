import SwiftUI
import PhotosUI

struct EditMerchView: View {
    @Environment(\.dismiss) var dismiss
    let item: MerchItem

    @State private var name: String
    @State private var description: String
    @State private var price: String
    @State private var cost: String
    @State private var category: MerchCategory
    @State private var subcategory: MerchSubcategory?
    @State private var stock: MerchSizeStock
    @State private var lowStockThreshold: String
    @State private var sku: String
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var merchImages: [UIImage] = []
    @State private var existingImageUrls: [String] = []
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showDeleteAlert = false

    init(item: MerchItem) {
        self.item = item
        _name = State(initialValue: item.name)
        _description = State(initialValue: item.description)
        _price = State(initialValue: String(item.price))
        _cost = State(initialValue: item.cost != nil ? String(item.cost!) : "")
        _category = State(initialValue: item.category)
        _subcategory = State(initialValue: item.subcategory)
        _stock = State(initialValue: item.stock)
        _lowStockThreshold = State(initialValue: String(item.lowStockThreshold))
        _sku = State(initialValue: item.sku ?? "")
        
        // Store existing image URLs
        if let urls = item.imageUrls {
            _existingImageUrls = State(initialValue: urls)
        } else if let url = item.imageURL {
            _existingImageUrls = State(initialValue: [url])
        } else {
            _existingImageUrls = State(initialValue: [])
        }
    }

    var body: some View {
        NavigationView {
            Form {
                // Item images
                Section(header: Text("Images")) {
                    // Show existing images
                    if !existingImageUrls.isEmpty || !merchImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                // Existing images
                                ForEach(existingImageUrls.indices, id: \.self) { index in
                                    MerchImageView(imageUrl: existingImageUrls[index], item: item)
                                        .overlay(
                                            Button(action: {
                                                removeExistingImage(at: index)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.red)
                                                    .padding(4)
                                                    .background(Color.white)
                                                    .clipShape(Circle())
                                            }
                                            .offset(x: 5, y: -5),
                                            alignment: .topTrailing
                                        )
                                }
                                
                                // New images
                                ForEach(0..<merchImages.count, id: \.self) { index in
                                    Image(uiImage: merchImages[index])
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 100)
                                        .cornerRadius(8)
                                        .overlay(
                                            Button(action: {
                                                merchImages.remove(at: index)
                                                selectedImages.remove(at: index)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.red)
                                                    .padding(4)
                                                    .background(Color.white)
                                                    .clipShape(Circle())
                                            }
                                            .offset(x: 5, y: -5),
                                            alignment: .topTrailing
                                        )
                                }
                            }
                            .padding(.vertical, 5)
                        }
                    }
                    
                    PhotosPicker(selection: $selectedImages, maxSelectionCount: 5, matching: .images) {
                        Label("Add more images", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .onChange(of: selectedImages) { newItems in
                        loadImages(from: newItems)
                    }
                }

                // Basic information
                Section(header: Text("Item information")) {
                    TextField("Name", text: $name)
                    
                    ZStack(alignment: .topLeading) {
                        if description.isEmpty {
                            Text("Description")
                                .foregroundColor(.gray.opacity(0.8))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        
                        TextEditor(text: $description)
                            .frame(minHeight: 80)
                    }
                    
                    TextField("Price (EUR)", text: $price)
                        .keyboardType(.decimalPad)
                    
                    TextField("Cost (EUR, optional)", text: $cost)
                        .keyboardType(.decimalPad)
                    
                    if !cost.isEmpty && Double(cost) != nil && Double(price) != nil {
                        let costValue = Double(cost) ?? 0
                        let priceValue = Double(price) ?? 0
                        
                        if costValue > 0 && priceValue > costValue {
                            let margin = ((priceValue - costValue) / priceValue) * 100
                            
                            HStack {
                                Text("Profit margin:")
                                Spacer()
                                Text("\(margin, specifier: "%.1f")%")
                                    .foregroundColor(margin > 50 ? .green : .primary)
                                    .bold(margin > 50)
                            }
                        }
                    }
                    
                    TextField("Low stock threshold", text: $lowStockThreshold)
                        .keyboardType(.numberPad)
                }

                // Category and subcategory
                Section(header: Text("Category")) {
                    Picker("Category", selection: $category) {
                        ForEach(MerchCategory.allCases) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .onChange(of: category) { newCategory in
                        // If new category is different from old one and subcategory doesn't belong to new category
                        if newCategory != item.category,
                           let currentSubcategory = subcategory,
                           !MerchSubcategory.subcategories(for: newCategory).contains(currentSubcategory) {
                            subcategory = nil
                        }
                    }

                    Picker("Subcategory", selection: $subcategory) {
                        Text("Not selected").tag(Optional<MerchSubcategory>.none)
                        ForEach(MerchSubcategory.subcategories(for: category), id: \.self) {
                            Text($0.rawValue).tag(Optional<MerchSubcategory>.some($0))
                        }
                    }
                }
                
                // Inventory
                Section(header: Text("Inventory")) {
                    HStack {
                        TextField("SKU", text: $sku)
                        
                        Button(action: {
                            // Generate an SKU if not specified
                            var tempItem = createUpdatedItem()
                            sku = tempItem.generateSKU()
                        }) {
                            Text("Generate")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }

                // Stock by sizes or quantity
                Section(header: Text(category == .clothing ? "Stock by sizes" : "Item quantity")) {
                    if category == .clothing {
                        Stepper("S: \(stock.S)", value: $stock.S, in: 0...999)
                        Stepper("M: \(stock.M)", value: $stock.M, in: 0...999)
                        Stepper("L: \(stock.L)", value: $stock.L, in: 0...999)
                        Stepper("XL: \(stock.XL)", value: $stock.XL, in: 0...999)
                        Stepper("XXL: \(stock.XXL)", value: $stock.XXL, in: 0...999)
                    } else {
                        Stepper("Quantity: \(stock.S)", value: $stock.S, in: 0...999)
                    }
                    
                    // Quick add buttons for stock
                    HStack {
                        Text("Quick add:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Group {
                            Button("+10") { addStock(10) }
                            Button("+50") { addStock(50) }
                            Button("+100") { addStock(100) }
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                    }
                }
                
                // Delete section
                Section {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Item")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Item")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(isUploading || !isFormValid)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .overlay(
                Group {
                    if isUploading {
                        ProgressView("Saving...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(10)
                    }
                }
            )
            .alert(isPresented: $showError) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage ?? "An unknown error occurred"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert("Delete item?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteItem()
                }
            } message: {
                Text("Are you sure you want to delete this item? This action cannot be undone.")
            }
        }
        .onAppear {
            loadExistingImages()
        }
    }

    // Form validation
    private var isFormValid: Bool {
        !name.isEmpty &&
        !price.isEmpty &&
        Double(price) != nil &&
        (price as NSString).doubleValue > 0 &&
        Int(lowStockThreshold) != nil &&
        (lowStockThreshold as NSString).integerValue >= 0 &&
        (existingImageUrls.count + merchImages.count > 0)
    }

    // Load existing images
    private func loadExistingImages() {
        // Load existing image URLs into UIImage objects if needed
        // This is only needed if you want to manipulate the existing images
    }
    
    // Load new selected images
    private func loadImages(from items: [PhotosPickerItem]) {
        for item in items {
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    DispatchQueue.main.async {
                        merchImages.append(uiImage)
                    }
                }
            }
        }
    }
    
    // Remove existing image
    private func removeExistingImage(at index: Int) {
        if index < existingImageUrls.count {
            existingImageUrls.remove(at: index)
        }
    }
    
    // Add stock quickly
    private func addStock(_ amount: Int) {
        if category == .clothing {
            // Distribute evenly across sizes for clothing
            let perSize = amount / 5
            stock.S += perSize
            stock.M += perSize
            stock.L += perSize
            stock.XL += perSize
            stock.XXL += perSize
        } else {
            // For other categories add to total (stored in S)
            stock.S += amount
        }
    }
    
    // Create updated item from form data
    private func createUpdatedItem() -> MerchItem {
        var updatedItem = item
        updatedItem.name = name
        updatedItem.description = description
        updatedItem.price = Double(price) ?? item.price
        
        if let costValue = Double(cost) {
            updatedItem.cost = costValue
        } else {
            updatedItem.cost = nil
        }
        
        updatedItem.category = category
        updatedItem.subcategory = subcategory
        
        // Update stock depending on category
        if category == .clothing {
            // For clothing save all sizes
            updatedItem.stock = stock
        } else {
            // For other categories save total quantity in S, other sizes = 0
            updatedItem.stock = MerchSizeStock(S: stock.S, M: 0, L: 0, XL: 0, XXL: 0)
        }
        
        updatedItem.lowStockThreshold = Int(lowStockThreshold) ?? item.lowStockThreshold
        updatedItem.sku = sku.isEmpty ? nil : sku
        updatedItem.updatedAt = Date()
        
        return updatedItem
    }

    // Save changes
    private func saveChanges() {
        isUploading = true
        errorMessage = nil
        
        var updatedItem = createUpdatedItem()
        
        // Если есть новые изображения для загрузки, конвертируем их в Base64
        if !merchImages.isEmpty {
            // Создаем массив для хранения Base64 строк
            var base64Images: [String] = []
            
            for image in merchImages {
                // Изменяем размер и сжимаем для уменьшения объема данных
                let resizedImage = MerchImageManager.shared.resizeImage(image, targetSize: CGSize(width: 800, height: 800))
                if let imageData = resizedImage.jpegData(compressionQuality: 0.5) {
                    let base64String = imageData.base64EncodedString()
                    base64Images.append(base64String)
                }
            }
            
            // Сохраняем Base64 строки в поле imageBase64
            if !base64Images.isEmpty {
                updatedItem.imageBase64 = base64Images
                
                // Генерируем стабильные URL, используя ID товара
                let itemId = updatedItem.id ?? UUID().uuidString
                var urls = [String]()
                
                for i in 0..<base64Images.count {
                    urls.append("base64://\(itemId)_\(i)")
                }
                
                updatedItem.imageUrls = urls
                
                // Используем первое изображение как основное
                if !urls.isEmpty {
                    updatedItem.imageURL = urls[0]
                }
            }
        }
        
        // Теперь сохраняем обновленный товар
        MerchService.shared.updateItem(updatedItem) { success in
            DispatchQueue.main.async {
                self.isUploading = false
                if success {
                    self.dismiss()
                } else {
                    self.errorMessage = "Не удалось сохранить изменения"
                    self.showError = true
                }
            }
        }
    }

    private func deleteItem() {
        isUploading = true
        
        MerchService.shared.deleteItem(item) { success in
            DispatchQueue.main.async {
                self.isUploading = false
                
                if success {
                    self.dismiss()
                } else {
                    self.errorMessage = "Failed to delete item"
                    self.showError = true
                }
            }
        }
    }
}

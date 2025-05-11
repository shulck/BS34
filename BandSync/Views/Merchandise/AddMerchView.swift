import SwiftUI
import PhotosUI

struct AddMerchView: View {
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var price = ""
    @State private var category: MerchCategory = .clothing
    @State private var subcategory: MerchSubcategory?
    @State private var stock = MerchSizeStock()
    @State private var lowStockThreshold = "5"
    @State private var cost = ""
    @State private var sku = ""
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var merchImages: [UIImage] = []
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showImportCSV = false
    @State private var csvData: String?

    var body: some View {
        NavigationView {
            Form {
                // Item image
                Section(header: Text("Images")) {
                    if !merchImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
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
                        Label(merchImages.isEmpty ? "Select images" : "Add more images", systemImage: "photo.on.rectangle")
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
                    
                    HStack {
                        TextField("Low stock threshold", text: $lowStockThreshold)
                            .keyboardType(.numberPad)
                        
                        Spacer()
                        
                        Text("\(stock.total) items")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }

                // Category and subcategory
                Section(header: Text("Category")) {
                    Picker("Category", selection: $category) {
                        ForEach(MerchCategory.allCases) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .onChange(of: category) { newValue in
                        // Reset subcategory when changing category
                        subcategory = nil
                        
                        // Update suggested threshold
                        lowStockThreshold = "\(newValue.suggestedLowStockThreshold)"
                    }

                    // Dynamic subcategory selection
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
                        TextField("SKU (optional)", text: $sku)
                        
                        Button(action: {
                            // Generate an SKU if not specified
                            var item = createItem()
                            sku = item.generateSKU()
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

                // Stock section
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
            }
            .navigationTitle("Add Item")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            saveItem()
                        } label: {
                            Label("Save", systemImage: "checkmark")
                        }
                        .disabled(isUploading || !isFormValid)
                        
                        Button {
                            showImportCSV = true
                        } label: {
                            Label("Import from CSV", systemImage: "doc.text")
                        }
                        
                        Button {
                            saveDraft()
                        } label: {
                            Label("Save as Draft", systemImage: "tray.and.arrow.down")
                        }
                    } label: {
                        Text("Save")
                    }
                    .disabled(isUploading || !isMinimallyValid)
                }
            }
            .overlay(
                Group {
                    if isUploading {
                        ProgressView("Uploading...")
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
            .sheet(isPresented: $showImportCSV) {
                CSVImportView { importedData in
                    csvData = importedData
                    showImportCSV = false
                    
                    // Process the CSV
                    if let csvString = csvData,
                       let groupId = AppState.shared.user?.groupId,
                       let items = ImportExportService.shared.importItemsFromCSV(csv: csvString, groupId: groupId),
                       let firstItem = items.first {
                        
                        // Use the first item from CSV
                        name = firstItem.name
                        description = firstItem.description
                        price = "\(firstItem.price)"
                        category = firstItem.category
                        subcategory = firstItem.subcategory
                        stock = firstItem.stock
                        lowStockThreshold = "\(firstItem.lowStockThreshold)"
                        
                        if let costValue = firstItem.cost {
                            cost = "\(costValue)"
                        }
                        
                        if let skuValue = firstItem.sku {
                            sku = skuValue
                        }
                    }
                }
            }
        }
    }

    // Form validation
    private var isFormValid: Bool {
        !name.isEmpty &&
        !price.isEmpty &&
        Double(price) != nil &&
        (price as NSString).doubleValue > 0 &&
        Int(lowStockThreshold) != nil &&
        merchImages.count > 0
    }
    
    // Minimal validation for saving drafts
    private var isMinimallyValid: Bool {
        !name.isEmpty && Double(price) != nil
    }
    
    // Load selected images
    private func loadImages(from items: [PhotosPickerItem]) {
        let dispatchGroup = DispatchGroup()
        var loadErrors = 0
        
        for (index, item) in items.enumerated() {
            dispatchGroup.enter()
            
            Task {
                do {
                    if let data = try await item.loadTransferable(type: Data.self) {
                        if let uiImage = UIImage(data: data) {
                            DispatchQueue.main.async {
                                // Если индекс уже есть в коллекции - заменяем, иначе добавляем
                                if index < merchImages.count {
                                    merchImages[index] = uiImage
                                } else {
                                    merchImages.append(uiImage)
                                }
                            }
                        } else {
                            DispatchQueue.main.async {
                                loadErrors += 1
                            }
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        loadErrors += 1
                        errorMessage = "Error loading images: \(error.localizedDescription)"
                        showError = true
                    }
                }
                
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if loadErrors > 0 {
                errorMessage = "Failed to load \(loadErrors) image(s)"
                showError = true
            }
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
    
    // Create item from form data
    private func createItem() -> MerchItem {
        let priceValue = Double(price) ?? 0
        let costValue = Double(cost)
        let thresholdValue = Int(lowStockThreshold) ?? category.suggestedLowStockThreshold
        let groupId = AppState.shared.user?.groupId ?? ""
        
        var actualStock = stock
        
        // For non-clothing items, only use S for stock
        if category != .clothing {
            actualStock = MerchSizeStock(S: stock.S, M: 0, L: 0, XL: 0, XXL: 0)
        }
        
        return MerchItem(
            name: name,
            description: description,
            price: priceValue,
            category: category,
            subcategory: subcategory,
            stock: actualStock,
            groupId: groupId,
            lowStockThreshold: thresholdValue,
            cost: costValue
        )
    }

    // Save item
    private func saveItem() {
        guard let groupId = AppState.shared.user?.groupId else {
            errorMessage = "User group not found"
            showError = true
            return
        }

        isUploading = true
        errorMessage = nil
        
        let item = createItem()

        // If there are images, upload them
        if !merchImages.isEmpty {
            var base64Images: [String] = []
            
            for image in merchImages {
                let resizedImage = MerchImageManager.shared.resizeImage(image, targetSize: CGSize(width: 800, height: 800))
                if let imageData = resizedImage.jpegData(compressionQuality: 0.5) {
                    let base64String = imageData.base64EncodedString()
                    base64Images.append(base64String)
                }
            }
            
            if !base64Images.isEmpty {
                var updatedItem = item
                updatedItem.imageBase64 = base64Images
                
                // Generate temporary ID for URLs
                var urls = [String]()
                
                for i in 0..<base64Images.count {
                    urls.append("base64://\(item.id)_\(i)")
                }
                
                updatedItem.imageUrls = urls
                updatedItem.imageURL = urls[0]
                
                MerchService.shared.addItem(updatedItem) { success in
                    self.isUploading = false
                    if success {
                        self.dismiss()
                    } else {
                        self.errorMessage = "Failed to save item"
                        self.showError = true
                    }
                }
            } else {
                MerchImageManager.shared.uploadImages(merchImages, for: item) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let urls):
                            // Create item with image URLs
                            var updatedItem = item
                            updatedItem.imageUrls = urls.map { $0.absoluteString }
                            
                            if let firstUrl = urls.first {
                                updatedItem.imageURL = firstUrl.absoluteString
                            }

                            MerchService.shared.addItem(updatedItem) { success in
                                self.isUploading = false
                                if success {
                                    self.dismiss()
                                } else {
                                    self.errorMessage = "Failed to save item"
                                    self.showError = true
                                }
                            }
                        case .failure(let error):
                            self.isUploading = false
                            self.errorMessage = "Error uploading images: \(error.localizedDescription)"
                            self.showError = true
                        }
                    }
                }
            }
        } else {
            // Create item without images
            MerchService.shared.addItem(item) { success in
                self.isUploading = false
                if success {
                    self.dismiss()
                } else {
                    self.errorMessage = "Failed to save item"
                    self.showError = true
                }
            }
        }
    }
    
    // Save draft locally
    private func saveDraft() {
        let item = createItem()
        let encoder = JSONEncoder()
        
        do {
            let itemData = try encoder.encode(item)
            
            // Save to UserDefaults
            var drafts = UserDefaults.standard.array(forKey: "merch_item_drafts") as? [Data] ?? []
            drafts.append(itemData)
            UserDefaults.standard.set(drafts, forKey: "merch_item_drafts")
            
            dismiss()
        } catch {
            errorMessage = "Failed to save draft: \(error.localizedDescription)"
            showError = true
        }
    }
}

// CSV Import View
struct CSVImportView: View {
    var onImport: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var csvText = ""
    @State private var showFilePicker = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("CSV Data")) {
                    ZStack(alignment: .topLeading) {
                        if csvText.isEmpty {
                            Text("Paste CSV data here...")
                                .foregroundColor(.gray.opacity(0.8))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        
                        TextEditor(text: $csvText)
                            .frame(minHeight: 200)
                    }
                    
                    Button("Import from file") {
                        showFilePicker = true
                    }
                }
                
                Section {
                    Button("Import CSV") {
                        onImport(csvText)
                    }
                    .disabled(csvText.isEmpty)
                    .frame(maxWidth: .infinity)
                }
                
                Section(header: Text("Sample Format")) {
                    Text("Name,Description,Price,Category,Subcategory,S,M,L,XL,XXL\nT-Shirt,Band logo t-shirt,25,Clothing,T-shirt,10,15,20,10,5\nVinyl,Limited edition vinyl,30,Music,Vinyl Record,50,0,0,0,0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Import from CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showFilePicker) {
                DocumentPicker { url in
                    do {
                        let data = try Data(contentsOf: url)
                        if let text = String(data: data, encoding: .utf8) {
                            csvText = text
                        }
                    } catch {
                        print("Error loading file: \(error)")
                    }
                }
            }
        }
    }
}

// Document Picker for importing CSV files
struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.commaSeparatedText, .text])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Secure access to the selected file
            guard url.startAccessingSecurityScopedResource() else { return }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            parent.onPick(url)
        }
    }
}

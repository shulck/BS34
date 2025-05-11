import SwiftUI
import UIKit

struct MerchDetailView: View {
    let item: MerchItem
    @State private var showSell = false
    @State private var merchImage: UIImage?
    @State private var isLoadingImage = false
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showSalesHistory = false
    @State private var showAllImages = false
    @State private var selectedImageIndex = 0
    @Environment(\.presentationMode) var presentationMode
    
    // For export functionality
    @State private var showingExportOptions = false
    @State private var exportedData: Foundation.Data?
    @State private var showingShareSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Item image
                imageSection
                
                // Gallery indicator
                if let imageUrls = item.imageUrls, imageUrls.count > 1 {
                    HStack(spacing: 4) {
                        ForEach(0..<imageUrls.count, id: \.self) { index in
                            Circle()
                                .fill(index == selectedImageIndex ? Color.blue : Color.gray.opacity(0.5))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.top, -8)
                    .frame(maxWidth: .infinity)
                }

                // Main information
                detailsSection

                // Stock by size
                stockSection

                // Recent sales stats
                recentSalesSection
                
                // Sales history button
                Button("Sales history") {
                    showSalesHistory = true
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.2))
                .foregroundColor(.blue)
                .cornerRadius(10)

                // Sell button
                sellButton
            }
            .padding()
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if AppState.shared.hasEditPermission(for: .merchandise) {
                        Menu {
                            Button {
                                showEditSheet = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Button {
                                showingExportOptions = true
                            } label: {
                                Label("Export", systemImage: "square.and.arrow.up")
                            }

                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                    }
                }
            }
        }
        .onAppear {
            loadImage()
        }
        .sheet(isPresented: $showSell) {
            SellMerchView(item: item)
        }
        .sheet(isPresented: $showEditSheet) {
            EditMerchView(item: item)
        }
        .sheet(isPresented: $showSalesHistory) {
            SalesHistoryView(item: item)
        }
        .sheet(isPresented: $showAllImages) {
            MerchImageGalleryView(item: item)
        }
        .alert("Delete item?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteItem()
            }
        } message: {
            Text("Are you sure you want to delete item '\(item.name)'? This action cannot be undone.")
        }
        .confirmationDialog("Export Options", isPresented: $showingExportOptions) {
            Button("Export as PDF") {
                exportAsPDF()
            }
            Button("Export Sales History") {
                exportSalesHistory()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingShareSheet) {
            if let exportedData = exportedData {
                MerchShareSheet(data: exportedData, filename: "\(item.name)_export.pdf")
            }
        }
    }

    // Image section
    private var imageSection: some View {
        ZStack {
            if isLoadingImage {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 250)
            } else {
                MerchImageView(imageUrl: item.imageURL ?? "", item: item)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, minHeight: 250)
            }
        }
    }

    // Details section
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.description)
                .font(.body)

            HStack {
                Text("Category:")
                Spacer()
                Text(item.category.rawValue)
            }

            if let subcategory = item.subcategory {
                HStack {
                    Text("Subcategory:")
                    Spacer()
                    Text(subcategory.rawValue)
                }
            }

            HStack {
                Text("Price:")
                Spacer()
                Text("\(Int(item.price)) EUR")
                    .bold()
            }
        }
    }

    // Stock section
    private var stockSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if item.category == .clothing {
                Text("Stock by sizes")
                    .font(.headline)

                HStack {
                    Text("S:")
                    Spacer()
                    Text("\(item.stock.S)")
                        .foregroundColor(getStockColor(quantity: item.stock.S))
                }
                HStack {
                    Text("M:")
                    Spacer()
                    Text("\(item.stock.M)")
                        .foregroundColor(getStockColor(quantity: item.stock.M))
                }
                HStack {
                    Text("L:")
                    Spacer()
                    Text("\(item.stock.L)")
                        .foregroundColor(getStockColor(quantity: item.stock.L))
                }
                HStack {
                    Text("XL:")
                    Spacer()
                    Text("\(item.stock.XL)")
                        .foregroundColor(getStockColor(quantity: item.stock.XL))
                }
                HStack {
                    Text("XXL:")
                    Spacer()
                    Text("\(item.stock.XXL)")
                        .foregroundColor(getStockColor(quantity: item.stock.XXL))
                }
            } else {
                Text("Quantity:")
                    .font(.headline)
                Text("\(item.totalStock)")
                    .font(.title3)
                    .foregroundColor(getStockColor(quantity: item.totalStock))
            }
            
            // Show progress indicator for stock level
            ProgressView(value: Double(item.totalStock), total: Double(item.totalStock + getSaleQuantity(for: item.id ?? "")))
                .progressViewStyle(LinearProgressViewStyle(tint: getStockColor(quantity: item.totalStock)))
                .padding(.vertical, 4)
            
            // Low stock warning if applicable
            if item.isLowStock {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Low stock! Threshold: \(item.lowStockThreshold) pcs.")
                        .foregroundColor(.orange)
                }
                .padding(.top, 5)
            }
        }
    }
    
    // Recent sales stats
    private var recentSalesSection: some View {
        let salesCount = getSaleQuantity(for: item.id ?? "")
        let salesRevenue = getSaleRevenue(for: item.id ?? "")
        
        return Group {
            if salesCount > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Sales")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Last 30 days:")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\(salesCount) pcs.")
                                .font(.title3)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Revenue:")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\(salesRevenue, specifier: "%.2f") EUR")
                                .font(.title3)
                        }
                    }
                }
            }
        }
    }

    // Sell button
    private var sellButton: some View {
        Button("Sell item") {
            showSell = true
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(10)
        .disabled(item.totalStock == 0)
        .opacity(item.totalStock == 0 ? 0.5 : 1)
    }

    // Load image
    private func loadImage() {
        if let imageUrls = item.imageUrls, !imageUrls.isEmpty, selectedImageIndex < imageUrls.count {
            loadImageAtIndex(selectedImageIndex)
        } else if let imageURL = item.imageURL {
            isLoadingImage = true
            MerchImageManager.shared.downloadImage(from: imageURL) { image in
                DispatchQueue.main.async {
                    self.merchImage = image
                    self.isLoadingImage = false
                }
            }
        }
    }
    
    // Load image at specific index
    private func loadImageAtIndex(_ index: Int) {
        guard let imageUrls = item.imageUrls, index < imageUrls.count else { return }
        
        isLoadingImage = true
        MerchImageManager.shared.downloadImage(from: imageUrls[index]) { image in
            DispatchQueue.main.async {
                self.merchImage = image
                self.isLoadingImage = false
            }
        }
    }

    // Delete item
    private func deleteItem() {
        MerchService.shared.deleteItem(item) { success in
            if success {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    // Helper functions
    
    // Get color based on stock level
    private func getStockColor(quantity: Int) -> Color {
        if quantity == 0 {
            return .red
        } else if quantity <= item.lowStockThreshold {
            return .orange
        } else {
            return .green
        }
    }
    
    // Get sales quantity for this item in last 30 days
    private func getSaleQuantity(for itemId: String) -> Int {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return MerchService.shared.sales
            .filter { $0.itemId == itemId && $0.date >= cutoffDate }
            .reduce(0) { $0 + $1.quantity }
    }
    
    // Get sales revenue for this item in last 30 days
    private func getSaleRevenue(for itemId: String) -> Double {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentSales = MerchService.shared.sales
            .filter { $0.itemId == itemId && $0.date >= cutoffDate }
        
        return recentSales.reduce(0.0) { total, sale in
            total + (Double(sale.quantity) * item.price)
        }
    }
    
    // Export functions
    
    // Export item details as PDF
    private func exportAsPDF() {
        let pdfData = renderItemAsPDF()
        self.exportedData = pdfData
        self.showingShareSheet = true
    }
    
    // Export sales history
    private func exportSalesHistory() {
        guard let id = item.id else { return }
        
        let sales = MerchService.shared.getSalesForItem(id)
        let csvData = generateCSV(from: sales)
        
        self.exportedData = csvData
        self.showingShareSheet = true
    }
    
    // Render item details as PDF
    private func renderItemAsPDF() -> Foundation.Data {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            // Define drawing area
            let drawingRect = CGRect(x: 50, y: 50, width: pageWidth - 100, height: pageHeight - 100)
            
            // Title
            let title = item.name
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24)
            ]
            
            let titleSize = (title as NSString).size(withAttributes: titleAttributes)
            (title as NSString).draw(
                at: CGPoint(x: drawingRect.midX - titleSize.width / 2, y: drawingRect.minY),
                withAttributes: titleAttributes
            )
            
            // Item image
            if let merchImage = merchImage {
                let imageRect = CGRect(x: drawingRect.midX - 100, y: drawingRect.minY + 50, width: 200, height: 200)
                merchImage.draw(in: imageRect)
            }
            
            // Details
            let detailsY = drawingRect.minY + 270
            let detailsAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14)
            ]
            
            let details = """
            Category: \(item.category.rawValue)
            \(item.subcategory != nil ? "Subcategory: \(item.subcategory!.rawValue)" : "")
            Price: \(Int(item.price)) EUR
            Stock: \(item.totalStock) pcs.
            Description: \(item.description)
            """
            
            (details as NSString).draw(
                in: CGRect(x: drawingRect.minX, y: detailsY, width: drawingRect.width, height: 200),
                withAttributes: detailsAttributes
            )
            
            // Footer
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.gray
            ]
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            
            let footer = "Generated on \(dateFormatter.string(from: Date()))"
            let footerSize = (footer as NSString).size(withAttributes: footerAttributes)
            
            (footer as NSString).draw(
                at: CGPoint(x: drawingRect.midX - footerSize.width / 2, y: drawingRect.maxY - 20),
                withAttributes: footerAttributes
            )
        }
        
        return data
    }
    
    // Generate CSV from sales data
    private func generateCSV(from sales: [MerchSale]) -> Foundation.Data {
        var csvString = "Date,Size,Quantity,Channel,Amount\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for sale in sales {
            let dateString = dateFormatter.string(from: sale.date)
            let amount = sale.channel == .gift ? "Gift" : "\(Double(sale.quantity) * item.price)"
            
            let line = "\(dateString),\(sale.size),\(sale.quantity),\(sale.channel.rawValue),\(amount)\n"
            csvString.append(line)
        }
        
        return csvString.data(using: .utf8) ?? Foundation.Data()
    }
}

// Переименованный ShareSheet для экспорта файлов
struct MerchShareSheet: UIViewControllerRepresentable {
    let data: Foundation.Data
    let filename: String
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: tempURL)
        
        let activityViewController = UIActivityViewController(
            activityItems: [tempURL],
            applicationActivities: nil
        )
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Image Gallery View
struct MerchImageGalleryView: View {
    let item: MerchItem
    @State private var selectedImageIndex = 0
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                TabView {
                    ForEach(item.imageUrls ?? [item.imageURL].compactMap { $0 }, id: \.self) { urlString in
                        MerchImageView(imageUrl: urlString, item: item)
                    }
                }
                .tabViewStyle(PageTabViewStyle())
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            }
            .navigationTitle("Item Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Helper view for async image loading
struct AsyncLoadingImage: View {
    let url: String
    let item: MerchItem?
    
    var body: some View {
        MerchImageView(imageUrl: url, item: item)
            .pinchToZoom()
    }
}

// PinchToZoom modifier for images
struct PinchToZoom: ViewModifier {
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        let delta = value / lastScale
                        lastScale = value
                        scale *= delta
                    }
                    .onEnded { _ in
                        if scale < 1.0 {
                            withAnimation {
                                scale = 1.0
                            }
                        } else if scale > 3.0 {
                            withAnimation {
                                scale = 3.0
                            }
                        }
                        lastScale = 1.0
                    }
            )
    }
}

extension View {
    func pinchToZoom() -> some View {
        self.modifier(PinchToZoom())
    }
}

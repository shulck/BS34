//
//  MerchView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct MerchView: View {
    @StateObject private var merchService = MerchService.shared
    @State private var showAdd = false
    @State private var showDrafts = false
    @State private var showAnalytics = false
    @State private var selectedCategory: MerchCategory? = nil
    @State private var searchText = ""
    @State private var showLowStockAlert = false
    @State private var showingExportOptions = false
    @State private var exportedData: Foundation.Data?
    @State private var showingShareSheet = false
    @State private var isGridView = false
    @State private var showingSortOptions = false
    @State private var sortOption: SortOption = .name
    @State private var showFilterPopover = false
    
    enum SortOption: String, CaseIterable {
        case name = "Name"
        case nameDesc = "Name (Z-A)"
        case price = "Price (Low to High)"
        case priceDesc = "Price (High to Low)"
        case stock = "Stock (Low to High)"
        case stockDesc = "Stock (High to Low)"
        case newest = "Newest First"
        case oldest = "Oldest First"
    }

    // Filtered items based on search and categories
    private var filteredItems: [MerchItem] {
        var items = merchService.items

        // Filter by category
        if let category = selectedCategory {
            items = items.filter { $0.category == category }
        }

        // Filter by search query
        if !searchText.isEmpty {
            items = items.filter { item in
                // Разбиваем сложное выражение на отдельные условия для облегчения проверки типа
                let nameMatch = item.name.lowercased().contains(searchText.lowercased())
                let descMatch = item.description.lowercased().contains(searchText.lowercased())
                let categoryMatch = item.category.rawValue.lowercased().contains(searchText.lowercased())
                
                let subcategoryMatch: Bool
                if let subcategory = item.subcategory?.rawValue.lowercased() {
                    subcategoryMatch = subcategory.contains(searchText.lowercased())
                } else {
                    subcategoryMatch = false
                }
                
                let skuMatch: Bool
                if let sku = item.sku?.lowercased() {
                    skuMatch = sku.contains(searchText.lowercased())
                } else {
                    skuMatch = false
                }
                
                // Объединяем результаты поиска
                return nameMatch || descMatch || categoryMatch || subcategoryMatch || skuMatch
            }
        }
        
        // Sort items
        return sortItems(items)
    }
    
    // Sort items based on selected option
    private func sortItems(_ items: [MerchItem]) -> [MerchItem] {
        switch sortOption {
        case .name:
            return items.sorted(by: { item1, item2 in
                item1.name < item2.name
            })
        case .nameDesc:
            return items.sorted(by: { item1, item2 in
                item1.name > item2.name
            })
        case .price:
            return items.sorted(by: { item1, item2 in
                item1.price < item2.price
            })
        case .priceDesc:
            return items.sorted(by: { item1, item2 in
                item1.price > item2.price
            })
        case .stock:
            return items.sorted(by: { item1, item2 in
                item1.totalStock < item2.totalStock
            })
        case .stockDesc:
            return items.sorted(by: { item1, item2 in
                item1.totalStock > item2.totalStock
            })
        case .newest:
            return items.sorted(by: { item1, item2 in
                // Используем updatedAt вместо createdAt, проверяя на nil
                let date1 = item1.updatedAt ?? Date(timeIntervalSince1970: 0)
                let date2 = item2.updatedAt ?? Date(timeIntervalSince1970: 0)
                return date1 > date2
            })
        case .oldest:
            return items.sorted(by: { item1, item2 in
                // Используем updatedAt вместо createdAt, проверяя на nil
                let date1 = item1.updatedAt ?? Date(timeIntervalSince1970: 0)
                let date2 = item2.updatedAt ?? Date(timeIntervalSince1970: 0)
                return date1 < date2
            })
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Product categories
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        categoryButton(title: "All", icon: "tshirt.fill", category: nil)

                        ForEach(MerchCategory.allCases) { category in
                            categoryButton(
                                title: category.rawValue,
                                icon: category.icon,
                                category: category
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color.gray.opacity(0.1))

                // Item counter and low stock
                HStack {
                    VStack(alignment: .leading) {
                        Text("Items")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(filteredItems.count)")
                            .font(.headline)
                    }

                    Spacer()
                    
                    // Low stock and view toggles
                    HStack(spacing: 10) {
                        if !merchService.lowStockItems.isEmpty {
                            // Low stock items information
                            Button {
                                showLowStockItems()
                            } label: {
                                Label("\(merchService.lowStockItems.count) low stock", systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(8)
                            }
                        }
                        
                        // Grid/List toggle
                        Button(action: {
                            isGridView.toggle()
                        }) {
                            Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                                .foregroundColor(.blue)
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        // Sort button
                        Button(action: {
                            showingSortOptions = true
                        }) {
                            Image(systemName: "arrow.up.arrow.down")
                                .foregroundColor(.blue)
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .confirmationDialog("Sort By", isPresented: $showingSortOptions) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Button(option.rawValue) {
                                    sortOption = option
                                }
                            }
                            Button("Cancel", role: .cancel) {}
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                if merchService.isLoading {
                    // Loading indicator
                    ProgressView("Loading items...")
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredItems.isEmpty {
                    // Empty list state
                    VStack(spacing: 20) {
                        Image(systemName: "bag")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)

                        Text(searchText.isEmpty
                            ? "No items in selected category"
                            : "No items matching '\(searchText)'")
                        .foregroundColor(.gray)

                        if AppState.shared.hasEditPermission(for: .merchandise) {
                            Button("Add item") {
                                showAdd = true
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Items list or grid
                    if isGridView {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 16) {
                                ForEach(filteredItems) { item in
                                    NavigationLink(destination: MerchDetailView(item: item)) {
                                        MerchItemGridCell(item: item)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding()
                        }
                    } else {
                        List {
                            ForEach(filteredItems) { item in
                                NavigationLink(destination: MerchDetailView(item: item)) {
                                    MerchItemRow(item: item)
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
            }
            .navigationTitle("Merch")
            .searchable(text: $searchText, prompt: "Search items")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if AppState.shared.hasEditPermission(for: .merchandise) {
                            Button {
                                showAdd = true
                            } label: {
                                Label("Add item", systemImage: "plus")
                            }
                            
                            Button {
                                showDrafts = true
                            } label: {
                                Label("Saved drafts", systemImage: "tray.and.arrow.down")
                            }
                        }

                        Button {
                            showAnalytics = true
                        } label: {
                            Label("Sales analytics", systemImage: "chart.bar")
                        }

                        if !merchService.lowStockItems.isEmpty {
                            Button {
                                showLowStockItems()
                            } label: {
                                Label("Show low stock items", systemImage: "exclamationmark.triangle")
                            }
                        }
                        
                        Button {
                            showingExportOptions = true
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    if !merchService.lowStockItems.isEmpty {
                        Badge(count: merchService.lowStockItems.count, color: .orange)
                            .offset(x: 10, y: -10)
                    }
                }
            }
            .onAppear {
                if let groupId = AppState.shared.user?.groupId {
                    merchService.fetchItems(for: groupId)
                    merchService.fetchSales(for: groupId)
                }
            }
            .sheet(isPresented: $showAdd) {
                AddMerchView()
            }
            .sheet(isPresented: $showDrafts) {
                DraftsView()
            }
            .alert("Low stock items", isPresented: $showLowStockAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("There are \(merchService.lowStockItems.count) items with stock below threshold.")
            }
            .confirmationDialog("Export Options", isPresented: $showingExportOptions) {
                Button("Export Inventory") {
                    exportInventory()
                }
                
                Button("Export Sales") {
                    exportSales()
                }
                
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showingShareSheet) {
                if let exportedData = exportedData {
                    MerchShareSheet(data: exportedData, filename: "merch_export.csv")
                }
            }
        }
    }

    // Category button
    private func categoryButton(title: String, icon: String, category: MerchCategory?) -> some View {
        Button {
            withAnimation {
                selectedCategory = category
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16))

                Text(title)
                    .font(.caption)
            }
            .foregroundColor(selectedCategory == category ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selectedCategory == category ? Color.blue : Color.gray.opacity(0.2))
            .cornerRadius(10)
        }
    }

    // Show low stock items
    private func showLowStockItems() {
        // Create temporary list for comparison
        let lowStockItemIds = Set(merchService.lowStockItems.compactMap { $0.id })

        // Determine low stock items in current view
        let lowStockItemsInCurrentView = filteredItems.filter { item in
            if let id = item.id {
                return lowStockItemIds.contains(id)
            }
            return false
        }

        // If no low stock items in current view,
        // show separate alert with information
        if lowStockItemsInCurrentView.isEmpty {
            showLowStockAlert = true
        } else {
            // Otherwise reset filters and set new search to display only low stock items
            selectedCategory = nil
            searchText = "low_stock_filter"

            // Delay for applying filters
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.searchText = ""  // Reset search query
                
                // Set sort by stock (low to high)
                self.sortOption = .stock
            }
        }
    }
    
    // Export inventory to CSV
    private func exportInventory() {
        if let data = ImportExportService.shared.exportItemsToCSV(items: merchService.items) {
            self.exportedData = data
            self.showingShareSheet = true
        }
    }
    
    // Export sales to CSV
    private func exportSales() {
        if let data = ImportExportService.shared.exportSalesToCSV(sales: merchService.sales, items: merchService.items) {
            self.exportedData = data
            self.showingShareSheet = true
        }
    }
}

// Badge for notifications
struct Badge: View {
    let count: Int
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color)
            
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .frame(width: 18, height: 18)
    }
}

// MARK: - Structure for item grid cell

struct MerchItemGridCell: View {
    let item: MerchItem
    
    var body: some View {
        VStack(alignment: .leading) {
            // Item image or category icon
            ZStack {
                MerchImageView(imageUrl: item.imageURL ?? "", item: item)
                    .frame(width: 160, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            // Item info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                HStack {
                    Text("\(Int(item.price)) EUR")
                        .font(.caption)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    if item.isLowStock {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    
                    Text("Stock: \(item.totalStock)")
                        .font(.caption)
                        .foregroundColor(getStockColor(item))
                }
                
                Text(item.category.rawValue)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func getStockColor(_ item: MerchItem) -> Color {
        if item.totalStock == 0 {
            return .red
        } else if item.isLowStock {
            return .orange
        } else {
            return .secondary
        }
    }
}

// MARK: - Structure for item row

struct MerchItemRow: View {
    let item: MerchItem

    var body: some View {
        HStack {
            // Item image or category icon
            Group {
                MerchImageView(imageUrl: item.imageURL ?? "", item: item)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Item information
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.name)
                        .font(.headline)

                    if item.isLowStock {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }

                Text("\(item.category.rawValue) \(item.subcategory != nil ? "• \(item.subcategory!.rawValue)" : "")")
                    .font(.caption)
                    .foregroundColor(.gray)

                // Stock indicator - show depending on category
                if item.category == .clothing {
                    // For clothing show sizes
                    HStack(spacing: 5) {
                        Text("Sizes:")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        sizeIndicator("S", quantity: item.stock.S, lowThreshold: item.lowStockThreshold)
                        sizeIndicator("M", quantity: item.stock.M, lowThreshold: item.lowStockThreshold)
                        sizeIndicator("L", quantity: item.stock.L, lowThreshold: item.lowStockThreshold)
                        sizeIndicator("XL", quantity: item.stock.XL, lowThreshold: item.lowStockThreshold)
                        sizeIndicator("XXL", quantity: item.stock.XXL, lowThreshold: item.lowStockThreshold)
                    }
                } else {
                    // For other categories show total quantity
                    HStack(spacing: 5) {
                        Text("Quantity:")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        // Use sizeIndicator to display quantity with same style
                        Text("\(item.totalStock)")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                item.totalStock == 0 ? Color.gray.opacity(0.3) :
                                    item.isLowStock ? Color.orange.opacity(0.3) :
                                        Color.green.opacity(0.3)
                            )
                            .foregroundColor(
                                item.totalStock == 0 ? .gray :
                                    item.isLowStock ? .orange :
                                        .green
                            )
                            .cornerRadius(3)
                    }
                }
            }

            Spacer()

            // Price
            VStack(alignment: .trailing) {
                Text("\(Int(item.price)) EUR")
                    .font(.headline)
                    .bold()

                Text("Total: \(item.totalStock)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // Size availability indicator
    private func sizeIndicator(_ size: String, quantity: Int, lowThreshold: Int) -> some View {
        Text(size)
            .font(.caption2)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                quantity == 0 ? Color.gray.opacity(0.3) :
                    quantity <= lowThreshold ? Color.orange.opacity(0.3) :
                        Color.green.opacity(0.3)
            )
            .foregroundColor(
                quantity == 0 ? .gray :
                    quantity <= lowThreshold ? .orange :
                        .green
            )
            .cornerRadius(3)
    }
}

// Drafts View
struct DraftsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var drafts: [MerchItem] = []
    @State private var showConfirmation = false
    @State private var selectedDraft: MerchItem?
    @State private var showAddView = false
    
    var body: some View {
        NavigationView {
            List {
                if drafts.isEmpty {
                    Text("No saved drafts")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(drafts.indices, id: \.self) { index in
                        let draft = drafts[index]
                        Button {
                            selectedDraft = drafts[index]
                            showConfirmation = true
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(draft.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("\(draft.category.rawValue) • \(draft.price, specifier: "%.2f") EUR")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if draft.totalStock > 0 {
                                    Text("Stock: \(draft.totalStock)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteDraft(at: index)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Saved Drafts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    if !drafts.isEmpty {
                        Button("Clear All") {
                            UserDefaults.standard.removeObject(forKey: "merch_item_drafts")
                            drafts = []
                        }
                    }
                }
            }
            .onAppear {
                loadDrafts()
            }
            .alert("Load Draft?", isPresented: $showConfirmation) {
                Button("Edit") {
                    // TODO: Load the draft into AddMerchView
                    showConfirmation = false
                    showAddView = true
                }
                
                Button("Cancel", role: .cancel) {
                    selectedDraft = nil
                    showConfirmation = false
                }
            } message: {
                Text("Do you want to load and edit this draft?")
            }
        }
    }
    
    private func loadDrafts() {
        if let draftsData = UserDefaults.standard.array(forKey: "merch_item_drafts") as? [Data] {
            let decoder = JSONDecoder()
            drafts = draftsData.compactMap { data in
                try? decoder.decode(MerchItem.self, from: data)
            }
        }
    }
    
    private func deleteDraft(at index: Int) {
        if var draftsData = UserDefaults.standard.array(forKey: "merch_item_drafts") as? [Data] {
            if index < draftsData.count {
                draftsData.remove(at: index)
                UserDefaults.standard.set(draftsData, forKey: "merch_item_drafts")
                loadDrafts()
            }
        }
    }
}
